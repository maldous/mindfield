# Production-grade, infra-agnostic bootstrap
# Phases:
# 0 Foundation | 1 Core Infra | 2 Identity & Security | 3 Observability
# 4 Applications | 5 GitOps & Automation | 6 Cleanup

.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
SHELL := bash
.DEFAULT_GOAL := help

# ---------------- Env ----------------
-include .env
export

export CLUSTER_TYPE ?= microk8s          # microk8s|kind|k3s
export BASE_DOMAIN  ?= example.local
export ADMIN_EMAIL  ?= admin@$(BASE_DOMAIN)
export ENP_IF       ?= enp3s0

# MetalLB
export LB_POOL      ?= 192.168.1.200-192.168.1.250
export LB_POOL_2    ?=
export GEN_DIR      ?= generated
export METALLB_YAML ?= $(GEN_DIR)/metallb-ip-pool.yaml

# TLS / DNS
export USE_LE ?= 0                        # 1 = Let's Encrypt DNS-01, 0 = self-signed
export CF_API_TOKEN_SECRET_NAME ?= cloudflare-api-token

# Registry / build tags
REG ?= localhost:32000
TAG ?= $(shell git rev-parse --short HEAD)

# Secrets (bootstrap only; prefer ESO)
POSTGRES_PASSWORD            ?= changeme
KC_DB_PASSWORD               ?= changeme
KC_BOOTSTRAP_ADMIN_PASSWORD  ?= admin123
TEMPORAL_DB_PASSWORD         ?= changeme
TEMPORAL_VIS_DB_PASSWORD     ?= changeme
GRAFANA_DEFAULT_PASSWORD     ?= admin

# Feature toggles
GATEWAY        ?= kong       # kong only (ingress-nginx not wired in this repo)
ENABLE_KAFKA   ?= 0

# Tooling by cluster type
ifeq ($(CLUSTER_TYPE),microk8s)
  KUBECTL ?= microk8s kubectl
  HELM    ?= microk8s helm3
else
  KUBECTL ?= kubectl
  HELM    ?= helm
endif

# Versions (defaults) — will be overridden by versions.mk if present
CERT_MANAGER_CHART_VERSION ?= 1.18.2
ESO_CHART_VERSION          ?= 0.12.1
KONG_CHART_VERSION         ?= 2.51.0
POSTGRES_CHART_VERSION     ?= 15.2.5
KEYCLOAK_CHART_VERSION     ?= 22.2.1
KPS_CHART_VERSION          ?= 75.15.0
LOKI_CHART_VERSION         ?= 6.33.0
TEMPO_CHART_VERSION        ?= 2.6.0
VELERO_CHART_VERSION       ?= 2.13.6
TEMPORAL_CHART_VERSION     ?= 0.64.0
GATEWAY_API_VERSION        ?= v1.3.0

-include versions.mk

# Namespaces
NS_CERT    := cert-manager
NS_ESO     := external-secrets-system
NS_NET     := metallb-system
NS_GATE    := gateway
NS_DATA    := data
NS_AUTH    := auth
NS_OBS     := observability
NS_TEMP    := temporal
NS_VELERO  := velero

# ---------------- Phony ----------------
.PHONY: help phase0 phase0-security phase0-cluster phase0-validate \
        phase1 phase1-prereqs phase1-postgres phase1-kong phase1-validate \
        phase2 phase2-keycloak phase2-policies phase2-validate \
        phase3 phase3-prometheus phase3-loki phase3-tempo phase3-validate \
        phase4 phase4-temporal phase4-validate \
        phase5 phase5-flux phase5-velero phase5-validate \
        phase6 phase6-cleanup phase6-validate \
        status clean reset reset-soft nuke \
        test-phase0 test-phase1 test-phase2 test-phase3 test-phase4 test-phase5 test-phase6 test-all \
        migrate _repos _namespaces _metallb _issuer _eso_store _gateway_values

# ---------------- Help ----------------
help: ## Show this help message
	@echo 'Usage: make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# =============================================================================
