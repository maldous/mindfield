# Terraform and MicroK8s Migration Plan - FINAL VERSION

This plan outlines the complete migration from Docker Compose to a Terraform-managed MicroK8s cluster, ensuring cloud portability and addressing all security vulnerabilities.

**ALL ACTIONS ARE MAKEFILE-DRIVEN** - Each phase has clear deliverables and validation targets that can be tested independently.

## CRITICAL SECURITY FIXES (IMMEDIATE)

**🚨 TOP PRIORITY - SECURITY VULNERABILITIES:**
1. **Plaintext DB credentials committed** - `1/services/pgbouncer/databases.ini` contains live passwords
2. **MD5 hashes committed** - `1/services/pgbouncer/userlist.txt` has MD5 hashes
3. **Wide port exposure** - Dozens of `0.0.0.0` host ports in `docker-compose.net.yml`
4. **Insecure telemetry** - OTEL → Jaeger with `tls.insecure: true`, OpenSearch with `tls.insecure: true`
5. **PgBouncer binding 0.0.0.0** - Should be ClusterIP only
6. **AKHQ security disabled** - `micronaut.security.enabled: false`

## 1. Project Structure and Initialization

```
terraform/
  envs/
    local/
      backend.tf              # Local backend config
      provider.tf             # Provider versions (pinned)
      variables.tf            # Environment variables
      terraform.tfvars        # Local values
      main.tf                 # Main infrastructure
    prod/
      backend.tf              # S3/MinIO + DynamoDB backend
      provider.tf             # Same providers, different config
      variables.tf            # Production variables
      terraform.tfvars        # Production values
      main.tf                 # Production overrides
  modules/
    cluster/                  # MicroK8s setup and addons
    metallb/                  # Load balancer configuration
    cert_manager/             # Certificate management
    kong/                     # Kong Ingress Controller
    postgres/                 # PostgreSQL with init jobs
    keycloak/                 # Keycloak identity provider
    kafka/                    # Kafka messaging
    observability/            # Grafana stack (Tempo/Loki/Prometheus)
    jobs/                     # Reusable job modules
    security/                 # NetworkPolicies, PSS, RBAC
k8s/
  configs/                  # Configuration templates
    akhq/application.yml
    alertmanager/alertmanager.yml
    blackbox/blackbox.yml
    grafana/dashboards/*.json
    loki/local-config.yml
    prometheus/prometheus.yml
    promtail/promtail-config.yml
    pgbouncer/pgbouncer.ini   # Template without secrets
    temporal/config.yaml
  gateway/                  # Gateway API manifests
    gateway.yaml
    httproutes/
    tcproutes/
    kongplugins/
  secrets/                  # SOPS-encrypted secrets
    local.yaml              # Local environment secrets
    prod.yaml               # Production secrets
scripts/
  build_push.sh             # Image build and push
  setup_cluster.sh          # MicroK8s setup automation
  rotate_secrets.sh         # Secret rotation
flux/                       # GitOps manifests (future)
  clusters/
  apps/
```

## 2. Cluster Prerequisites and Setup

### 2.1 MicroK8s Configuration
- **CNI**: Flannel (dev), Calico (prod/cloud)
- **Default StorageClass**: `microk8s-hostpath` (dev), `gp3/pd-ssd` (prod)
- **Node Sizing Matrix**:
  - **Dev (single node)**: 8 CPU, 16GB RAM, 100GB disk
  - **Staging**: 3 nodes, 4 CPU, 8GB RAM, 50GB disk each
  - **Prod**: 5+ nodes, 8 CPU, 16GB RAM, 100GB disk each

### 2.2 Required Add-ons
```bash
# Local dev - DO NOT enable ingress or cert-manager addons
# We use Helm-managed versions to avoid version conflicts
microk8s enable dns storage metallb registry
```

## 3. GitOps Integration

**Bootstrap Flux via Terraform**:
- Terraform manages infrastructure (LB IPs, DNS, buckets, PKI, Flux bootstrap)
- Flux manages application lifecycles via HelmReleases in git
- Clear separation of concerns

## 4. Ingress & Gateway (Kong Single Entry Point)

### 4.1 Remove Caddy Entirely
- **DELETE**: `1/docker/Dockerfile.caddy`, `1/services/caddy/Caddyfile`
- **MIGRATE**: Security headers, HSTS, rate limits to KongPlugins

### 4.2 Kong Gateway API Implementation
```yaml
# Gateway (single LoadBalancer)
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: edge, namespace: gateway}
spec:
  gatewayClassName: kong
  listeners:
  - name: https
    protocol: HTTPS
    port: 443
    tls: {mode: Terminate, certificateRefs: [{name: edge-cert}]}

# HTTPRoute per service
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: keycloak, namespace: auth}
spec:
  parentRefs: [{name: edge, namespace: gateway}]
  hostnames: ["keycloak.${DOMAIN}"]
  rules:
  - backendRefs: [{name: keycloak, port: 8080}]
  annotations:
    konghq.com/cluster-plugins: "global-rate"  # Use cluster-plugins

# Global rate limiting (cluster-scoped)
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata: {name: global-rate}
plugin: rate-limiting
config:
  minute: 6000
  policy: local  # Change to 'redis' for HA
  limit_by: ip

---
# Redis for rate limiting (optional HA)
apiVersion: apps/v1
kind: Deployment
metadata: {name: redis, namespace: gateway}
spec:
  replicas: 1
  selector: {matchLabels: {app: redis}}
  template:
    metadata: {labels: {app: redis}}
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports: [{containerPort: 6379}]
        resources:
          requests: {cpu: 100m, memory: 128Mi}
          limits: {cpu: 500m, memory: 512Mi}
---
apiVersion: v1
kind: Service
metadata: {name: redis, namespace: gateway}
spec:
  selector: {app: redis}
  ports: [{port: 6379, targetPort: 6379}]
```

