locals {
  cloudflare_api_token = var.cloudflare_api_token
}
module "microk8s_addons" {
  source            = "./modules/microk8s_addons"
  enabled           = true
  metallb_range     = var.metallb_range
  kong_proxy_ip     = var.kong_proxy_ip
  enable_gpu_addons = var.enable_gpu_addons
}
module "calico" {
  source  = "./modules/calico"
  enabled = true
  domain  = var.domain
}
module "cert_manager" {
  source       = "./modules/cert_manager"
  enabled      = true
  domain       = var.domain
  acme_email   = var.acme_email
  cf_zone_id   = var.cloudflare_zone_id
  cf_api_token = local.cloudflare_api_token
  depends_on = [
    module.microk8s_addons,
    module.calico,
  ]
}
module "cert_issuers" {
  source     = "./modules/cert_issuers"
  enabled    = true
  domain     = var.domain
  acme_email = var.acme_email
  depends_on = [
    module.cert_manager
  ]
}

module "external_dns" {
  source       = "./modules/external_dns"
  enabled      = true
  domain       = var.domain
  zone_id      = var.cloudflare_zone_id
  cf_api_token = local.cloudflare_api_token
  depends_on = [
    module.cert_issuers
  ]
}

# Storage Operators
module "rook_operator" {
  source  = "./modules/rook_operator"
  enabled = true
  depends_on = [
    module.calico
  ]
}

module "rook_cluster" {
  source       = "./modules/rook_cluster"
  enabled      = true
  storage_size = var.opensearch_storage
  depends_on = [
    module.rook_operator
  ]
}

module "minio_operator" {
  source  = "./modules/minio_operator"
  enabled = true
  depends_on = [
    module.calico
  ]
}

module "minio_tenant" {
  source       = "./modules/minio_tenant"
  enabled      = true
  storage_size = var.minio_storage
  depends_on = [
    module.minio_operator,
    module.rook_cluster
  ]
}

# Datastores
module "postgres" {
  source       = "./modules/postgres"
  enabled      = true
  storage_size = var.postgres_storage
  pg_version   = var.postgres_version
  depends_on = [
    module.rook_cluster
  ]
}

module "redis" {
  source  = "./modules/redis"
  enabled = true
  depends_on = [
    module.rook_cluster
  ]
}

module "pgbouncer" {
  source  = "./modules/pgbouncer"
  enabled = true
  depends_on = [
    module.postgres
  ]
}

module "postgraphile" {
  source  = "./modules/postgraphile"
  enabled = true
  depends_on = [
    module.postgres
  ]
}