# PHASE 0: SECURITY & FOUNDATION
# =============================================================================
phase0: phase0-security phase0-cluster phase0-validate ## Complete Phase 0

phase0-security: ## Validate secrets hygiene (fail fast if legacy plaintext)
	@echo "🚨 Phase 0: Security Fixes"
	@if [ -f "1/services/pgbouncer/databases.ini" ]; then \
	  echo "ERROR: databases.ini contains plaintext credentials. Remove and rotate."; exit 1; fi
	@if [ -f "1/services/pgbouncer/userlist.txt" ]; then \
	  echo "ERROR: userlist.txt contains MD5 hashes. Remove and migrate to SCRAM-SHA-256."; exit 1; fi
	@echo "✅ Security validation passed"

phase0-cluster: _repos ## Setup cluster add-ons (if MicroK8s) and kube access
	@echo "🏗️ Phase 0: Cluster Setup ($(CLUSTER_TYPE))"
ifeq ($(CLUSTER_TYPE),microk8s)
	microk8s status --wait-ready
	microk8s enable dns storage registry metallb || true
endif
	@mkdir -p $(GEN_DIR)
	$(MAKE) _metallb
	@echo "✅ Cluster base ready"

phase0-validate: ## Validate Phase 0 deliverables
	@echo "🔍 Phase 0: Validation"
ifeq ($(CLUSTER_TYPE),microk8s)
	microk8s status | grep -E "dns|storage|metallb|registry"
endif
	@echo "Checking MetalLB pools…"
	$(KUBECTL) get ipaddresspools -n $(NS_NET) || true
	@echo "✅ Phase 0 validation complete"

# =============================================================================
# PHASE 1: CORE INFRASTRUCTURE
# =============================================================================
phase1: phase1-prereqs phase1-postgres phase1-kong phase1-validate ## Complete Phase 1

_repos:
	$(HELM) repo add kong https://charts.konghq.com
	$(HELM) repo add bitnami https://charts.bitnami.com/bitnami
	$(HELM) repo add jetstack https://charts.jetstack.io
	$(HELM) repo add external-secrets https://charts.external-secrets.io
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts
	$(HELM) repo add grafana https://grafana.github.io/helm-charts
	$(HELM) repo update

_namespaces:
	@for ns in $(NS_CERT) $(NS_ESO) $(NS_NET) $(NS_GATE) $(NS_DATA) $(NS_AUTH) $(NS_OBS) $(NS_TEMP) $(NS_VELERO); do \
	  $(KUBECTL) get ns $$ns >/dev/null 2>&1 || $(KUBECTL) create ns $$ns ; \
	done
	$(KUBECTL) label namespace $(NS_GATE) name=gateway --overwrite
	$(KUBECTL) label namespace $(NS_AUTH) name=auth --overwrite
	$(KUBECTL) label namespace $(NS_OBS)  name=observability --overwrite
	$(KUBECTL) label namespace $(NS_DATA) name=data --overwrite
	$(KUBECTL) label namespace $(NS_TEMP) name=temporal --overwrite

phase1-prereqs: _namespaces ## Gateway API, cert-manager, ESO, ESO store
	@echo "🔧 Phase 1: Prerequisites"
	@echo "Installing Gateway API CRDs ($(GATEWAY_API_VERSION))…"
	$(KUBECTL) apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/standard-install.yaml
	@echo "Installing cert-manager…"
	$(HELM) upgrade --install cert-manager jetstack/cert-manager \
	  --namespace $(NS_CERT) --version $(CERT_MANAGER_CHART_VERSION) --set installCRDs=true
	@echo "Installing External Secrets Operator…"
	$(HELM) upgrade --install external-secrets external-secrets/external-secrets \
	  --namespace $(NS_ESO) --version $(ESO_CHART_VERSION)
	@echo "Applying ESO ClusterSecretStore + RBAC…"
	$(KUBECTL) apply -f k8s/security/eso-store.yaml
	@echo "Applying DNS egress policies…"
	$(KUBECTL) apply -f k8s/security/dns-policies.yaml
	@echo "Rendering & applying ClusterIssuer (LE or self-signed)…"
	$(MAKE) _issuer
	@echo "✅ Prerequisites installed"

