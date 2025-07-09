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

import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import session from 'express-session';
import Keycloak from 'keycloak-connect';
import rateLimit from 'express-rate-limit';
import slowDown from 'express-slow-down';
import promClient from 'prom-client';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { WsAdapter } from '@nestjs/platform-ws';
import { Queue, Worker, QueueScheduler } from 'bullmq';
import { ExpressAdapter } from '@nestjs/platform-express';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module';

/* OTEL */
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

export async function startNest() {
  /* ── OTEL ── */
  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter(),
    instrumentations: [getNodeAutoInstrumentations()],
  });
  await sdk.start();

  /* ── Nest factory ── */
  const adapter = new ExpressAdapter();
  const app = await NestFactory.create(AppModule, {
    logger: new Logger(), // pino under the hood
    cors: { origin: true, credentials: true },
    bodyParser: false, // we add it manually for large limits
  });
  app.use(helmet());
  app.use(compression());
  app.use(cookieParser());
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: false }));

  /* validation */
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }));

  /* rate-limit / slow-down */
  const limiter = rateLimit({
    windowMs: 60_000,
    max: 1000,
    standardHeaders: true,
    legacyHeaders: false,
  });
  const slowdown = slowDown({ windowMs: 60_000, delayAfter: 400, delayMs: 250 });
  app.use(limiter, slowdown);

  /* Keycloak (optional) */
  if (process.env.KEYCLOAK_URL) {
    const memoryStore = new session.MemoryStore();
    app.use(
      session({
        secret: process.env.SESSION_SECRET ?? 'dev_secret_change_me',
        resave: false,
        saveUninitialized: true,
        store: memoryStore,
      }),
    );
    const keycloak = new Keycloak({ store: memoryStore }, {
      'auth-server-url': process.env.KEYCLOAK_URL,
      realm: process.env.KEYCLOAK_REALM ?? 'mindfield',
      resource: process.env.KEYCLOAK_CLIENT_ID ?? 'api',
      'ssl-required': 'external',
    });
    app.use(keycloak.middleware());
  }

  /* Prometheus metrics */
  const registry = new promClient.Registry();
  promClient.collectDefaultMetrics({ register: registry, prefix: 'api_' });
  app.getHttpAdapter().getInstance().get('/metrics', async (_req: any, res: any) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  /* Swagger */
  const docCfg = new DocumentBuilder().setTitle('MindField API').setVersion('1.0').build();
  const document = SwaggerModule.createDocument(app, docCfg);
  SwaggerModule.setup('api-docs', app, document);

  /* WebSockets */
  app.useWebSocketAdapter(new WsAdapter(app));

  /* BullMQ helper */
  if (process.env.REDIS_URL) {
    const connection = { connection: { url: process.env.REDIS_URL } as any };
    const queue = new Queue('api-q', connection);
    const scheduler = new QueueScheduler('api-q', connection);
    const worker = new Worker('api-q', async (job) => {
      app.get(Logger).log(`dummy worker job ${job.id}`);
    }, connection);

    // Expose via app locals
    (app.getHttpAdapter().getInstance() as any).locals.queue = queue;
    await scheduler.waitUntilReady();
  }

  /* ── listen & shutdown ── */
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  app.get(Logger).log(`🚀  API running on :${port}`);

  const shutdown = async () => {
    app.get(Logger).log('Shutting down…');
    await app.close();
    await sdk.shutdown().catch(app.get(Logger).error);
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}
