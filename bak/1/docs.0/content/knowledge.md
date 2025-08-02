# MindField Infrastructure Knowledge

## Architecture Decisions

### All Services Externally Accessible

- Every service with a UI is accessible via HTTPS when authenticated
- Enables external developers to use services remotely
- Authentication handled by Keycloak OAuth2/OIDC

### Service Discovery

- Internal: Use Docker service names (e.g., `http://api:3000`)
- External: Use subdomain pattern `https://{service}.aldous.info`

### Port Management

- Only Caddy exposes ports 80/443 externally
- All other services communicate internally
- Development can use localhost with port forwarding

### Authentication Flow

1. User accesses any service URL
2. Redirected to Keycloak for authentication
3. After login, redirected back with auth token
4. Service validates token with Keycloak
5. Access granted to authenticated users

### Kong API Gateway Patterns

- All API services routed through Kong
- Path-based routing: `/services/{service-name}/*`
- Global plugins: CORS, rate limiting, authentication
- Strip path to forward clean URLs to services

### Docker Networks

- `frontend`: Services accessed by users
- `backend`: Internal services and databases
- `monitoring`: Observability stack

### Security Considerations

- All external traffic via HTTPS (Caddy + Let's Encrypt)
- Internal traffic unencrypted (trusted Docker network)
- Secrets in environment variables (consider HashiCorp Vault for production)
- Database connections via pgbouncer for pooling

### Monitoring Strategy

- Prometheus scrapes all services
- Loki aggregates logs via Promtail
- Jaeger collects distributed traces
- Grafana visualizes everything
- Uptime Kuma for external monitoring

### Development Tips

- Use `docker-compose logs -f {service}` for debugging
- Access Kong Admin API at `http://localhost:8001` during development
- Grafana dashboards auto-provisioned from `services/grafana/dashboards`
- All services support hot-reload in development mode

### Common Issues

- Certificate errors: Ensure all subdomains have A records pointing to server
- Auth loops: Check Keycloak client redirect URIs
- Service discovery: Use Docker service names, not localhost
- Port conflicts: Only Caddy should bind to 80/443

### Future Enhancements

- Add HashiCorp Vault for secret management
- Implement service mesh (Istio/Linkerd) for advanced routing
- Add horizontal scaling with Docker Swarm/Kubernetes
- Implement blue-green deployments