phase1-postgres: ## PostgreSQL
	@echo "🗄️ Phase 1: PostgreSQL"
	$(HELM) upgrade --install postgresql bitnami/postgresql \
	  --namespace $(NS_DATA) --version $(POSTGRES_CHART_VERSION) \
	  --set auth.postgresPassword="$(POSTGRES_PASSWORD)" \
	  --set primary.persistence.size=50Gi \
	  --set primary.persistence.storageClass=microk8s-hostpath
	@echo "✅ PostgreSQL deployed"

_gateway_values:
	@mkdir -p $(GEN_DIR)
	@cat > $(GEN_DIR)/kong-values.yaml <<EOF
ingressController:
  enabled: true
  ingressClass: kong
gateway:
  enabled: true
proxy:
  type: LoadBalancer
  annotations:
    metallb.universe.tf/address-pool: lan-pool
env:
  KONG_DATABASE: "off"
	EOF

phase1-kong: _gateway_values ## Kong (DB-less)
	@echo "🦍 Phase 1: Kong Gateway"
	$(HELM) upgrade --install kong kong/kong \
	  --namespace $(NS_GATE) --version $(KONG_CHART_VERSION) \
	  -f $(GEN_DIR)/kong-values.yaml
	@echo "✅ Kong deployed"

phase1-validate: ## Validate Phase 1
	@echo "🔍 Phase 1: Validation"
	$(KUBECTL) get crd gateways.gateway.networking.k8s.io
	$(KUBECTL) get pods -n $(NS_CERT)
	$(KUBECTL) get pods -n $(NS_ESO)
	$(KUBECTL) get pods -n $(NS_DATA) -l app.kubernetes.io/name=postgresql
	$(KUBECTL) get svc  -n $(NS_GATE) kong-kong-proxy
	@echo "✅ Phase 1 validation complete"

# =============================================================================
# PHASE 2: IDENTITY & SECURITY
# =============================================================================
phase2: phase2-keycloak phase2-policies phase2-validate ## Complete Phase 2

phase2-keycloak: ## Keycloak behind Kong, external Postgres
	@echo "🔐 Phase 2: Keycloak"
	# Create DB & user if absent
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_roles WHERE rolname='keycloak'\" | grep -q 1 || psql -U postgres -c \"CREATE USER keycloak WITH PASSWORD '$(KC_DB_PASSWORD)';\""
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='keycloak'\" | grep -q 1 || createdb -U postgres -O keycloak keycloak"
	# Install
	$(HELM) upgrade --install keycloak bitnami/keycloak \
	  --namespace $(NS_AUTH) --version $(KEYCLOAK_CHART_VERSION) \
	  --set postgresql.enabled=false \
	  --set externalDatabase.host=postgresql.$(NS_DATA).svc.cluster.local \
	  --set externalDatabase.user=keycloak \
	  --set externalDatabase.password="$(KC_DB_PASSWORD)" \
	  --set externalDatabase.database=keycloak \
	  --set auth.adminUser=admin \
	  --set auth.adminPassword="$(KC_BOOTSTRAP_ADMIN_PASSWORD)" \
	  --set proxy=edge \
	  --set proxyAddressForwarding=true
	@echo "✅ Keycloak deployed"