### 4.3 Port Exposure Elimination
**REMOVE ALL** `0.0.0.0` host ports from `docker-compose.net.yml`:
- Keep **ONLY** essential LoadBalancer services: Kong Gateway
- **Internal access**: Use `kubectl port-forward` for debugging
- **External access**: Route through Kong Gateway

## 5. Secrets & Credentials (CRITICAL SECURITY FIX)

### 5.1 Immediate Actions
1. **ROTATE ALL CREDENTIALS** in `1/services/pgbouncer/databases.ini`
2. **DELETE** committed `userlist.txt` and `databases.ini`
3. **IMPLEMENT** SOPS + External Secrets Operator

### 5.2 SOPS + ESO Implementation
```yaml
# External Secret pulling from SOPS
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: {name: pg-secrets, namespace: data}
spec:
  refreshInterval: 1h
  secretStoreRef: {name: sops-store, kind: ClusterSecretStore}
  target: {name: pg-credentials, creationPolicy: Owner}
  data:
  - secretKey: POSTGRES_PASSWORD
    remoteRef: {key: postgres/password}
  - secretKey: KC_DB_PASSWORD
    remoteRef: {key: keycloak/password}
```

### 5.3 PgBouncer Security Upgrade
- **REPLACE** MD5 with SCRAM-SHA-256: `auth_type = scram-sha-256`
- **USE** `auth_query` against Postgres instead of static files
- **BIND** to ClusterIP only: `listen_addr = 0.0.0.0` → `listen_addr = *`

## 6. Helm Chart Strategy (Mainstream Components)

### 6.1 Chart Versions (Centralized)
```hcl
# terraform/modules/versions.tf
locals {
  chart_versions = {
    kong                    = "2.51.0"    # KIC 3.4.4 for Gateway API
    temporal                = "0.64.0"    # Server 1.28.0
    kube_prometheus_stack   = "75.15.0"   # Latest stable
    loki                    = "6.33.0"    # Loki v3.x series
    tempo                   = "2.6.0"     # Latest stable
    cert_manager            = "1.18.2"    # Latest v1.18.x
    velero                  = "2.13.6"    # vmware-tanzu repo
    metallb                 = "0.14.8"    # Latest stable
    bitnami_postgresql      = "15.2.5"    # Stable PostgreSQL
    external_secrets        = "0.12.1"    # ESO latest
  }
  
  # Gateway API CRDs version
  gateway_api_version = "v1.3.0"
}
```

### 6.2 Core Infrastructure
```hcl
# PostgreSQL
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = local.chart_versions.bitnami_postgresql
  namespace  = "data"
  
  values = [yamlencode({
    auth = {
      postgresPassword = var.postgres_password
      database = var.database_name
    }
    primary = {
      persistence = {
        size = "50Gi"
        storageClass = "microk8s-hostpath"
      }
      resources = {
        requests = { cpu = "500m", memory = "1Gi" }
  })]
      }

### 6.3 cert-manager Configuration
```yaml
# ClusterIssuer for Cloudflare DNS-01 (supports wildcards)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    email: ${EMAIL}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef: {name: le-account-key}
    solvers:
    - dns01:
        cloudflare:
          email: ${EMAIL}
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: token

---
# Wildcard TLS certificate for Kong
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: edge-cert, namespace: gateway}
spec:
  secretName: edge-cert
  issuerRef: {name: letsencrypt-dns, kind: ClusterIssuer}
  dnsNames: ["${DOMAIN}", "*.${DOMAIN}"]

