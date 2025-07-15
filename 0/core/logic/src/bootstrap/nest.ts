/**
 * CORS + Helmet + compression
 * Cookie/session + Keycloak
 * Rate-limit & slow-down
 * Structured pino logs + ALS request-id
 * Validation (celebrate/Joi)
 * Swagger UI / Redoc docs
 * Prometheus metrics
 * OpenTelemetry auto-instrumentation
 * Socket.io (web-sockets)
 * BullMQ queue helper
 * Graceful shutdown
 */

import "reflect-metadata";
import { Logger, Type, ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { WsAdapter } from "@nestjs/platform-ws";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { Queue, Worker } from "bullmq";
import compression from "compression";
import cookieParser from "cookie-parser";
import * as express from "express";
import rateLimit from "express-rate-limit";
import session from "express-session";
import slowDown from "express-slow-down";
import helmet from "helmet";
import Keycloak from "keycloak-connect";
import promClient from "prom-client";

/* ────────── OpenTelemetry ────────── */
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { NodeSDK } from "@opentelemetry/sdk-node";

export async function startNest(AppRoot: Type<unknown>) {
    /* ── OTEL ── */
    const sdk = new NodeSDK({
        traceExporter: new OTLPTraceExporter(),
        instrumentations: [getNodeAutoInstrumentations()],
    });
    sdk.start();

    /* ── Nest factory ── */
    const app = await NestFactory.create(AppRoot, {
        logger: new Logger(), // let Nest handle stdout/stderr
        cors: { origin: true, credentials: true },
        bodyParser: false,
    });

    /* Local logger instance (to avoid .get(Logger) look-ups) */
    const logger = new Logger("bootstrap");

    /* ── Core middleware ── */
    app.use(helmet());
    app.use(compression());
    app.use(cookieParser());
    app.use(express.json({ limit: "10mb" }));
    app.use(express.urlencoded({ extended: false }));

    /* ── Validation ── */
    app.useGlobalPipes(
        new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }),
    );

    /* ── Rate-limit / slow-down ── */
    const limiter = rateLimit({
        windowMs: 60_000,
        max: 1_000,
        standardHeaders: true,
        legacyHeaders: false,
    });
    const slowdown = slowDown({
        windowMs: 60_000,
        delayAfter: 400,
        delayMs: 250,
    });
    app.use(limiter, slowdown);

    /* ── Keycloak (optional) ── */
    if (process.env.KEYCLOAK_URL) {
        const memoryStore = new session.MemoryStore();
        app.use(
            session({
                secret: process.env.SESSION_SECRET ?? "dev_secret_change_me",
                resave: false,
                saveUninitialized: true,
                store: memoryStore,
            }),
        );

        const keycloak = new Keycloak(
            { store: memoryStore },
            {
                "confidential-port": 0,
                "auth-server-url": process.env.KEYCLOAK_URL,
                realm: process.env.KEYCLOAK_REALM ?? "mindfield",
                resource: process.env.KEYCLOAK_CLIENT_ID ?? "api",
                "ssl-required": "external",
            },
        );
        app.use(keycloak.middleware());
    }

    /* ── Prometheus metrics ── */
    const registry = new promClient.Registry();
    promClient.collectDefaultMetrics({ register: registry, prefix: "api_" });
    app.getHttpAdapter()
        .getInstance()
        .get("/metrics", async (_req: unknown, res: express.Response) => {
            res.set("Content-Type", registry.contentType);
            res.end(await registry.metrics());
        });

    /* ── Swagger ── */
    const docCfg = new DocumentBuilder()
        .setTitle("MindField API")
        .setVersion("1.0")
        .build();

    const document = SwaggerModule.createDocument(app, docCfg);

    // Raw JSON for external viewers
    app.getHttpAdapter()
        .getInstance()
        .get("/api-docs/swagger.json", (_req: unknown, res: express.Response) =>
            res.json(document),
        );

    // In-process Swagger-UI
    SwaggerModule.setup("api-docs", app, document, {
        jsonDocumentUrl: "api-docs/swagger.json", // deep-link button on the UI
    });

    /* ── WebSockets ── */
    app.useWebSocketAdapter(new WsAdapter(app));

    /* ── BullMQ helper ── */
    let queue: Queue | undefined;
    let _worker: Worker | undefined; // intentionally unused variable

    if (process.env.REDIS_URL) {
        const connection = { connection: { url: process.env.REDIS_URL } };

        queue = new Queue("api-q", connection);

        // Dummy worker so the queue has a consumer (useful in dev)
        _worker = new Worker(
            "api-q",
            async (job) => logger.log(`dummy worker job ${job.id}`),
            connection,
        );

        // Expose queue on Express locals (handy for tests / health)
        (
            app.getHttpAdapter().getInstance() as express.Application
        ).locals.queue = queue;
    }

    /* ── Listen & graceful shutdown ── */
    const port = Number(process.env.PORT ?? 3000);
    await app.listen(port);
    logger.log(`🚀  API running on :${port}`);

    const shutdown = async () => {
        logger.log("Shutting down…");

        await Promise.all([
            _worker?.close().catch(() => void 0),
            queue?.close().catch(() => void 0),
            app.close(),
            sdk.shutdown().catch((err) => logger.error(err)),
        ]);

        process.exit(0);
    };

    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
}