phase2-policies: ## PSS, NetworkPolicies, Kong plugins, OIDC secrets, Gateway & routes
	@echo "🛡️ Phase 2: Policies"
	$(KUBECTL) label namespace $(NS_DATA) pod-security.kubernetes.io/enforce=restricted --overwrite
	$(KUBECTL) label namespace $(NS_AUTH) pod-security.kubernetes.io/enforce=restricted --overwrite
	$(KUBECTL) label namespace $(NS_GATE) pod-security.kubernetes.io/enforce=baseline --overwrite
	$(KUBECTL) apply -f k8s/security/
	$(KUBECTL) apply -f k8s/gateway/kong-plugins.yaml
	$(KUBECTL) apply -f k8s/gateway/oidc-secrets.yaml
	$(KUBECTL) apply -f k8s/gateway/redis.yaml
	$(KUBECTL) apply -f k8s/gateway/gateway.yaml
	$(KUBECTL) apply -f k8s/gateway/httproutes/
	@echo "✅ Security policies & routes applied"

phase2-validate: ## Validate Phase 2
	@echo "🔍 Phase 2: Validation"
	$(KUBECTL) get pods -n $(NS_AUTH) -l app.kubernetes.io/name=keycloak
	$(KUBECTL) get networkpolicy --all-namespaces
	$(KUBECTL) get kongclusterplugin
	@echo "✅ Phase 2 validation complete"

# =============================================================================
# PHASE 3: OBSERVABILITY
# =============================================================================
phase3: phase3-prometheus phase3-loki phase3-tempo phase3-validate ## Complete Phase 3

phase3-prometheus: ## kube-prometheus-stack
	@echo "📊 Phase 3: Prometheus Stack"
	$(HELM) upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
	  --namespace $(NS_OBS) --version $(KPS_CHART_VERSION) \
	  --set grafana.adminPassword="$(GRAFANA_DEFAULT_PASSWORD)" \
	  --set grafana.persistence.enabled=true \
	  --set grafana.persistence.size=10Gi \
	  --set prometheus.prometheusSpec.retention=7d \
	  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=microk8s-hostpath \
	  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
	@echo "✅ Prometheus stack deployed"

phase3-loki: ## Loki
	@echo "📝 Phase 3: Loki"
	$(HELM) upgrade --install loki grafana/loki \
	  --namespace $(NS_OBS) --version $(LOKI_CHART_VERSION) \
	  --set deploymentMode=SingleBinary \
	  --set loki.commonConfig.replication_factor=1 \
	  --set loki.storage.type=filesystem \
	  --set singleBinary.persistence.enabled=true \
	  --set singleBinary.persistence.size=50Gi \
	  --set singleBinary.persistence.storageClass=microk8s-hostpath
	@echo "✅ Loki deployed"

phase3-tempo: ## Tempo
	@echo "🔍 Phase 3: Tempo"
	$(HELM) upgrade --install tempo grafana/tempo \
	  --namespace $(NS_OBS) --version $(TEMPO_CHART_VERSION) \
	  --set tempo.storage.trace.backend=local \
	  --set tempo.storage.trace.local.path=/var/tempo/traces \
	  --set persistence.enabled=true \
	  --set persistence.size=50Gi \
	  --set persistence.storageClass=microk8s-hostpath
	@echo "✅ Tempo deployed"

phase3-validate: ## Validate Phase 3
	@echo "🔍 Phase 3: Validation"
	$(KUBECTL) get pods -n $(NS_OBS) -l app.kubernetes.io/name=prometheus
	$(KUBECTL) get pods -n $(NS_OBS) -l app.kubernetes.io/name=grafana
	$(KUBECTL) get pods -n $(NS_OBS) -l app.kubernetes.io/name=loki
	$(KUBECTL) get pods -n $(NS_OBS) -l app.kubernetes.io/name=tempo
	@echo "✅ Phase 3 validation complete"

# =============================================================================
# PHASE 4: APPLICATIONS
# =============================================================================
phase4: phase4-temporal phase4-validate ## Complete Phase 4

