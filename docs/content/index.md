# MindField

MindField is a personality profiling app built with React. It helps users explore their traits through interactive questions and visual insights—like stepping into the landscape of your own mind.

## Architecture Overview

All services are accessible externally via HTTPS when authenticated through Keycloak. This allows external developers to use any service remotely.

### Authentication Flow
1. All services require authentication via Keycloak OAuth2/OIDC
2. Access `https://keycloak.aldous.info` to manage authentication
3. API requests go through Kong Gateway at `https://api.aldous.info`
4. Direct service access available via `https://{service}.aldous.info` when authenticated

## Services

### Core Application Services
- **[web](https://aldous.info/)** - Next.js frontend for MindField
- **[api](https://api.aldous.info/)** - Kong API Gateway (routes to internal services)
- **[docs](https://docs.aldous.info/)** - This documentation site

### Authentication & Identity
- **[keycloak](https://keycloak.aldous.info/)** - OAuth2/OpenID Connect identity provider
- **[kong](https://kong.aldous.info/)** - API gateway admin interface

### Data Processing Services
- **[submission](https://submission.aldous.info/)** - Handles form submissions
- **[transform](https://transform.aldous.info/)** - Data transformation service
- **[render](https://render.aldous.info/)** - PDF/report generation
- **[redaction](https://redaction.aldous.info/)** - PII removal service
- **[grapesjs](https://grapesjs.aldous.info/)** - Visual editor service

### Data Storage
- **postgres** - Primary database (internal only)
- **[pgadmin](https://pgadmin.aldous.info/)** - PostgreSQL admin interface
- **[redis](https://redis.aldous.info/)** - Cache and session store
- **[minio](https://minio.aldous.info/)** - S3-compatible object storage
- **[minio-console](https://minio-console.aldous.info/)** - MinIO management UI

### API Development Tools
- **[hasura](https://hasura.aldous.info/)** - Instant GraphQL API
- **[postgraphile](https://postgraphile.aldous.info/)** - GraphQL API for PostgreSQL
- **[postgrest](https://postgrest.aldous.info/)** - REST API for PostgreSQL
- **[swagger-ui](https://swagger-ui.aldous.info/)** - Interactive API documentation
- **[redoc](https://redoc.aldous.info/)** - API documentation

### Monitoring & Observability
- **[grafana](https://grafana.aldous.info/)** - Metrics dashboards
- **[prometheus](https://prometheus.aldous.info/)** - Metrics collection
- **[loki](https://loki.aldous.info/)** - Log aggregation
- **[jaeger](https://jaeger.aldous.info/)** - Distributed tracing
- **[alertmanager](https://alertmanager.aldous.info/)** - Alert management
- **[uptime-kuma](https://uptime-kuma.aldous.info/)** - Uptime monitoring

### Search & Analytics
- **[opensearch](https://opensearch.aldous.info/)** - Search and analytics
- **[opensearch-dashboards](https://opensearch-dashboards.aldous.info/)** - OpenSearch UI

### Development Tools
- **[storybook](https://storybook.aldous.info/)** - Component library
- **[sonarqube](https://sonarqube.aldous.info/)** - Code quality analysis
- **[prisma-studio](https://prisma-studio.aldous.info/)** - Database ORM UI
- **[gitea](https://gitea.aldous.info/)** - Git repository management

### Infrastructure Services
- **[rabbitmq](https://rabbitmq.aldous.info/)** - Message broker
- **[mailhog](https://mailhog.aldous.info/)** - Email testing
- **[step-ca](https://step-ca.aldous.info/)** - Internal certificate authority
- **[trivy](https://trivy.aldous.info/)** - Security scanning
- **[otel-collector](https://otel-collector.aldous.info/)** - OpenTelemetry collector

### Internal Services (No UI)
- **postgres** - Primary database
- **pgbouncer** - Connection pooling
- **kong-database** - Kong configuration storage
- **redis** - Caching layer
- **promtail** - Log shipping
- **node-exporter** - System metrics
- **blackbox-exporter** - Endpoint monitoring
- **backup** - Automated backups

## API Access Patterns

### Direct Service Access
When authenticated, you can access any service directly:
```
https://{service}.aldous.info
```

### Via Kong API Gateway
All API services are also available through the gateway:
```
https://api.aldous.info/api/* → Internal API service
https://api.aldous.info/services/submission/* → Submission service
https://api.aldous.info/services/transform/* → Transform service
https://api.aldous.info/services/render/* → Render service
https://api.aldous.info/services/redaction/* → Redaction service
https://api.aldous.info/services/grapesjs/* → GrapesJS service
```

## Development Setup

### Environment Variables
All services use environment variables from `.env` file. Key variables:
- `DOMAIN` - Your domain (default: aldous.info)
- `KEYCLOAK_*` - Authentication configuration
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection
- `S3_*` - MinIO/S3 configuration

### Authentication Setup
1. Access Keycloak at `https://keycloak.aldous.info`
2. Default admin credentials: `admin/admin`
3. Create realm: `mindfield`
4. Create clients for each service requiring authentication
5. Configure redirect URIs for each client

### Service Communication
- Internal services communicate via Docker network names
- External access requires authentication token from Keycloak
- Kong handles rate limiting and request routing
- All traffic encrypted via Caddy with Let's Encrypt certificates
