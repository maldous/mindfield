resource "kubernetes_manifest" "kong_oidc_root" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "oidc-root"
      namespace = "gateway"
    }
    plugin = "oidcify"
    config = {
      issuer        = "https://keycloak.aldous.info/auth/realms/mindfield"
      client_id     = "mindfield-root"
      client_secret = "${data.kubernetes_secret.oidc_secrets[0].data.root_client_secret}"
      redirect_uri  = "https://aldous.info/callback"
      scope         = "openid profile email"
      cookie_name   = "mindfield_session"
      cookie_secure = true
      cookie_httponly = true
      cookie_samesite = "Lax"
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}
resource "kubernetes_manifest" "kong_oidc_postgraphile" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "oidc-postgraphile"
      namespace = "gateway"
    }
    plugin = "oidcify"
    config = {
      issuer        = "https://keycloak.aldous.info/auth/realms/mindfield"
      client_id     = "mindfield-postgraphile"
      client_secret = "${data.kubernetes_secret.oidc_secrets[0].data.postgraphile_client_secret}"
      redirect_uri  = "https://postgraphile.aldous.info/callback"
      scope         = "openid profile email"
      cookie_name   = "postgraphile_session"
      cookie_secure = true
      cookie_httponly = true
      cookie_samesite = "Lax"
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}
data "kubernetes_secret" "oidc_secrets" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "oidc-client-secrets"
    namespace = "gateway"
  }
}
