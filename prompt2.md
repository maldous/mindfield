Below is a **ready‑to‑apply scaffold**.
It enables **MicroK8s addons only** on first apply (everything else is stubbed and disabled).
You can flip `enabled = true` per module as you implement each chart.

---

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.13.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.5"
    }
  }
}

# Assumes your MicroK8s kubeconfig is merged into ~/.kube/config
provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
```

---

### `locals.tf`

```hcl
locals {
  app_name   = "mindfield"
  owner      = "matt"
  env        = "dev"
  labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"    = local.app_name
    "app.kubernetes.io/environment"= local.env
    "app.kubernetes.io/owner"      = local.owner
  }
}
```

---

### `variables.tf`

```hcl
variable "kubeconfig" {
  description = "Path to kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "domain" {
  description = "Primary DNS zone"
  type        = string
  default     = "aldous.info"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for domain"
  type        = string
  default     = ""
}

variable "cloudflare_email" {
  description = "Cloudflare account email (if needed)"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Read + DNS:Edit"
  type        = string
  sensitive   = true
  default     = ""
}

variable "acme_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
  default     = "you@aldous.info"
}

variable "metallb_range" {
  description = "MetalLB address pool"
  type        = string
  default     = "192.168.1.250-192.168.1.254"
}

variable "kong_proxy_ip" {
  description = "Static LB IP for Kong proxy"
  type        = string
  default     = "192.168.1.251"
}

variable "cidr_allow_admin" {
  description = "CIDR(s) allowed to access admin /health/metrics endpoints"
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

# Postgres / storage sizes
variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_storage" {
  description = "PostgreSQL PVC size"
  type        = string
  default     = "50Gi"
}

variable "opensearch_storage" {
  description = "OpenSearch PVC size"
  type        = string
  default     = "100Gi"
}

variable "minio_storage" {
  description = "MinIO tenant total raw size"
  type        = string
  default     = "100Gi"
}

variable "grafana_storage" {
  type        = string
  default     = "10Gi"
}

variable "prometheus_storage" {
  type        = string
  default     = "50Gi"
}

variable "loki_storage" {
  type        = string
  default     = "100Gi"
}

variable "tempo_storage" {
  type        = string
  default     = "100Gi"
}
```

---

### `outputs.tf`

```hcl
output "domain" {
  value = var.domain
}

output "kong_proxy_ip" {
  value = var.kong_proxy_ip
}

# Secrets (placeholders; will be populated when implemented)
output "cloudflare_api_token" {
  value     = var.cloudflare_api_token
  sensitive = true
}

# Common endpoints (to be created when modules are enabled)
output "urls" {
  value = {
    web          = "https://${var.domain}"
    keycloak     = "https://auth.${var.domain}"
    grafana      = "https://grafana.${var.domain}"
    prometheus   = "https://prometheus.${var.domain}"
    alertmanager = "https://alertmanager.${var.domain}"
    opensearch   = "https://search.${var.domain}"
    sonarqube    = "https://sonar.${var.domain}"
    mailhog      = "https://mailhog.${var.domain}"
    pgadmin      = "https://pgadmin.${var.domain}"
    kuma         = "https://ops.${var.domain}"
  }
}
```

---

### `main.tf`

```hcl
############################################################
# Root wiring — enable modules incrementally
############################################################

module "microk8s_addons" {
  source        = "./modules/microk8s_addons"
  metallb_range = var.metallb_range
  kong_proxy_ip = var.kong_proxy_ip
  enabled       = true
}

# Network policy baseline (Calico is default CNI; cilium stub disabled)
module "cilium" {
  source  = "./modules/cilium"
  enabled = false
}

module "cert_manager" {
  source          = "./modules/cert_manager"
  enabled         = false
  acme_email      = var.acme_email
  domain          = var.domain
  cf_zone_id      = var.cloudflare_zone_id
  cf_api_token    = var.cloudflare_api_token
}

module "external_dns" {
  source       = "./modules/external_dns"
  enabled      = false
  domain       = var.domain
  zone_id      = var.cloudflare_zone_id
}