---
# cert-manager RBAC for DNS-01 solver
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-manager-dns-solver
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["external-secrets.io"]
  resources: ["externalsecrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-manager-dns-solver
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-manager-dns-solver
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: cert-manager
```

### 6.4 Observability Stack (Grafana Trio)
        limits = { cpu = "2", memory = "4Gi" }
    }
# Gateway API CRDs (MUST install before Kong)
resource "kubernetes_manifest" "gateway_api_crds" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "gateway-api-install"
      namespace = "kube-system"
    }
  }
  
  # Use local-exec to install CRDs
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/standard-install.yaml"
  }
}

# Kong Ingress Controller (KIC 3.x with Gateway API)
resource "helm_release" "kong" {
  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "kong"
  version    = local.chart_versions.kong
  namespace  = "gateway"
  
  depends_on = [kubernetes_manifest.gateway_api_crds]
  
    ingressController = {
      enabled      = true
      ingressClass = "kong"
    }
}
  values = [yamlencode({
    ingressController = { enabled = true }
    gateway = { enabled = true }
    proxy = {
      type = "LoadBalancer"
      annotations = {
        "metallb.universe.tf/address-pool" = "default"
      }
    }
    env = { KONG_DATABASE = "off" }  # DB-less mode
  })]
}

# Temporal (replacing Cadence)
resource "helm_release" "temporal" {
  name       = "temporal"
  repository = "https://temporalio.github.io/helm-charts"
  chart      = "temporal"
  version    = local.chart_versions.temporal
  namespace  = "temporal"
  
  values = [yamlencode({
    server = {
      image = {
        tag = "1.28.0"  # Pin server version
      }
    }
    # Use PostgreSQL instead of Cassandra
    cassandra = { enabled = false }
    postgresql = { enabled = true }
  })]
}
```

### 6.2 Observability Stack (Grafana Trio)
```hcl
# Kube-Prometheus-Stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.1.0"  # PINNED
  namespace  = "observability"
  
  values = [yamlencode({
    grafana = {
      adminPassword = var.grafana_admin_password
      persistence = { enabled = true, size = "10Gi" }
    }
    prometheus = {
      prometheusSpec = {
        retention = "7d"
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "microk8s-hostpath"
              accessModes = ["ReadWriteOnce"]
              resources = { requests = { storage = "50Gi" } }
  })]
            }

### 6.3 Observability Stack (Grafana Trio)
  version    = local.chart_versions.kube_prometheus_stack
          }
        # Higher resource limits for observability namespace
        resources = {
          requests = { cpu = "1", memory = "2Gi" }
          limits = { cpu = "4", memory = "8Gi" }
        }
        }
## 13. Makefile-Driven Implementation
### 13.1 Master Makefile Structure
```makefile
.PHONY: *
.DEFAULT_GOAL := help
.ONESHELL:
SHELL := bash

# Load environment variables
ifneq (,$(wildcard .env))
	include .env
	export
endif

# Chart versions (centralized)
CHART_VERSIONS := \
	kong=2.51.0 \
	temporal=0.64.0 \
	kube-prometheus-stack=75.15.0 \
	loki=6.33.0 \
	tempo=2.6.0 \
	cert-manager=1.18.2 \
	velero=2.13.6 \
	metallb=0.14.8 \
	bitnami-postgresql=15.2.5 \
	external-secrets=0.12.1

GATEWAY_API_VERSION := v1.3.0
REG ?= localhost:32000
TAG ?= $(shell git rev-parse --short HEAD)
DOMAIN ?= aldous.info

# =============================================================================
# HELP
# =============================================================================
help: ## Show this help message
	@echo 'Usage: make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $1, $2}' $(MAKEFILE_LIST)

# =============================================================================
# PHASE 0: SECURITY & FOUNDATION (IMMEDIATE)
# =============================================================================
phase0: phase0-security phase0-cluster phase0-validate ## Complete Phase 0: Security & Foundation

phase0-security: ## CRITICAL: Rotate credentials and setup SOPS
	@echo "🚨 Phase 0: Security Fixes"
	@if [ -f "1/services/pgbouncer/databases.ini" ]; then \
		echo "ERROR: databases.ini still contains plaintext credentials!"; \
		echo "Please rotate all credentials and remove this file."; \
		exit 1; \
	fi
	@if [ -f "1/services/pgbouncer/userlist.txt" ]; then \
		echo "ERROR: userlist.txt still contains MD5 hashes!"; \
		echo "Please remove this file and implement SCRAM-SHA-256."; \
		exit 1; \
	fi
	@echo "✅ Security validation passed"

phase0-cluster: ## Setup MicroK8s with required addons
	@echo "🏗️ Phase 0: Cluster Setup"
	microk8s status --wait-ready
	microk8s enable dns storage metallb registry
	@echo "Configuring MetalLB IP pool..."
	kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 10.0.0.200-10.0.0.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF
	@echo "✅ MicroK8s cluster ready"

phase0-validate: ## Validate Phase 0 deliverables
	@echo "🔍 Phase 0: Validation"
	@echo "Checking MicroK8s addons..."
	microk8s status | grep -E "dns|storage|metallb|registry" | grep enabled
	@echo "Checking MetalLB configuration..."
	kubectl get ipaddresspool -n metallb-system default
	@echo "✅ Phase 0 validation complete"

# =============================================================================
# PHASE 1: CORE INFRASTRUCTURE
# =============================================================================
phase1: phase1-prereqs phase1-postgres phase1-kong phase1-validate ## Complete Phase 1: Core Infrastructure

phase1-prereqs: ## Install Gateway API CRDs and cert-manager
	@echo "🔧 Phase 1: Prerequisites"
	@echo "Installing Gateway API CRDs..."
	kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/standard-install.yaml
	@echo "Adding Helm repositories..."
	helm repo add kong https://charts.konghq.com
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo add jetstack https://charts.jetstack.io
	helm repo add external-secrets https://charts.external-secrets.io
	helm repo update
	@echo "Installing cert-manager..."
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--version $(CERT_MANAGER_CHART_VERSION) \
		--set installCRDs=true
	@echo "✅ Prerequisites installed"

phase1-postgres: ## Deploy PostgreSQL with Bitnami Helm
	@echo "🗄️ Phase 1: PostgreSQL"
	kubectl create namespace data --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install postgresql bitnami/postgresql \
		--namespace data \
		--version $(POSTGRES_CHART_VERSION) \
		--set auth.postgresPassword="$(POSTGRES_PASSWORD)" \
		--set auth.database="$(NAME)" \
		--set primary.persistence.size=50Gi \
		--set primary.persistence.storageClass=microk8s-hostpath
	@echo "✅ PostgreSQL deployed"

phase1-kong: ## Deploy Kong Ingress Controller (DB-less)
	@echo "🦍 Phase 1: Kong Gateway"
	kubectl create namespace gateway --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install kong kong/kong \
		--namespace gateway \
		--version $(KONG_CHART_VERSION) \
		--set ingressController.enabled=true \
		--set ingressController.ingressClass=kong \
		--set gateway.enabled=true \
		--set proxy.type=LoadBalancer \
		--set proxy.annotations."metallb\.universe\.tf/address-pool"=default \
		--set env.KONG_DATABASE=off
	@echo "✅ Kong Gateway deployed"

phase1-validate: ## Validate Phase 1 deliverables
	@echo "🔍 Phase 1: Validation"
	@echo "Checking Gateway API CRDs..."
	kubectl get crd gateways.gateway.networking.k8s.io
	@echo "Checking cert-manager..."
	kubectl get pods -n cert-manager
	@echo "Checking PostgreSQL..."
	kubectl get pods -n data -l app.kubernetes.io/name=postgresql
	@echo "Checking Kong Gateway..."
	kubectl get pods -n gateway -l app.kubernetes.io/name=kong
	@echo "Checking LoadBalancer IP..."
	kubectl get svc -n gateway kong-kong-proxy
	@echo "✅ Phase 1 validation complete"

# =============================================================================
# PHASE 2: IDENTITY & SECURITY
# =============================================================================
phase2: phase2-keycloak phase2-policies phase2-validate ## Complete Phase 2: Identity & Security

phase2-keycloak: ## Deploy Keycloak behind Kong
	@echo "🔐 Phase 2: Keycloak"
	kubectl create namespace auth --dry-run=client -o yaml | kubectl apply -f -
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	helm upgrade --install keycloak bitnami/keycloak \
		--namespace auth \
		--version $(KEYCLOAK_CHART_VERSION) \
		--set postgresql.enabled=false \
		--set externalDatabase.host=postgresql.data.svc.cluster.local \
		--set externalDatabase.user=keycloak \
		--set externalDatabase.password="$(KC_DB_PASSWORD)" \
		--set externalDatabase.database=keycloak \
		--set auth.adminUser=admin \
		--set auth.adminPassword="$(KC_BOOTSTRAP_ADMIN_PASSWORD)" \
		--set proxy=edge \
		--set proxyAddressForwarding=true
	@echo "✅ Keycloak deployed"

phase2-policies: ## Implement NetworkPolicies and Pod Security Standards
	@echo "🛡️ Phase 2: Security Policies"
	@echo "Applying Pod Security Standards..."
	kubectl label namespace data pod-security.kubernetes.io/enforce=restricted --overwrite
	kubectl label namespace auth pod-security.kubernetes.io/enforce=restricted --overwrite
	kubectl label namespace gateway pod-security.kubernetes.io/enforce=baseline --overwrite
	@echo "Applying NetworkPolicies..."
	kubectl apply -f k8s/security/
	@echo "✅ Security policies applied"

phase2-validate: ## Validate Phase 2 deliverables
	@echo "🔍 Phase 2: Validation"
	@echo "Checking Keycloak..."
	kubectl get pods -n auth -l app.kubernetes.io/name=keycloak
	@echo "Checking Pod Security Standards..."
	kubectl get namespace data -o jsonpath='{.metadata.labels}'
	@echo "Checking NetworkPolicies..."
	kubectl get networkpolicy --all-namespaces
	@echo "✅ Phase 2 validation complete"

# =============================================================================
# PHASE 3: OBSERVABILITY
# =============================================================================
phase3: phase3-prometheus phase3-loki phase3-tempo phase3-validate ## Complete Phase 3: Observability

phase3-prometheus: ## Deploy kube-prometheus-stack
	@echo "📊 Phase 3: Prometheus Stack"
	kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
		--namespace observability \
		--version $(KPS_CHART_VERSION) \
		--set grafana.adminPassword="$(GRAFANA_DEFAULT_PASSWORD)" \
		--set grafana.persistence.enabled=true \
		--set grafana.persistence.size=10Gi \
		--set prometheus.prometheusSpec.retention=7d \
		--set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=microk8s-hostpath \
		--set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
	@echo "✅ Prometheus stack deployed"

phase3-loki: ## Deploy Loki (v3.x)
	@echo "📝 Phase 3: Loki"
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update
	helm upgrade --install loki grafana/loki \
		--namespace observability \
		--version $(LOKI_CHART_VERSION) \
		--set deploymentMode=SingleBinary \
		--set loki.commonConfig.replication_factor=1 \
		--set loki.storage.type=filesystem \
		--set singleBinary.persistence.enabled=true \
		--set singleBinary.persistence.size=50Gi \
		--set singleBinary.persistence.storageClass=microk8s-hostpath
	@echo "✅ Loki deployed"

phase3-tempo: ## Deploy Tempo
	@echo "🔍 Phase 3: Tempo"
	helm upgrade --install tempo grafana/tempo \
		--namespace observability \
		--version $(TEMPO_CHART_VERSION) \
		--set tempo.storage.trace.backend=local \
		--set tempo.storage.trace.local.path=/var/tempo/traces \
		--set persistence.enabled=true \
		--set persistence.size=50Gi \
		--set persistence.storageClass=microk8s-hostpath
	@echo "✅ Tempo deployed"

phase3-validate: ## Validate Phase 3 deliverables
	@echo "🔍 Phase 3: Validation"
	@echo "Checking Prometheus..."
	kubectl get pods -n observability -l app.kubernetes.io/name=prometheus
	@echo "Checking Grafana..."
	kubectl get pods -n observability -l app.kubernetes.io/name=grafana
	@echo "Checking Loki..."
	kubectl get pods -n observability -l app.kubernetes.io/name=loki
	@echo "Checking Tempo..."
	kubectl get pods -n observability -l app.kubernetes.io/name=tempo
	@echo "✅ Phase 3 validation complete"

# =============================================================================
# PHASE 4: APPLICATIONS
# =============================================================================
phase4: phase4-kafka phase4-temporal phase4-validate ## Complete Phase 4: Applications

phase4-kafka: ## Migrate Kafka + Connect + AKHQ
	@echo "📨 Phase 4: Kafka Stack"
	kubectl create namespace messaging --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install kafka bitnami/kafka \
		--namespace messaging \
		--set persistence.enabled=true \
		--set persistence.size=50Gi \
		--set persistence.storageClass=microk8s-hostpath
	@echo "✅ Kafka deployed"

phase4-temporal: ## Deploy Temporal (replace Cadence)
	@echo "⏰ Phase 4: Temporal"
	kubectl create namespace temporal --dry-run=client -o yaml | kubectl apply -f -
	helm repo add temporalio https://temporalio.github.io/helm-charts
	helm repo update
	@echo "Creating Temporal database users..."
	kubectl exec -n data postgresql-0 -- psql -U postgres -c "CREATE USER temporal WITH PASSWORD '$(TEMPORAL_DB_PASSWORD)'; CREATE DATABASE temporal OWNER temporal;" || true
	kubectl exec -n data postgresql-0 -- psql -U postgres -c "CREATE USER temporal_visibility WITH PASSWORD '$(TEMPORAL_VIS_DB_PASSWORD)'; CREATE DATABASE temporal_visibility OWNER temporal_visibility;" || true
	@echo "Rendering Temporal values with environment variables..."
	envsubst < k8s/configs/temporal-values.yaml > /tmp/temporal-values.rendered.yaml
	helm upgrade --install temporal temporalio/temporal \
		--namespace temporal \
		--version $(TEMPORAL_CHART_VERSION) \
		--values /tmp/temporal-values.rendered.yaml
	@echo "✅ Temporal deployed"

phase4-validate: ## Validate Phase 4 deliverables
	@echo "🔍 Phase 4: Validation"
	@echo "Checking Kafka..."
	kubectl get pods -n messaging -l app.kubernetes.io/name=kafka
	@echo "Checking Temporal..."
	kubectl get pods -n temporal -l app.kubernetes.io/name=temporal
	@echo "✅ Phase 4 validation complete"

# =============================================================================
# PHASE 5: GITOPS & AUTOMATION
# =============================================================================
phase5: phase5-flux phase5-velero phase5-validate ## Complete Phase 5: GitOps & Automation

phase5-flux: ## Bootstrap Flux
	@echo "🔄 Phase 5: Flux GitOps"
	@echo "Installing Flux CLI..."
	curl -s https://fluxcd.io/install.sh | sudo bash
	@echo "Bootstrapping Flux..."
	flux bootstrap git \
		--url=https://github.com/$(GITHUB_USER)/$(GITHUB_REPO) \
		--branch=main \
		--path=./flux/clusters/local
	@echo "✅ Flux bootstrapped"

phase5-velero: ## Implement Velero backups
	@echo "💾 Phase 5: Velero Backups"
	helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
	helm repo update
	helm upgrade --install velero vmware-tanzu/velero \
		--namespace velero --create-namespace \
		--version $(VELERO_CHART_VERSION) \
		--set configuration.backupStorageLocation[0].name=default \
		--set configuration.backupStorageLocation[0].provider=aws \
		--set configuration.backupStorageLocation[0].bucket=$(BACKUP_BUCKET) \
		--set configuration.backupStorageLocation[0].config.region=$(AWS_REGION) \
		--set configuration.backupStorageLocation[0].config.s3ForcePathStyle=true \
		--set configuration.backupStorageLocation[0].config.s3Url=$(MINIO_ENDPOINT)
	@echo "✅ Velero deployed"

phase5-validate: ## Validate Phase 5 deliverables
	@echo "🔍 Phase 5: Validation"
	@echo "Checking Flux..."
	flux get all
	@echo "Checking Velero..."
	kubectl get pods -n velero -l app.kubernetes.io/name=velero
	@echo "✅ Phase 5 validation complete"

# =============================================================================
# PHASE 6: CLEANUP
# =============================================================================
phase6: phase6-cleanup phase6-validate ## Complete Phase 6: Cleanup

phase6-cleanup: ## Remove Docker Compose files and old infrastructure
	@echo "🧹 Phase 6: Cleanup"
	@echo "Archiving old infrastructure..."
	mkdir -p archive/$(shell date +%Y%m%d)
	mv docker/ archive/$(shell date +%Y%m%d)/ || true
	mv 1/ archive/$(shell date +%Y%m%d)/ || true
	mv Makefile.old archive/$(shell date +%Y%m%d)/ || true
	@echo "✅ Cleanup complete"

phase6-validate: ## Validate Phase 6 deliverables
	@echo "🔍 Phase 6: Validation"
	@echo "Checking archived files..."
	ls -la archive/
	@echo "✅ Phase 6 validation complete"

# =============================================================================
# UTILITIES
# =============================================================================
status: ## Show cluster status
	@echo "📊 Cluster Status"
	@echo "MicroK8s Status:"
	microk8s status
	@echo "\nNamespaces:"
	kubectl get namespaces
	@echo "\nPods by namespace:"
	kubectl get pods --all-namespaces
	@echo "\nServices with external IPs:"
	kubectl get svc --all-namespaces -o wide | grep -E "LoadBalancer|NodePort"

clean: ## Clean up failed deployments
	@echo "🧽 Cleaning up..."
	helm list --all-namespaces --failed -q | xargs -r helm delete
	kubectl get pods --all-namespaces --field-selector=status.phase=Failed -o name | xargs -r kubectl delete

reset: ## Reset entire cluster (DANGEROUS)
	@echo "⚠️  This will destroy the entire cluster!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	if [[ $REPLY =~ ^[Yy]$ ]]; then \
		microk8s reset; \
	else \
		echo "Cancelled."; \
	fi

# =============================================================================
# TESTING
# =============================================================================
test-phase0: phase0-validate ## Test Phase 0 deliverables
test-phase1: phase1-validate ## Test Phase 1 deliverables
test-phase2: phase2-validate ## Test Phase 2 deliverables
test-phase3: phase3-validate ## Test Phase 3 deliverables
test-phase4: phase4-validate ## Test Phase 4 deliverables
test-phase5: phase5-validate ## Test Phase 5 deliverables
test-phase6: phase6-validate ## Test Phase 6 deliverables

test-all: test-phase0 test-phase1 test-phase2 test-phase3 test-phase4 test-phase5 test-phase6 ## Test all phases

# =============================================================================
# COMPLETE MIGRATION
# =============================================================================
migrate: phase0 phase1 phase2 phase3 phase4 phase5 phase6 ## Complete full migration
	@echo "🎉 Migration complete!"
	@echo "Your Kubernetes cluster is ready."
	@echo "\nNext steps:"
	@echo "1. Configure DNS to point to Kong LoadBalancer IP"
	@echo "2. Setup monitoring dashboards"
	@echo "3. Test application deployments"
	@echo "4. Configure backup schedules"
```

## 14. Implementation Phases

      }
    }
}
# Loki Stack
resource "helm_release" "loki_stack" {
  name       = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "2.10.2"  # PINNED
  namespace  = "observability"
  
  values = [yamlencode({
    loki = {
      persistence = { enabled = true, size = "50Gi" }
    }
    grafana = { enabled = false }  # Use main Grafana
  })]
}

# Tempo
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.10.1"  # PINNED
  namespace  = "observability"
}
```

## 7. Security Baseline (Zero Trust)

### 7.1 Namespace Security
```yaml
# Namespace with Pod Security Standards
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data  # For NetworkPolicy selectors
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    name: observability
    # Relaxed limits for Prometheus resource usage
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: gateway
  labels:
    name: gateway
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline

---
# Default-deny NetworkPolicy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: default-deny, namespace: data}
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]

---
# DNS egress for all namespaces
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-dns, namespace: data}
spec:
  podSelector: {}
  policyTypes: ["Egress"]
  egress:
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53

---
# cert-manager solver traffic to Kong
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-cert-manager, namespace: gateway}
spec:
  podSelector: {matchLabels: {app.kubernetes.io/name: kong}}
  policyTypes: ["Ingress"]
  ingress:
  - from:
    - namespaceSelector: {matchLabels: {name: cert-manager}}
    ports:
    - protocol: TCP
      port: 8080

---
# Explicit egress for database access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: allow-db-egress, namespace: apps}
spec:
  podSelector:
    matchLabels: {app: web-app}
  policyTypes: ["Egress"]
  egress:
  - to:
    - namespaceSelector:
        matchLabels: {name: data}
    ports:
    - protocol: TCP
      port: 5432
  - to: []  # DNS
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### 7.2 Runtime Security
```yaml
# SecurityContext template
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
```

## 8. Observability (Secure Telemetry)

### 8.1 OTEL → Tempo Configuration
```yaml
# Secure OTEL config (replacing insecure paths)
exporters:
  otlp/tempo:
    endpoint: tempo.observability.svc.cluster.local:9095
    tls: {insecure: false}  # SECURE
    headers:
      authorization: "Bearer ${TEMPO_TOKEN}"
  loki:
    endpoint: http://loki.observability.svc.cluster.local:3100/loki/api/v1/push
    headers:
      authorization: "Bearer ${LOKI_TOKEN}"
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki]  # NOT OpenSearch

