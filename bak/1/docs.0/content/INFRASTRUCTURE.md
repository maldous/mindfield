# MindField Infrastructure Guide

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
cp .env.example .env  # Edit with your domain and credentials
```

2. **Start services**

```bash
# Production mode (all services internal except via Caddy)
docker-compose up -d

# Development mode (exposes ports for local access)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

3. **Verify services**

```bash
# Check all services are running
docker-compose ps

# View logs
docker-compose logs -f <service-name>
```

## Architecture Overview

### Network Topology

- **frontend**: User-facing services (Caddy, web app, admin UIs)
- **backend**: Internal services (databases, APIs, processing)
- **monitoring**: Observability stack (Prometheus, Grafana, etc.)

### Authentication Flow

1. All services protected by Keycloak OAuth2/OIDC
2. Caddy handles TLS termination
3. Kong manages API routing and rate limiting
4. Services validate tokens with Keycloak

## Service Categories

### Core Infrastructure

- **Caddy**: Reverse proxy with automatic HTTPS
- **Kong**: API gateway for microservices
- **Keycloak**: Identity and access management

### Data Layer

- **PostgreSQL**: Primary database
- **Redis**: Caching and sessions
- **MinIO**: S3-compatible object storage
- **OpenSearch**: Full-text search and analytics

### Application Services

- **API**: Main application backend
- **Web**: Next.js frontend
- **Submission**: Form processing
- **Transform**: Data transformation
- **Render**: PDF generation
- **Presidio**: PII detection and anonymization (Analyzer, Anonymizer, Image Redactor)
- **GrapesJS**: Visual editor

### Monitoring Stack

- **Prometheus**: Metrics collection
- **Grafana**: Dashboards
- **Loki**: Log aggregation
- **Jaeger**: Distributed tracing
- **Alertmanager**: Alert routing

### Development Tools

- **PgAdmin**: Database management
- **Hasura**: Instant GraphQL
- **PostGraphile**: GraphQL for PostgreSQL
- **PostgREST**: REST API for PostgreSQL
- **Swagger UI**: API documentation
- **Storybook**: Component library
- **SonarQube**: Code quality

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
- Check Caddy logs: `docker-compose logs caddy`
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
docker-compose logs -f

# Restart a service
docker-compose restart <service>

# Execute commands in container
docker-compose exec <service> sh

# Database backup
docker-compose exec postgres pg_dump -U mindfield mindfield > backup.sql

# Clear all data (WARNING: destructive)
docker-compose down -v
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