module "external_secrets" {
  source  = "./modules/external_secrets"
  enabled = false
}

module "rook_ceph" {
  source  = "./modules/rook_ceph"
  enabled = false
}

module "minio" {
  source        = "./modules/minio"
  enabled       = false
  minio_storage = var.minio_storage
}

module "postgres" {
  source            = "./modules/postgres"
  enabled           = false
  postgres_version  = var.postgres_version
  postgres_storage  = var.postgres_storage
}

module "pgbouncer" {
  source  = "./modules/pgbouncer"
  enabled = false
}

module "redis" {
  source  = "./modules/redis"
  enabled = false
}

module "keycloak" {
  source  = "./modules/keycloak"
  enabled = false
  domain  = var.domain
}

module "kong" {
  source        = "./modules/kong"
  enabled       = false
  domain        = var.domain
  kong_proxy_ip = var.kong_proxy_ip
}

module "observability" {
  source             = "./modules/observability"
  enabled            = false
  grafana_storage    = var.grafana_storage
  prometheus_storage = var.prometheus_storage
  loki_storage       = var.loki_storage
  tempo_storage      = var.tempo_storage
  domain             = var.domain
}

module "opensearch" {
  source           = "./modules/opensearch"
  enabled          = false
  opensearch_size  = var.opensearch_storage
}

module "uptime_kuma" {
  source  = "./modules/uptime_kuma"
  enabled = false
}

module "sonarqube" {
  source  = "./modules/sonarqube"
  enabled = false
}

module "mailhog" {
  source  = "./modules/mailhog"
  enabled = false
}

module "pgadmin" {
  source  = "./modules/pgadmin"
  enabled = false
}

module "swagger_ui" {
  source  = "./modules/swagger_ui"
  enabled = false
}

module "redoc" {
  source  = "./modules/redoc"
  enabled = false
}

module "mkdocs" {
  source  = "./modules/mkdocs"
  enabled = false
}

module "postgraphile" {
  source  = "./modules/postgraphile"
  enabled = false
}

module "trivy" {
  source  = "./modules/trivy"
  enabled = false
}

module "gitops_argocd" {
  source  = "./modules/gitops_argocd"
  enabled = false
}
```

---

## Module stubs

> Pattern: every module has `enabled` var and no-op when false.
> Only **microk8s\_addons** actually runs on first apply.

### `modules/microk8s_addons/variables.tf`

```hcl
variable "enabled" {
  type    = bool
  default = true
}

variable "metallb_range" {
  type = string
}

variable "kong_proxy_ip" {
  type = string
}
```

### `modules/microk8s_addons/main.tf`

```hcl
locals {
  addons_list = [
    "dns",
    "rbac",
    "helm3",
    "metrics-server",
    "cert-manager",
    "metallb:${var.metallb_range}",
    "gpu",
  ]
}

resource "null_resource" "addons" {
  count = var.enabled ? 1 : 0

  triggers = {
    addons_hash = join(",", local.addons_list)
    proxy_ip    = var.kong_proxy_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      sudo microk8s status --wait-ready

      # ensure clean enablement idempotently
      microk8s enable ${join(" ", local.addons_list)}

      # Ensure MetalLB has our static IP reserved for Kong (idempotent create/update)
      cat <<'YAML' | microk8s kubectl apply -f -
      apiVersion: metallb.io/v1beta1
      kind: IPAddressPool
      metadata:
        name: public-pool
        namespace: metallb-system
      spec:
        addresses:
        - ${var.metallb_range}
      ---
      apiVersion: metallb.io/v1beta1
      kind: L2Advertisement
      metadata:
        name: public-l2
        namespace: metallb-system
      spec:
        ipAddressPools:
        - public-pool
      YAML
    EOT
  }
}
```

### `modules/microk8s_addons/outputs.tf`

```hcl
output "enabled" {
  value = true
}
```

---

### Stub template for all other modules

You can copy this trio and adjust names.

**`modules/<name>/variables.tf`**

```hcl
variable "enabled" {
  type    = bool
  default = false
}
```

**`modules/<name>/main.tf`**

```hcl
# Placeholder. Implement helm_release / manifests when enabling.
locals {
  noop = true
}

