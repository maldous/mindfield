# Architecture

## System Overview

MindField is built as a microservices architecture with the following key principles:

- **Service-oriented**: Each component has a specific responsibility
- **Container-native**: All services run in Docker containers
- **API-first**: Services communicate via well-defined APIs
- **Observable**: Comprehensive monitoring and logging
- **Secure**: Authentication and authorization at every layer

## Network Architecture

### Network Segmentation

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │    │     Backend     │    │   Monitoring    │
│                 │    │                 │    │                 │
│ • Caddy         │    │ • PostgreSQL    │    │ • Prometheus    │
│ • Web App       │    │ • Redis         │    │ • Grafana       │
│ • Admin UIs     │    │ • APIs          │    │ • Loki          │
│                 │    │ • Processing    │    │ • Jaeger        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Service Communication

- **External → Frontend**: HTTPS via Caddy (ports 80/443)
- **Frontend ↔ Backend**: Internal Docker networks
- **Backend ↔ Monitoring**: Metrics and logs collection
- **Inter-service**: Service discovery via Docker DNS

## Core Components

### Reverse Proxy Layer

**Caddy** serves as the entry point:

- Automatic HTTPS with Let's Encrypt
- Request routing to services
- Load balancing and health checks
- Static file serving

### API Gateway

**Kong** manages API traffic:

- Request routing and transformation
- Rate limiting and throttling
- Authentication and authorization
- API analytics and monitoring

### Authentication

**Keycloak** provides identity management:

- OAuth2/OpenID Connect
- User and role management
- Single sign-on (SSO)
- Multi-factor authentication

## Data Architecture

### Primary Database

**PostgreSQL** with **PgBouncer** connection pooling:

- ACID compliance for critical data
- Connection pooling for performance
- Automated backups
- Read replicas for scaling

### Caching Layer

**Redis** for high-performance caching:

- Session storage
- Application caching
- Rate limiting counters
- Real-time data

### Object Storage

**MinIO** S3-compatible storage:

- File uploads and assets
- Document storage
- Backup storage
- CDN integration

### Search Engine

**OpenSearch** for full-text search:

- Document indexing
- Analytics and aggregations
- Log analysis
- Real-time search

## Application Services

### Core Application

- **Web**: Next.js frontend application
- **API**: Main backend API service
- **Submission**: Form processing service
- **Transform**: Data transformation pipeline
- **Render**: PDF and report generation
- **Presidio**: Microsoft's PII detection and anonymization platform with separate services for text analysis, anonymization, and image redaction
- **GrapesJS**: Visual content editor

### Development Tools

- **Storybook**: Component library and documentation
- **Swagger UI**: Interactive API documentation
- **Hasura**: Instant GraphQL API
- **PostGraphile**: PostgreSQL GraphQL interface
- **PostgREST**: PostgreSQL REST API
- **PgAdmin**: Database administration
- **Prisma Studio**: Database ORM interface

## Monitoring Architecture

### Metrics Collection

**Prometheus** ecosystem:

- Service metrics collection
- Custom application metrics
- Infrastructure monitoring
- Alert rule evaluation

### Visualization

**Grafana** dashboards:

- Real-time metrics visualization
- Custom dashboard creation
- Alert management
- Multi-data source support

### Logging

**Loki** log aggregation:

- Centralized log collection
- Log parsing and indexing
- Log-based alerting
- Integration with Grafana

### Tracing

**Jaeger** distributed tracing:

- Request flow visualization
- Performance bottleneck identification
- Service dependency mapping
- Error tracking

### Uptime Monitoring

**Uptime Kuma** service monitoring:

- HTTP/HTTPS endpoint monitoring
- Service availability tracking
- Notification management
- Status page generation

## Security Architecture

### Network Security

- Internal service communication via private networks
- No direct database access from external networks
- Service-to-service authentication
- Network segmentation by function

### Authentication Flow

```
User → Caddy → Kong → Keycloak → Service
  ↓      ↓      ↓        ↓         ↓
HTTPS   TLS   OAuth2   JWT    Validation
```

### Data Protection

- Encryption at rest (database, object storage)
- Encryption in transit (TLS everywhere)
- Microsoft Presidio PII detection and anonymization services
- Regular security scanning with Trivy

## Scalability Considerations

### Horizontal Scaling

- Stateless service design
- Load balancing via Kong/Caddy
- Database read replicas
- Container orchestration ready

### Vertical Scaling

- Resource limits per service
- Memory and CPU optimization
- Database connection pooling
- Caching strategies

### Performance Optimization

- CDN integration via MinIO
- Database query optimization
- Application-level caching
- Asynchronous processing

## Deployment Architecture

### Container Strategy

- Multi-stage Docker builds
- Shared base images
- Build caching optimization
- Security scanning integration

### Configuration Management

- Environment-based configuration
- Secret management
- Feature flags
- Configuration validation

### Health Checks

- Service health endpoints
- Dependency health validation
- Graceful degradation
- Circuit breaker patterns
