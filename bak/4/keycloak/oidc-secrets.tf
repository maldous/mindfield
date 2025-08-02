resource "kubernetes_secret" "oidc_client_secrets_auth" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "oidc-client-secrets"
    namespace = "auth"
  }
  data = {
    root_client_id     = "mindfield-root"
    root_client_secret = "mindfield-root-secret-${random_password.root_secret[0].result}"
    postgraphile_client_id     = "mindfield-postgraphile"
    postgraphile_client_secret = "mindfield-postgraphile-secret-${random_password.postgraphile_secret[0].result}"
    cookie_hash_key  = random_password.cookie_hash[0].result
    cookie_block_key = random_password.cookie_block[0].result
  }
}
resource "kubernetes_secret" "oidc_client_secrets_gateway" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "oidc-client-secrets"
    namespace = "gateway"
  }
  data = {
    root_client_id     = "mindfield-root"
    root_client_secret = "mindfield-root-secret-${random_password.root_secret[0].result}"
    postgraphile_client_id     = "mindfield-postgraphile"
    postgraphile_client_secret = "mindfield-postgraphile-secret-${random_password.postgraphile_secret[0].result}"
    cookie_hash_key  = random_password.cookie_hash[0].result
    cookie_block_key = random_password.cookie_block[0].result
  }
}
resource "random_password" "root_secret" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "postgraphile_secret" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}
resource "random_password" "cookie_hash" {
  count   = var.enabled ? 1 : 0
  length  = 64
  special = false
}
resource "random_password" "cookie_block" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}