# Example (disabled): null_resource just to be structurally valid
resource "null_resource" "noop" {
  count = var.enabled ? 1 : 0
}
```

**`modules/<name>/outputs.tf`**

```hcl
output "enabled" {
  value = var.enabled
}
```

Create these for:

```
cilium
cert_manager
external_dns
external_secrets
postgres
pgbouncer
redis
minio
rook_ceph
opensearch
kong
keycloak
observability
uptime_kuma
sonarqube
mailhog
pgadmin
swagger_ui
redoc
mkdocs
postgraphile
trivy
gitops_argocd
```

---

## `helm-values/` placeholders

Create empty files with comments so git tracks them:

```yaml
# helm-values/cert-manager.yaml
# pin: jetstack/cert-manager v1.18.2
```

Repeat similarly for each file listed earlier (external-dns.yaml, external-secrets.yaml, kong.yaml, keycloak.yaml, postgres.yaml, pgbouncer.yaml, redis.yaml, rook-operator.yaml, rook-cluster.yaml, minio-operator.yaml, minio-tenant.yaml, kube-prometheus-stack.yaml, loki.yaml, promtail.yaml, tempo-distributed.yaml, blackbox-exporter.yaml, otel-collector.yaml, opensearch.yaml, opensearch-dashboards.yaml, sonarqube.yaml, uptime-kuma.yaml, mailhog.yaml, pgadmin4.yaml, trivy-operator.yaml, velero.yaml).

---

## `README.md`

````md
# Mindfield Platform — Terraform on MicroK8s

## Quick start

```bash
# 0) Ensure kubeconfig has MicroK8s context
microk8s config > ~/.kube/microk8s
kubectl config view --raw > ~/.kube/config   # if you merge contexts another way, update var.kubeconfig

# 1) Init
cd infra/terraform
terraform init

# 2) Apply base addons only
terraform apply -auto-approve \
  -target=module.microk8s_addons
````

## Enable next components

Flip `enabled = true` for each module in `main.tf`, then:

```bash
# Example enabling cert-manager + ExternalDNS + ESO
terraform apply -target=module.cert_manager -target=module.external_dns -target=module.external_secrets
```

## Smoke tests

```bash
# Cluster ready
microk8s status --wait-ready
kubectl get pods -A

# MetalLB pool / speaker
kubectl get ipaddresspools.metallb.io -A
kubectl get pods -n metallb-system

# cert-manager CRDs
kubectl get crds | grep cert-manager
kubectl get pods -n cert-manager

# ExternalDNS logs
kubectl -n networking logs -l app.kubernetes.io/name=external-dns --tail=200

# DNS-01 issuance (after you add ClusterIssuer + Certificate)
kubectl describe certificate -A
kubectl describe order -A
kubectl describe challenge -A
```

## Order of enablement

1. `microk8s_addons`
2. `cert_manager` → create ClusterIssuers (staging/prod)
3. `external_secrets` → bootstrap CF token as secret or ESO
4. `external_dns`
5. Storage: `rook_ceph`, `minio`
6. Datastores: `postgres`, `pgbouncer`, `redis`
7. `keycloak`
8. `kong` (Gateway API, OIDC, rate-limit)
9. `observability`
10. `opensearch`
11. Dev tools: `uptime_kuma`, `sonarqube`, `mailhog`, `pgadmin`
12. APIs/docs: `swagger_ui`, `redoc`, `mkdocs`, `postgraphile`
13. Security: `trivy`
14. (Optional) `gitops_argocd`

```

---

## Next

- Want me to fill **cert_manager**, **external_dns**, **external_secrets**, **kong**, and **keycloak** modules with actual `helm_release` + manifests next?  
- If yes, say **“generate phase‑2 modules”** and I’ll output those with pinned chart versions and initial `values.yaml`.
::contentReference[oaicite:0]{index=0}
```