---
# OTEL Token Secret (managed by ESO)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: {name: otel-tokens, namespace: observability}
spec:
  refreshInterval: 1h
  secretStoreRef: {name: k8s-secrets-store, kind: ClusterSecretStore}
  target: {name: otel-credentials, creationPolicy: Owner}
  data:
  - secretKey: TEMPO_TOKEN
    remoteRef: {key: tempo-auth-secret, property: token}
  - secretKey: LOKI_TOKEN
    remoteRef: {key: loki-auth-secret, property: token}
```

### 8.2 Blackbox Exporter (Production TLS)
```yaml
# Secure blackbox module
modules:
  http_2xx_secure:
    prober: http
    timeout: 5s
    http:
      tls_config:
        insecure_skip_verify: false  # SECURE
        ca_file: /etc/ssl/certs/ca-certificates.crt
```

## 9. Database Strategy

### 9.1 PostgreSQL with Idempotent Init
```sql
-- Idempotent database initialization
CREATE ROLE IF NOT EXISTS keycloak WITH LOGIN PASSWORD '${KC_DB_PASSWORD}';
CREATE DATABASE IF NOT EXISTS keycloak OWNER keycloak;
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- Add ON CONFLICT DO NOTHING for all operations
INSERT INTO users (username, email) VALUES ('admin', 'admin@example.com') 
ON CONFLICT (username) DO NOTHING;
```

### 9.2 PgBouncer Secure Configuration
```ini
# Secure PgBouncer config
[pgbouncer]
auth_type = scram-sha-256  # NOT md5
auth_query = SELECT username, password FROM pgbouncer.users WHERE username=$1
listen_addr = *  # ClusterIP binding
listen_port = 5432
pool_mode = transaction
max_client_conn = 100
default_pool_size = 25
```

## 10. Resource Governance

### 10.1 Resource Quotas and Limits
```yaml
# Data namespace quota
apiVersion: v1
kind: ResourceQuota
metadata: {name: data-quota, namespace: data}
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"

