# MindField Infrastructure Setup Plan

## Overview

Transform the current development setup into a production-ready platform with proper service connectivity, security, and monitoring.

## Current Issues to Address

### 1. Port Configuration & Connectivity

- Multiple services exposing unnecessary external ports
- Inconsistent internal/external port mappings
- Missing internal DNS resolution between services

### 2. Kong API Gateway Configuration

- Kong not properly configured to route to internal services
- Missing service definitions and routes
- No authentication/rate limiting configured

### 3. Service Dependencies & Environment Variables

- Missing environment variables for service interconnection
- Incorrect service URLs in configurations
- Database connection strings need updating

### 4. Security & Access Control

- All services currently exposed externally
- No proper authentication flow through Keycloak
- Missing CORS and security headers

## Implementation Steps

### Phase 1: Environment Configuration

1. Update `.env` file with proper service URLs and credentials
2. Add missing environment variables for service interconnection
3. Configure internal DNS names for service discovery

### Phase 2: Docker Compose Optimization

1. Remove external port mappings for internal-only services
2. Add proper health checks and dependencies
3. Configure internal networks for service isolation

### Phase 3: Caddy Configuration

1. Fix localhost development routing
2. Ensure production routing only exposes public services
3. Add security headers and rate limiting

### Phase 4: Kong API Gateway Setup

1. Configure Kong routes for internal services
2. Add authentication plugins (OAuth2/JWT)
3. Implement rate limiting and request transformation

### Phase 5: Service Integration

1. Configure Keycloak realms and clients
2. Set up Grafana data sources and dashboards
3. Configure Prometheus scraping for all services
4. Set up Loki log aggregation

### Phase 6: Documentation Update

1. Update docs/content/index.md with service categories
2. Document internal vs external services
3. Add architecture diagrams and flow documentation

## Service Architecture

### Public-Facing Services (via HTTPS)

- **web** (aldous.info) - Main application
- **api** (api.aldous.info) - API gateway via Kong
- **docs** (docs.aldous.info) - Documentation
- **keycloak** (keycloak.aldous.info) - Authentication
- **grafana** (grafana.aldous.info) - Monitoring dashboards
- **kong** (kong.aldous.info) - API gateway admin

### Internal Services (Not publicly accessible)

- **postgres** - Primary database
- **redis** - Cache and session store
- **minio** - Object storage
- **submission** - Form submission processing
- **transform** - Data transformation
- **render** - PDF/report generation
- **presidio-analyzer** - PII detection service
- **presidio-anonymizer** - PII anonymization service
- **presidio-image-redactor** - Image PII redaction service

### Development/Admin Tools (Restricted access)

- **pgadmin** - Database management
- **sonarqube** - Code quality
- **storybook** - Component library
- **swagger-ui/redoc** - API documentation

## Data Flow Patterns

### External Client Flow

```
Client -> Caddy -> Kong -> Internal Services
                     |
                     +-> Authentication (Keycloak)
                     +-> Rate Limiting
                     +-> Request Transformation
```

### Internal Service Communication

```
Services -> Direct container networking
         -> Redis (caching/sessions)
         -> RabbitMQ (async jobs)
         -> PostgreSQL (data persistence)
         -> MinIO (file storage)
```

### Monitoring Flow

```
All Services -> Prometheus (metrics)
             -> Loki (logs via Promtail)
             -> Jaeger (traces via OTEL)
             -> Grafana (visualization)
```

## Missing Components to Add

1. **Backup Strategy**
   - Automated PostgreSQL backups (already present)
   - MinIO bucket replication
   - Configuration backups

2. **Security Enhancements**
   - Network policies
   - Secret management (consider Vault)
   - Certificate rotation

3. **High Availability**
   - Database replication
   - Redis sentinel
   - Service replicas

4. **CI/CD Integration**
   - Health check endpoints
   - Deployment webhooks
   - Database migration strategy