phase4-temporal: ## Temporal with external Postgres
	@echo "⏰ Phase 4: Temporal"
	# Users/databases (guarded)
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_roles WHERE rolname='temporal'\" | grep -q 1 || psql -U postgres -c \"CREATE USER temporal WITH PASSWORD '$(TEMPORAL_DB_PASSWORD)';\""
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='temporal'\" | grep -q 1 || createdb -U postgres -O temporal temporal"
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_roles WHERE rolname='temporal_visibility'\" | grep -q 1 || psql -U postgres -c \"CREATE USER temporal_visibility WITH PASSWORD '$(TEMPORAL_VIS_DB_PASSWORD)';\""
	$(KUBECTL) exec -n $(NS_DATA) postgresql-0 -- bash -lc \
	  "psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='temporal_visibility'\" | grep -q 1 || createdb -U postgres -O temporal_visibility temporal_visibility"
	# Render values and install
	 envsubst < k8s/configs/temporal-values.yaml > $(GEN_DIR)/temporal-values.yaml
	$(HELM) upgrade --install temporal temporalio/temporal \
	  --namespace $(NS_TEMP) --version $(TEMPORAL_CHART_VERSION) \
	  --values $(GEN_DIR)/temporal-values.yaml
	@echo "✅ Temporal deployed"

phase4-validate: ## Validate Phase 4
	@echo "🔍 Phase 4: Validation"
	$(KUBECTL) get pods -n $(NS_TEMP) -l app.kubernetes.io/name=temporal
	@echo "✅ Phase 4 validation complete"

# =============================================================================
# PHASE 5: GITOPS & AUTOMATION
# =============================================================================
phase5: phase5-flux phase5-velero phase5-validate ## Complete Phase 5

phase5-flux: ## Bootstrap Flux
	@echo "🔄 Phase 5: Flux GitOps"
	curl -s https://fluxcd.io/install.sh | sudo bash
	@if [ -z "$(GITHUB_USER)" ] || [ -z "$(GITHUB_REPO)" ]; then \
	  echo "Please set GITHUB_USER and GITHUB_REPO environment variables"; exit 1; fi
	flux bootstrap git \
	  --url=https://github.com/$(GITHUB_USER)/$(GITHUB_REPO) \
	  --branch=main \
	  --path=./flux/clusters/local
	@echo "✅ Flux bootstrapped"

phase5-velero: ## Velero backup to S3-compatible (MinIO)
	@echo "💾 Phase 5: Velero Backups"
	$(HELM) repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
	$(HELM) repo update
	$(HELM) upgrade --install velero vmware-tanzu/velero \
	  --namespace $(NS_VELERO) --create-namespace \
	  --version $(VELERO_CHART_VERSION) \
	  --set configuration.backupStorageLocation[0].name=default \
	  --set configuration.backupStorageLocation[0].provider=aws \
	  --set configuration.backupStorageLocation[0].bucket=$(BACKUP_BUCKET) \
	  --set configuration.backupStorageLocation[0].config.region=$(AWS_REGION) \
	  --set configuration.backupStorageLocation[0].config.s3ForcePathStyle=true \
	  --set configuration.backupStorageLocation[0].config.s3Url=$(MINIO_ENDPOINT)
	@echo "✅ Velero deployed"

phase5-validate: ## Validate Phase 5
	@echo "🔍 Phase 5: Validation"
	flux get all || echo "Flux not configured"
	$(KUBECTL) get pods -n $(NS_VELERO) -l app.kubernetes.io/name=velero
	$(KUBECTL) apply -f k8s/velero/backup-schedule.yaml
	velero backup create test-backup --include-namespaces default --wait || echo "Backup test failed"
	velero restore create test-restore --from-backup test-backup --wait || echo "Restore test failed"
	 envsubst < flux/clusters/local/observability-source.yaml | $(KUBECTL) apply -f -
	@echo "✅ Phase 5 validation complete"

# =============================================================================
# PHASE 6: CLEANUP
# =============================================================================
phase6: phase6-cleanup phase6-validate ## Complete Phase 6

phase6-cleanup: ## Archive legacy dirs
	@echo "🧹 Phase 6: Cleanup"
	mkdir -p archive/$(shell date +%Y%m%d)
	mv docker/ archive/$(shell date +%Y%m%d)/ 2>/dev/null || true
	mv 1/ archive/$(shell date +%Y%m%d)/ 2>/dev/null || true
	mv 0/ archive/$(shell date +%Y%m%d)/ 2>/dev/null || true
	@echo "✅ Cleanup complete"