---
# Observability namespace quota (higher limits for Prometheus)
apiVersion: v1
kind: ResourceQuota
metadata: {name: observability-quota, namespace: observability}
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    persistentvolumeclaims: "20"

---
# PodDisruptionBudget for critical services
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: postgres-pdb, namespace: data}
spec:
  minAvailable: 1
  selector:
    matchLabels: {app.kubernetes.io/name: postgresql}

---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: {name: kong-pdb, namespace: gateway}
spec:
  minAvailable: 1
  selector:
    matchLabels: {app.kubernetes.io/name: kong}

---
# HorizontalPodAutoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: {name: web-app-hpa, namespace: apps}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70

---
# PriorityClass for critical services
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: {name: critical-priority}
value: 1000
globalDefault: false
description: "Priority class for critical infrastructure services"
```

## 11. Backup and Disaster Recovery

### 11.1 Velero Installation
```hcl
resource "helm_release" "velero" {
  name       = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "7.1.4"  # PINNED
  namespace  = "velero"
  
  values = [yamlencode({
    configuration = {
      backupStorageLocation = [{
        name = "default"
        provider = "aws"
        bucket = var.backup_bucket
        config = {
          region = var.aws_region
          s3ForcePathStyle = "true"
          s3Url = var.minio_endpoint
        }
      }]
    }
    schedules = {
      daily = {
        disabled = false
        schedule = "0 2 * * *"
        template = {
          ttl = "720h"  # 30 days
          includedNamespaces = ["data", "apps"]
        }
  })]
      }

# Loki (v3.x chart - NOT loki-stack)
resource "helm_release" "loki" {
  name       = "loki"
  chart      = "loki"
  version    = local.chart_versions.loki
    deploymentMode = "SingleBinary"  # For dev/small clusters
      commonConfig = {
        replication_factor = 1
      }
      storage = {
        type = "filesystem"
      }
    }
    singleBinary = {
      persistence = {
        enabled = true
        size = "50Gi"
        storageClass = "microk8s-hostpath"
      }
    }
}
  version    = local.chart_versions.tempo
  
  values = [yamlencode({
    tempo = {
      storage = {
        trace = {
          backend = "local"
          local = {
            path = "/var/tempo/traces"
          }
        }
      }
    }
    persistence = {
      enabled = true
      size = "50Gi"
      storageClass = "microk8s-hostpath"
    }
  })]
```
### 11.2 Database Backup Strategy
```yaml
# PostgreSQL backup CronJob
apiVersion: batch/v1
kind: CronJob
metadata: {name: postgres-backup, namespace: data}
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:17-alpine
            command:
            - /bin/bash
            - -c
            - |
              pg_dumpall -h postgresql -U postgres | \
              gzip | \
              aws s3 cp - s3://${BACKUP_BUCKET}/postgres/$(date +%Y%m%d_%H%M%S).sql.gz
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: pg-credentials
                  key: POSTGRES_PASSWORD
          restartPolicy: OnFailure
```

## 12. Terraform State Management

### 12.1 Remote Backend Configuration
```hcl
# terraform/envs/local/backend.tf
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# terraform/envs/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "mindfield/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## 13. Implementation Phases

### Phase 0: Security & Foundation (IMMEDIATE)
- [ ] **CRITICAL**: Rotate all credentials in `databases.ini`
- [ ] Remove all `0.0.0.0` port bindings
- [ ] Setup SOPS + age encryption
- [ ] Install MicroK8s with required addons
- [ ] Configure MetalLB IP pool

### Phase 1: Core Infrastructure
- [ ] Deploy PostgreSQL with Bitnami Helm
- [ ] Deploy Kong Ingress Controller (DB-less)
- [ ] Setup cert-manager + LetsEncrypt
- [ ] Implement secure PgBouncer with SCRAM

### Phase 2: Identity & Security
- [ ] Deploy Keycloak behind Kong
- [ ] Implement NetworkPolicies (default-deny)
- [ ] Setup Pod Security Standards
- [ ] Configure OIDC authentication flow

### Phase 3: Observability
- [ ] Deploy kube-prometheus-stack
- [ ] Deploy Loki + Tempo (replace OpenSearch/Jaeger)
- [ ] Configure secure OTEL collector
- [ ] Setup Grafana dashboards

### Phase 4: Applications
- [ ] Migrate Kafka + Connect + AKHQ
- [ ] Deploy Temporal (replace Cadence)
- [ ] Migrate remaining applications

### Phase 5: GitOps & Automation
- [ ] Bootstrap Flux
- [ ] Implement Velero backups
- [ ] Setup CI/CD pipelines
- [ ] Document runbooks

### Phase 6: Cleanup
- [ ] Remove Docker Compose files
- [ ] Delete Caddy configurations
- [ ] Archive old infrastructure

## 14. Validation Checklist

### Security Validation
- [ ] No plaintext credentials in git
- [ ] All secrets managed by SOPS + ESO
- [ ] PgBouncer using SCRAM-SHA-256
- [ ] All telemetry paths use TLS
- [ ] NetworkPolicies enforced
- [ ] Pod Security Standards active

### Functionality Validation
- [ ] All services accessible via Kong Gateway
- [ ] OIDC login flow working
- [ ] Rate limiting active (6000 req/min)
- [ ] TLS certificates auto-renewing
- [ ] Monitoring and alerting functional
- [ ] Backup and restore tested

### Performance Validation
- [ ] Resource limits appropriate
- [ ] HPAs scaling correctly
- [ ] Database performance acceptable
- [ ] Network policies not blocking legitimate traffic

## 15. Upgrade Procedures

### 15.1 cert-manager Upgrade Path
```bash
# Check current version
kubectl get deployment -n cert-manager cert-manager -o jsonpath='{.spec.template.spec.containers[0].image}'

# Upgrade cert-manager (CRDs are managed by Helm with installCRDs=true)
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.18.2 \
  --reuse-values

# Verify webhook restart
kubectl rollout status deployment/cert-manager-webhook -n cert-manager

# Test certificate issuance
kubectl get certificates --all-namespaces
```

### 15.2 Kong Upgrade Path
```bash
# Check Gateway API CRDs compatibility
kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.spec.versions[*].name}'

# Upgrade Kong (DB-less mode preserves config in CRDs)
helm upgrade kong kong/kong \
  --namespace gateway \
  --version 2.51.0 \
  --reuse-values

# Verify Gateway API resources
kubectl get gateway,httproute --all-namespaces
```

### 15.3 Chart Version Management
```bash
# Update all chart versions in Makefile
make update-charts

# Test upgrades in staging first
make ENVIRONMENT=staging upgrade-all

# Production upgrade with validation
make ENVIRONMENT=prod upgrade-all validate-all
```

## 16. Emergency Procedures

### Rollback Plan
1. **Immediate**: Scale down new services
2. **Database**: Restore from backup if needed
3. **DNS**: Point back to old infrastructure
4. **Monitoring**: Ensure old alerting active

### Incident Response
1. **Security Breach**: Rotate all secrets immediately
2. **Data Loss**: Restore from Velero + database backups
3. **Network Issues**: Check NetworkPolicies and Kong config
4. **Performance**: Scale resources and check limits

### 5.2 External Secrets Operator + Kubernetes Secret Store
**Note**: ESO cannot read SOPS files directly. This implementation uses Kubernetes Secrets as the backend store for local development. For production, use AWS Secrets Manager, Azure Key Vault, or HashiCorp Vault.

### 5.2.1 ESO Installation
```hcl
# External Secrets Operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = local.chart_versions.external_secrets
}

### 6.3 cert-manager Configuration (Cloudflare DNS-01)
# ClusterIssuer for Cloudflare DNS-01 (supports wildcards)
  name: letsencrypt-dns
spec:
    - dns01:
        cloudflare:
          email: ${EMAIL}
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: token
# Wildcard TLS certificate for Kong
  issuerRef: {name: letsencrypt-dns, kind: ClusterIssuer}
  dnsNames: ["${DOMAIN}", "*.${DOMAIN}"]
```
**Setup Required:**
1. Create Cloudflare API Token with Zone:Read, DNS:Edit permissions
2. Run `./scripts/setup-cloudflare.sh` to create source secret
3. ESO will create the cert-manager secret from the source
4. Ensure Cloudflare manages DNS for your domain

**Note**: NetworkPolicy allowing Kong ports 80/443 is optional for DNS-01 but kept for flexibility.

  namespace  = "external-secrets-system"
  create_namespace = true
# Option 1: ESO with AWS Secrets Manager (Production)
kind: ClusterSecretStore
metadata: {name: aws-secrets-store}
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
            namespace: external-secrets-system
---
# Option 2: ESO with Kubernetes Secrets (Local Dev)
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata: {name: k8s-secrets-store}
spec:
  provider:
    kubernetes:
      server:
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
      auth:
        serviceAccount:
          name: external-secrets-sa
          namespace: external-secrets-system
---
# External Secret pulling from chosen store
apiVersion: external-secrets.io/v1beta1
  secretStoreRef: {name: k8s-secrets-store, kind: ClusterSecretStore}  # or aws-secrets-store
    remoteRef: {key: postgres-master-secret, property: password}
    remoteRef: {key: keycloak-db-secret, property: password}

- **BIND** to 0.0.0.0 inside Pod (isolation via Service + NetworkPolicy)
- **EXPOSE** via ClusterIP Service only (no NodePort/LoadBalancer)

-- Idempotent database initialization (PostgreSQL compatible)
DO $
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'keycloak') THEN
    CREATE ROLE keycloak LOGIN PASSWORD :'KC_DB_PASSWORD';
  END IF;
