# MindField

MindField is a personality profiling app built with React. It helps users explore their traits through interactive questions and visual insights—like stepping into the landscape of your own mind.

## Services

- [alertmanager](https://alertmanager.mindfield.local/): Prometheus Alertmanager for grouping, silencing and sending alerts.
- [api](https://api.mindfield.local/): Nest-based backend serving the MindField API.
- backup: Daily Postgres dump & retention cleanup.
- blackbox-exporter: Probes HTTP/TCP endpoints for uptime checks.
- caddy: TLS-terminating reverse proxy for all web services.
- [gitea](https://gitea.mindfield.local/): Self-hosted Git service.
- gitea-db: PostgreSQL store for Gitea.
- [grafana](https://grafana.mindfield.local/): Dashboard UI for Prometheus metrics.
- [grapesjs](https://grapesjs.mindfield.local/): Headless editor service for dynamic forms.
- [hasura](https://hasura.mindfield.local/): Instant GraphQL API on Postgres.
- [jaeger](https://jaeger.mindfield.local/): Distributed-tracing storage & UI.
- [keycloak](https://keycloak.mindfield.local/): OAuth2/OpenID Connect identity provider.
- [kong](https://kong.mindfield.local/): API gateway & rate-limiter.
- kong-database: PostgreSQL store for Kong.
- [loki](https://loki.mindfield.local/): Log aggregation compatible with Prometheus.
- mailhog: Fake SMTP server for dev/testing.
- [minio](https://minio.mindfield.local/): S3-compatible object storage.
- [mkdocs](https://docs.mindfield.local/): Serves your Markdown docs (this site).
- node-exporter: Exposes host OS metrics to Prometheus.
- [opensearch](https://opensearch.mindfield.local/): Elasticsearch-compatible search & analytics.
- [opensearch-dashboards](https://opensearch-dashboards.mindfield.local/): UI for OpenSearch.
- otel-collector: Central OpenTelemetry collector & exporter.
- [pgadmin](https://pgadmin.mindfield.local/): Web UI for managing Postgres.
- pgbouncer: Lightweight Postgres connection pooler.
- [postgraphile](https://postgraphile.mindfield.local/): Instant GraphQL server on Postgres.
- postgres: Primary relational database.
- postgrest: REST API server for Postgres.
- prisma-studio: GUI for inspecting your Prisma schema & data.
- [prometheus](https://prometheus.mindfield.local/): Time-series database for metrics.
- promtail: Ships logs to Loki.
- [rabbitmq](https://rabbitmq.mindfield.local/): Message broker for background jobs.
- redaction: FastAPI-based PII redaction service.
- [redis](https://redis.mindfield.local/): In-memory data store & cache.
- redoc: OpenAPI documentation UI.
- [render](https://render.mindfield.local/): Service that generates PDFs/previews.
- [sonarqube](https://sonarqube.mindfield.local/): Continuous code-quality analysis.
- sonarqube-db: PostgreSQL for SonarQube.
- [step-ca](https://step-ca.mindfield.local/): Internal certificate authority.
- [storybook](https://storybook.mindfield.local/): React component explorer.
- [submission](https://submission.mindfield.local/): Microservice handling submissions.
- swagger-ui: Interactive API docs for `api`.
- [transform](https://transform.mindfield.local/): Microservice that sanitises & transforms payloads.
- [trivy](https://trivy.mindfield.local/): Container image security scanner.
- [uptime-kuma](https://uptime-kuma.mindfield.local/): Self-hosted uptime monitoring dashboard.
- [web](https://mindfield.local/): Next.js frontend for MindField.