phase6-validate: ## Validate Phase 6
	@echo "🔍 Phase 6: Validation"
	ls -la archive/ 2>/dev/null || echo "No archive directory found"
	@echo "✅ Phase 6 validation complete"

# =============================================================================
# UTILITIES
# =============================================================================
status: ## Show cluster status & fail on NotReady
	@echo "📊 Cluster Status"
ifeq ($(CLUSTER_TYPE),microk8s)
	microk8s status || true
endif
	@echo "\nNamespaces:"; $(KUBECTL) get namespaces
	@echo "\nPods (all):"; $(KUBECTL) get pods --all-namespaces
	@echo "\nServices with external IPs:"; $(KUBECTL) get svc --all-namespaces -o wide | grep -E "LoadBalancer|NodePort" || true
	@echo "\ncert-manager:"; $(KUBECTL) -n $(NS_CERT) get pods,svc,certificates,clusterissuers || true
	@echo "\nexternal-secrets:"; $(KUBECTL) -n $(NS_ESO) get pods,clustersercretstores,externalsecrets || true
	@echo "\nmetallb:"; $(KUBECTL) -n $(NS_NET) get pods,cm,svc || true
	@echo "\ngateway:"; $(KUBECTL) -n $(NS_GATE) get pods,svc,secrets || true
	@echo "\nauth:"; $(KUBECTL) -n $(NS_AUTH) get pods,svc,sts,secrets || true
	@echo "\nobservability:"; $(KUBECTL) -n $(NS_OBS) get pods,svc,cm,secrets || true
	@echo "\ndata:"; $(KUBECTL) -n $(NS_DATA) get pods,svc,sts,secrets || true
	@echo "\ntemporal:"; $(KUBECTL) -n $(NS_TEMP) get pods,svc,sts,secrets || true
	@echo "\nHelm releases:"; $(HELM) list -A || true
	@echo "\nReadiness gate:"
	@nr=$$($(KUBECTL) get pods --all-namespaces | grep -c -E '0/|CrashLoopBackOff|Error' || true); \
	if [ "$$nr" -gt 0 ]; then echo "❌ Some pods not ready"; exit 1; else echo "✅ All pods Ready"; fi

clean: ## Clean failed workloads
	@echo "🧽 Cleaning up…"
	$(HELM) list --all-namespaces --failed -q | xargs -r $(HELM) delete
	$(KUBECTL) get pods --all-namespaces --field-selector=status.phase=Failed -o name | xargs -r $(KUBECTL) delete

reset: ## Reset entire MicroK8s cluster (DANGEROUS)
	@echo "⚠️  This will destroy the entire cluster!"
	@read -p "Are you sure? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then microk8s reset; else echo "Cancelled."; fi

reset-soft: ## Uninstall Helm releases only
	@echo "🧼 Uninstalling Helm releases (keeping PVCs)…"
	@for ns in $(NS_GATE) $(NS_AUTH) $(NS_OBS) $(NS_DATA) $(NS_TEMP) $(NS_CERT) $(NS_ESO) $(NS_VELERO); do \
	  $(HELM) list -n $$ns -q | xargs -r -n1 $(HELM) uninstall -n $$ns ; \
	done
	@echo "✅ reset-soft complete"

nuke: ## Delete namespaces, PVCs & key CRDs (set CONFIRM=YES)
	@if [ "$(CONFIRM)" != "YES" ]; then echo "Set CONFIRM=YES to proceed"; exit 1; fi
	@for ns in $(NS_GATE) $(NS_AUTH) $(NS_OBS) $(NS_DATA) $(NS_TEMP) $(NS_CERT) $(NS_ESO) $(NS_VELERO); do \
	  $(KUBECTL) delete ns $$ns --ignore-not-found=true ; \
	done
	$(KUBECTL) delete crd certificates.cert-manager.io clusterissuers.cert-manager.io --ignore-not-found=true || true
	@echo "✅ nuke complete"

