# Keycloak + Kong Gateway OIDC Implementation Plan

## Current State Analysis
- Keycloak and Kong modules exist but are placeholders (null_resource)
- Gateway API infrastructure already configured with edge Gateway
- HTTPRoutes exist for keycloak, grafana, temporal with OIDC annotations
- Network policies configured for Keycloak and Kong access
- External PostgreSQL database available (postgres-postgresql service)
- Cert-manager and wildcard TLS certificates working
- External Secrets Operator configured for secret management

## Implementation Steps

### 1. Implement Keycloak Terraform Module
- Replace placeholder in `infra/terraform/modules/keycloak/main.tf`
- Deploy Keycloak Helm chart (codecentric/keycloak)
- Configure external PostgreSQL connection
- Set up proper resource limits and security context
- Create Keycloak database in existing PostgreSQL

### 2. Create Keycloak Helm Values
- Configure `infra/terraform/helm-values/keycloak.yaml`
- Disable internal PostgreSQL (`postgresql.enabled: false`)
- Configure external database connection to postgres-postgresql service
- Set up admin credentials via secrets
- Configure realm and OIDC client for Kong

### 3. Implement Kong Gateway Terraform Module
- Replace placeholder in `infra/terraform/modules/kong/main.tf`
- Deploy Kong Helm chart with Gateway API support
- Enable OIDC and rate-limiting plugins
- Configure LoadBalancer service with static IP (192.168.1.251)

### 4. Create Kong Helm Values
- Configure `infra/terraform/helm-values/kong.yaml`
- Enable Gateway API controller
- Configure proxy service with static IP
- Set up admin API access
- Enable required plugins (oidc, rate-limiting)

### 5. Create Kong Plugins
- Global rate limiting plugin (100 req/min per IP)
- OIDC authentication plugin (Keycloak integration)
- Apply plugins via KongClusterPlugin resources

### 6. Update HTTPRoutes
- Ensure all existing routes have OIDC authentication
- Add missing routes for: alertmanager, kuma, mailhog, opensearch, pgadmin, prometheus, sonarqube, web
- Configure proper backend service references

### 7. Update Terraform Main Configuration
- Add keycloak and kong modules to `infra/terraform/main.tf`
- Set proper dependencies (keycloak depends on postgres, kong depends on cert_issuers)
- Update Makefile to include auth modules

### 8. Database Setup
- Create Keycloak database and user in PostgreSQL
- Configure proper permissions and extensions

### 9. Secrets Management
- Update OIDC secrets with proper Keycloak client credentials
- Ensure External Secrets Operator pulls production secrets
- Configure Keycloak admin credentials

### 10. Network Security
- Verify existing network policies are sufficient
- Ensure Kong can access all backend services
- Confirm Keycloak can access PostgreSQL

## Key Configuration Details

### Keycloak Configuration
- External PostgreSQL: `postgres-postgresql.data.svc.cluster.local:5432`
- Database: `keycloak` (to be created)
- Namespace: `auth`
- Admin realm and Kong client configuration

### Kong Configuration
- Namespace: `gateway`
- LoadBalancer IP: `192.168.1.251`
- Gateway API controller enabled
- OIDC discovery: `https://keycloak.aldous.info/realms/master/.well-known/openid-configuration`

### Required HTTPRoutes
- alertmanager.aldous.info → observability/alertmanager:9093
- grafana.aldous.info → observability/kube-prometheus-stack-grafana:80
- keycloak.aldous.info → auth/keycloak:8080
- kuma.aldous.info → observability/uptime-kuma:3001
- mailhog.aldous.info → devtools/mailhog:8025
- opensearch.aldous.info → search/opensearch-cluster-master:9200
- pgadmin.aldous.info → data/pgadmin4:80
- prometheus.aldous.info → observability/kube-prometheus-stack-prometheus:9090
- sonarqube.aldous.info → devtools/sonarqube:9000
- temporal.aldous.info → temporal/temporal-web:8080
- web.aldous.info → apps/web:3000

## Security Considerations
- All routes require OIDC authentication except Keycloak itself
- Rate limiting applied globally (100 req/min per IP)
- TLS termination at Kong with wildcard certificate
- Network policies restrict access between namespaces
- Secrets managed via External Secrets Operator