END$;

DO $
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'keycloak') THEN
    PERFORM dblink_exec('dbname=postgres', 'CREATE DATABASE keycloak OWNER keycloak');
  END IF;
END$;

listen_addr = 0.0.0.0  # Pod binding (isolated by Service)
```yaml
# PgBouncer Service (ClusterIP only)
apiVersion: v1
kind: Service
metadata: {name: pgbouncer, namespace: data}
spec:
  type: ClusterIP  # NO LoadBalancer/NodePort
  ports: [{name: psql, port: 5432, targetPort: 5432}]
  selector: {app: pgbouncer}
---
# NetworkPolicy for PgBouncer access control
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: pgbouncer-ingress, namespace: data}
spec:
  podSelector: {matchLabels: {app: pgbouncer}}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector: {matchLabels: {name: apps}}
    - namespaceSelector: {matchLabels: {name: auth}}
    ports: [{protocol: TCP, port: 5432}]
```

---
## NEXT STEPS CHECKLIST
**IMMEDIATE (Security Critical)**:
- [ ] Remove Caddy; install Kong KIC (DB-less) with Gateway API
  version    = local.chart_versions.velero
  create_namespace = true
- [ ] Introduce Flux; move Helm releases to GitOps
- [ ] Replace all committed secrets with SOPS; rotate passwords/keys
- [ ] Switch PgBouncer to SCRAM + auth_query; ClusterIP only
- [ ] OTEL → Tempo, Logs → Loki; secure all exporters
- [ ] Add NetworkPolicies default-deny + egress allow-lists

**SHORT TERM (Foundation)**:
- [ ] Add HPAs, PDBs, PriorityClasses for critical services
- [ ] Define PVC sizes & StorageClasses; document node sizing
- [ ] Add Velero + DB/Kafka/MinIO backup plans
- [ ] Pin chart/image versions; remove `latest`
- [ ] Implement admission controllers (Kyverno)

**MEDIUM TERM (Operations)**:
- [ ] Setup monitoring dashboards and alerting
- [ ] Implement secret rotation automation
- [ ] Create disaster recovery runbooks
          # Enable encryption
          serverSideEncryption = "AES256"
- [ ] Performance testing and optimization
- [ ] Security scanning and compliance

This plan provides a complete, secure, and production-ready migration path from the current Docker Compose setup to a modern Kubernetes infrastructure.
          includedNamespaces = ["data", "apps", "auth"]
          # Add integrity verification
          hooks = {
            resources = [{
              name = "backup-verification"
              includedNamespaces = ["velero"]
            }]
          }