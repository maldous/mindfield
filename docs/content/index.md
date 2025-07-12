# MindField Documentation

MindField is a personality profiling app built with React. It helps users explore their traits through interactive questions and visual insights—like stepping into the landscape of your own mind.

## Services

### Core Application Services

- **[web](https://aldous.info/)** - Next.js frontend for MindField
- **[api](https://api.aldous.info/)** - Kong API Gateway (routes to internal services)
- **[docs](https://docs.aldous.info/)** - This documentation site

### Data Processing Services

- **[submission](https://submission.aldous.info/)** - Handles form submissions
- **[transform](https://transform.aldous.info/)** - Data transformation service
- **[render](https://render.aldous.info/)** - PDF/report generation
- **[presidio-analyzer](https://presidio-analyzer.aldous.info/)** - PII detection service
- **[presidio-anonymizer](https://presidio-anonymizer.aldous.info/)** - PII anonymization service
- **[presidio-image](https://presidio-image.aldous.info/)** - Image PII redaction service
- **[grapesjs](https://grapesjs.aldous.info/)** - Visual editor service

### Authentication & Identity

- **[keycloak](https://keycloak.aldous.info/)** - OAuth2/OpenID Connect identity provider
- **[kong](https://kong.aldous.info/)** - API gateway admin interface

### Data Storage

- **postgres** - Primary database (internal only)
- **[pgadmin](https://pgadmin.aldous.info/)** - PostgreSQL admin interface
- **redis** - Cache and session store
- **[redis-insight](https://redis-insight.aldous.info/)** - Official GUI by Redis
- **minio** - S3-compatible object storage (internal only)
- **[minio-console](https://minio-console.aldous.info/)** - MinIO management UI

### API Development Tools

- **[postgraphile](https://postgraphile.aldous.info/)** - GraphQL API for PostgreSQL
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

### Infrastructure Services

- **[mailhog](https://mailhog.aldous.info/)** - Email testing
- **[trivy](https://trivy.aldous.info/)** - Security scanning

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Domain with DNS management (A records for all subdomains)
- Ports 80 and 443 available

### Initial Setup

1. **Clone and configure environment**

```bash
git clone <repository>
cd mindfield
./setup.sh  # Creates .env with production settings
# Edit .env with your domain and credentials
```

2. **Start services**

```bash
# Production mode (all services via Caddy reverse proxy)
make start

# Development mode (exposes individual ports)
make dev

# View all available development ports
make ports
```

3. **Verify services**

```bash
# Check all services are running
docker compose ps

# View logs
make logs
```

## Architecture Overview

### Network Topology

- **frontend**: User-facing services (Caddy, web app, admin UIs)
- **backend**: Internal services (databases, APIs, processing)
- **monitoring**: Observability stack (Prometheus, Grafana, etc.)

### Authentication Flow

1. All services protected by Keycloak OAuth2/OIDC
2. Caddy handles TLS termination with automatic Let's Encrypt certificates
3. Kong manages API routing and rate limiting
4. Services validate tokens with Keycloak

### Service Access Patterns

**Production Mode (make start)**
All services accessible via HTTPS when authenticated:

```
https://aldous.info/           - Main web application
https://api.aldous.info/       - Kong API Gateway
https://keycloak.aldous.info/  - Authentication
https://grafana.aldous.info/   - Monitoring dashboards
```

**Development Mode (make dev)**
Direct port access for development:

```
http://localhost:3000  - Web App
http://localhost:3001  - API
http://localhost:3007  - Grafana
http://localhost:3017  - Keycloak
```

## Configuration

### Environment Variables

Key variables in `.env`:

- `DOMAIN`: Your domain (e.g., aldous.info)
- `LETSENCRYPT_EMAIL`: Email for SSL certificates
- `KEYCLOAK_*`: Authentication settings
- `DATABASE_URL`: PostgreSQL connection
- `REDIS_URL`: Redis connection
- `S3_*`: MinIO configuration

### Keycloak Setup

1. Access: https://keycloak.yourdomain.com
2. Login: admin/admin (change immediately)
3. Create realm: `mindfield`
4. Create clients for each service
5. Configure redirect URIs

### Kong Configuration

Routes are automatically configured via `kong-configure` service:

- `/api/*` → API service
- `/services/submission/*` → Submission service
- `/services/transform/*` → Transform service
- `/services/render/*` → Render service
- `/services/presidio/analyzer/*` → Presidio Analyzer service
- `/services/presidio/anonymizer/*` → Presidio Anonymizer service
- `/services/presidio/image/*` → Presidio Image Redactor service
- `/services/grapesjs/*` → GrapesJS service

## Development Workflow

### Make Commands

```bash
make help          # Show all available commands
make setup         # Initial project setup
make install       # Install dependencies
make build         # Build all services
make start         # Production mode (via Caddy)
make dev           # Development mode (exposed ports)
make ports         # Show development port mappings
make test          # Run tests
make lint          # Code linting
make logs          # View service logs
make stop          # Stop all services
make clean         # Clean up images and volumes
make reset         # Complete reset
```

### Development Ports (make dev)

```
Web App:             http://localhost:3000
API:                 http://localhost:3001
Submission:          http://localhost:3002
Transform:           http://localhost:3003
Render:              http://localhost:3004
Presidio Analyzer:   http://localhost:3005
Presidio Anonymizer: http://localhost:3006
Presidio Image:      http://localhost:3007
GrapesJS:            http://localhost:3008
Grafana:             http://localhost:3009
Hasura:              http://localhost:3010
PostGraphile:        http://localhost:3011
PostgREST:           http://localhost:3012
Swagger UI:          http://localhost:3013
ReDoc:               http://localhost:3014
Storybook:           http://localhost:3015
PgAdmin:             http://localhost:3016
Prisma Studio:       http://localhost:3017
SonarQube:           http://localhost:3018
Keycloak:            http://localhost:3019
Uptime Kuma:         http://localhost:3020
Redis Insight:       http://localhost:3021
```

## Operations

### Backup Strategy

- PostgreSQL: Daily automated backups via `backup` service
- MinIO: Configure bucket replication
- Configuration: Version control + regular snapshots

### Monitoring

- Grafana dashboards: https://grafana.yourdomain.com
- Prometheus metrics: https://prometheus.yourdomain.com
- Uptime monitoring: https://uptime-kuma.yourdomain.com

### Scaling

- Horizontal: Add service replicas
- Vertical: Adjust `mem_limit` and `cpus` in docker-compose.yml
- Database: Configure read replicas

### Security

- All external traffic via HTTPS
- Internal communication on Docker networks
- Secrets in environment variables (use Vault for production)
- Regular security scans via Trivy

## Troubleshooting

### Common Issues

**Certificate errors**

- Verify all subdomains have A records
- Check Caddy logs: `make logs`
- Ensure ports 80/443 are accessible

**Authentication loops**

- Check Keycloak redirect URIs
- Verify service environment variables
- Review Kong OIDC plugin configuration

**Service discovery failures**

- Use Docker service names (e.g., `http://api:3000`)
- Check network assignments in docker-compose.yml
- Verify health checks are passing

**Database connection issues**

- Check pgbouncer is healthy
- Verify DATABASE_URL format
- Review PostgreSQL logs

### Useful Commands

```bash
# View all logs
make logs

# Restart a service
docker compose restart <service>

# Execute commands in container
docker compose exec <service> sh

# Database backup
docker compose exec postgres pg_dump -U mindfield mindfield > backup.sql

# Clear all data (WARNING: destructive)
make reset
```

## Production Checklist

- [ ] Change all default passwords
- [ ] Configure proper SMTP for emails
- [ ] Set up monitoring alerts
- [ ] Enable database backups
- [ ] Configure log retention
- [ ] Set up SSL certificate renewal monitoring
- [ ] Implement secret management (Vault)
- [ ] Configure firewall rules
- [ ] Set up CI/CD pipeline
- [ ] Document disaster recovery procedure

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
https://api.aldous.info/services/presidio/analyzer/* → Presidio Analyzer service
https://api.aldous.info/services/presidio/anonymizer/* → Presidio Anonymizer service
https://api.aldous.info/services/presidio/image/* → Presidio Image Redactor service
https://api.aldous.info/services/grapesjs/* → GrapesJS service
```

## Service Communication

- Internal services communicate via Docker network names
- External access requires authentication token from Keycloak
- Kong handles rate limiting and request routing
- All traffic encrypted via Caddy with Let's Encrypt certificates