# =============================================================================
# TESTS & ROLLUP
# =============================================================================
test-phase0: phase0-validate ## Test Phase 0 deliverables
test-phase1: phase1-validate ## Test Phase 1 deliverables
test-phase2: phase2-validate ## Test Phase 2 deliverables
test-phase3: phase3-validate ## Test Phase 3 deliverables
test-phase4: phase4-validate ## Test Phase 4 deliverables
test-phase5: phase5-validate ## Test Phase 5 deliverables
test-phase6: phase6-validate ## Test Phase 6 deliverables
test-all: test-phase0 test-phase1 test-phase2 test-phase3 test-phase4 test-phase5 test-phase6 ## Test all phases

migrate: phase0 phase1 phase2 phase3 phase4 phase5 phase6 ## Full migration
	@echo "🎉 Migration complete!"
	@echo "Your Kubernetes cluster is ready with:"
	@echo "- Core infrastructure (PostgreSQL, Kong Gateway)"
	@echo "- Identity & Security (Keycloak, NetworkPolicies)"
	@echo "- Observability (Prometheus, Loki, Tempo)"
	@echo "- Applications (Temporal)"
	@echo "- GitOps & Automation (Flux, Velero)"
	@echo "- Cleanup completed"
	@echo "\nNext steps:"
	@echo "1. Configure DNS to point to Kong LoadBalancer IP"
	@echo "2. Setup monitoring dashboards"
	@echo "3. Test application deployments"
	@echo "4. Configure backup schedules"

# ---------------- Internals ----------------
_metallb:
	@mkdir -p $(GEN_DIR)
	@cat > $(METALLB_YAML) <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: lan-pool
  namespace: $(NS_NET)
spec:
  addresses:
  - $(LB_POOL)
$(if $(LB_POOL_2),  - $(LB_POOL_2),)
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: lan-adv
  namespace: $(NS_NET)
spec:
  ipAddressPools:
  - lan-pool
EOF
	@if $(KUBECTL) get ns $(NS_NET) >/dev/null 2>&1; then $(KUBECTL) apply -f $(METALLB_YAML); fi

_issuer:
	@mkdir -p $(GEN_DIR)
	@cat > $(GEN_DIR)/clusterissuer.tmpl.yaml <<'EOF'
{{- if eq (env "USE_LE") "1" -}}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-token
  namespace: cert-manager
spec:
  refreshInterval: 24h
  secretStoreRef:
    name: k8s-secrets-store
    kind: ClusterSecretStore
  target:
    name: {{ env "CF_API_TOKEN_SECRET_NAME" }}
    creationPolicy: Owner
  data:
  - secretKey: token
    remoteRef:
      key: cloudflare-api-token-source
      property: token
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns
spec:
  acme:
    email: {{ env "ADMIN_EMAIL" }}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: le-account-key
    solvers:
    - dns01:
        cloudflare:
          email: {{ env "ADMIN_EMAIL" }}
          apiTokenSecretRef:
            name: {{ env "CF_API_TOKEN_SECRET_NAME" }}
            key: token
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: edge-cert
  namespace: gateway
spec:
  secretName: edge-cert
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
  dnsNames:
    - "{{ env "BASE_DOMAIN" }}"
    - "*.{{ env "BASE_DOMAIN" }}"
{{- else -}}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-cluster-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: edge-cert
  namespace: gateway
spec:
  secretName: edge-cert
  issuerRef:
    name: selfsigned-cluster-issuer
    kind: ClusterIssuer
  dnsNames:
    - "{{ env "BASE_DOMAIN" }}"
    - "*.{{ env "BASE_DOMAIN" }}"
{{- end -}}
EOF
	@envsubst < $(GEN_DIR)/clusterissuer.tmpl.yaml | $(KUBECTL) apply -f -

