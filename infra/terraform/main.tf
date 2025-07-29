data "dotenv" "config" {
  filename = ".env"
}
locals {
  cloudflare_api_token = var.cloudflare_api_token != "" ? var.cloudflare_api_token : data.dotenv.config.env["CLOUDFLARE_API_TOKEN"]
}
module "microk8s_addons" {
  source = "./modules/microk8s_addons"
  enabled = true
  metallb_range = var.metallb_range
  kong_proxy_ip = var.kong_proxy_ip
}
module "calico" {
  source = "./modules/calico"
  enabled = true
  domain = var.domain
  cidr_allow_admin = var.cidr_allow_admin
}
module "cert_manager" {
  source = "./modules/cert_manager"
  enabled = true
  domain = var.domain
  acme_email = var.acme_email
  cf_zone_id = var.cloudflare_zone_id
  cf_api_token = local.cloudflare_api_token
  depends_on = [
    module.microk8s_addons,
    module.calico,
  ]
}
module "external_dns" {
  source = "./modules/external_dns"
  enabled = true
  domain = var.domain
  zone_id = var.cloudflare_zone_id
  cf_api_token = local.cloudflare_api_token
  depends_on = [
    module.external_secrets
  ]
}
module "external_secrets" {
  source = "./modules/external_secrets"
  enabled = true
  cf_api_token = local.cloudflare_api_token
  depends_on = [module.cert_manager]
  create_objects = var.external_secrets_create_objects
}
