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

import express from "express";
import cors from "cors";
import helmet from "helmet";
import compression from "compression";
import cookieParser from "cookie-parser";
import session from "express-session";
import Keycloak from "keycloak-connect";
import rateLimit from "express-rate-limit";
import slowDown from "express-slow-down";
import { AsyncLocalStorage } from "node:async_hooks";
import { v4 as uuid } from "uuid";
import promClient from "prom-client";
import { celebrate, errors as celebrateErrors, Joi } from "celebrate";
import swaggerUi from "swagger-ui-express";
import swaggerJsdoc from "swagger-jsdoc";
import { Server as HttpServer } from "http";
import { Server as SocketIOServer } from "socket.io";
import { Queue, Worker } from "bullmq";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const pino = require("pino");
const pinoHttp: any = require("pino-http");

/* ────────── OpenTelemetry ────────── */
import { NodeSDK } from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";

/* ─────────────────────────────────────────────────────────────── */

export interface Options {
  serviceName: string;
  exposeSwagger?: boolean;
  swaggerOptions?: swaggerJsdoc.Options;
  registerRoutes: (app: express.Express, io: SocketIOServer) => void;
  registerQueues?: (deps: {
    queue: Queue;
    worker: Worker;
    // Delete scheduler as it is not used in express.ts
  }) => void;
}

const als = new AsyncLocalStorage<Map<string, any>>();
const rootLogger = pino({ level: process.env.LOG_LEVEL ?? "info" });

export async function startExpress(opts: Options) {
  /* ── OTEL ── */
  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    instrumentations: [getNodeAutoInstrumentations()],
  });
  await sdk.start();

  /* ── Express core ── */
  const app = express();
  app.set("trust proxy", 1);
  app.disable("x-powered-by");

  /* ── Essential middleware ── */
  app.use(helmet());
  app.use(compression());
  app.use(cors({ origin: true, credentials: true }));
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: false }));
  app.use(cookieParser());

  /* ── Request-id & ALS context ── */
  app.use(
    (
      req: express.Request,
      _res: express.Response,
      next: express.NextFunction,
    ) => {
      const store = new Map<string, any>();
      store.set("requestId", req.headers["x-request-id"] ?? uuid());
      als.run(store, next);
    },
  );

  /* ── Pino HTTP logger ── */

  app.use(
    pinoHttp({
      logger: rootLogger,
      serializers: {
        req: (req: express.Request) => ({
          id: als.getStore()?.get("requestId"),
          method: req.method,
          url: req.url,
        }),
      },
    }),
  );

  /* ── Rate-limit & slow-down ── */
  const limiter = rateLimit({
    windowMs: 60_000,
    max: 500,
    standardHeaders: true,
    legacyHeaders: false,
  });
  const slowdown = slowDown({
    windowMs: 60_000,
    delayAfter: 250,
    delayMs: 250,
  });
  app.use(limiter, slowdown);

  /* ── Session + Keycloak (if KEYCLOAK_URL env is set) ── */
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
        resource: process.env.KEYCLOAK_CLIENT_ID ?? opts.serviceName,
        "ssl-required": "external",
      },
    );
    app.use(keycloak.middleware());
    // Example protected endpoint
    app.get(
      "/whoami",
      keycloak.protect(),
      (req: express.Request, res: express.Response) =>
        res.json({ user: (req as any).kauth?.grant?.access_token?.content }),
    );
  }

  /* ── Prometheus metrics ── */
  const registry = new promClient.Registry();
  promClient.collectDefaultMetrics({
    register: registry,
    prefix: `${opts.serviceName}_`,
  });
  const httpMetrics = new promClient.Histogram({
    name: `${opts.serviceName}_http_request_seconds`,
    help: "Request duration",
    buckets: [0.05, 0.1, 0.3, 1.5, 10],
    labelNames: ["method", "route", "code"],
  });
  registry.registerMetric(httpMetrics);
  app.use(
    (
      req: express.Request,
      res: express.Response,
      next: express.NextFunction,
    ) => {
      const end = httpMetrics.startTimer({
        method: req.method,
        route: req.path,
      });
      res.on("finish", () => end({ code: res.statusCode }));
      next();
    },
  );
  app.get("/metrics", async (_req: express.Request, res: express.Response) => {
    res.set("Content-Type", registry.contentType);
    res.end(await registry.metrics());
  });

  /* ── Health probe ── */
  app.get("/health", (_req, res) =>
    res.json({
      status: "ok",
      service: opts.serviceName,
      time: new Date().toISOString(),
    }),
  );

  /* ── Validation example route (celebrate/Joi) ── */
  app.post(
    "/echo",
    celebrate({
      body: Joi.object({ msg: Joi.string().max(1024).required() }),
    }),
    (req, res) => res.json({ echoed: (req.body as any).msg }),
  );

  /* ── Swagger / Redoc ── */
  if (opts.exposeSwagger !== false) {
    const swaggerSpec = swaggerJsdoc({
      definition: {
        openapi: "3.0.0",
        info: { title: `${opts.serviceName} API`, version: "1.0.0" },
      },
      apis: ["dist/**/*.js", "dist/**/*.ts"], // adjust for your compiled output
      ...(opts.swaggerOptions ?? {}),
    });
    app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  }

  /* ── BullMQ helpers (Redis URL must exist) ── */
  let queueDeps: any = null;
  if (process.env.REDIS_URL && opts.registerQueues) {
    const connection = { connection: { url: process.env.REDIS_URL } as any };
    const queue = new Queue(`${opts.serviceName}-q`, connection);
    // Delete the QueueScheduler instantiation as it's not directly used in express.ts
    const worker = new Worker(
      `${opts.serviceName}-q`,
      async (job: any) => {
        rootLogger.info(
          { jobId: job.id },
          "Dummy worker – no processor registered",
        );
      },
      connection,
    );
    queueDeps = { queue, worker };
    await opts.registerQueues(queueDeps);
  }

  /* ── Web-sockets ── */
  const httpServer = new HttpServer(app);
  const io = new SocketIOServer(httpServer, {
    cors: { origin: true, credentials: true },
  });
  io.on("connection", (socket) => {
    rootLogger.info({ id: socket.id }, "socket connected");
    socket.emit("welcome", { ts: Date.now() });
  });

  /* ── Service-specific routes ── */
  opts.registerRoutes(app, io);

  /* celebrate validation errors */
  app.use(celebrateErrors());

  /* 404 fallback */
  app.use((_req, res) => res.status(404).json({ error: "Not Found" }));

  /* Global error */
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use(
    (
      err: any,
      _req: express.Request,
      res: express.Response,
      _next: express.NextFunction,
    ) => {
      rootLogger.error({ err }, "Unhandled error");
      res
        .status(err.status ?? 500)
        .json({ error: err.message ?? "Internal error" });
    },
  );

  /* ── Listen ── */
  const port = Number(process.env.PORT ?? 3000);
  const server = httpServer.listen(port, () =>
    rootLogger.info(`🚀  ${opts.serviceName} on :${port}`),
  );

  /* ── Graceful shutdown ── */
  const shutdown = async () => {
    rootLogger.info("Shutting down…");
    server.close(async () => {
      if (queueDeps) {
        await queueDeps.worker.close();
        await queueDeps.scheduler.close();
        await queueDeps.queue.close();
      }
      await sdk.shutdown().catch(rootLogger.error);
      process.exit(0);
    });
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}
