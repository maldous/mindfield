# Kong Consumer for OIDC
resource "kubernetes_manifest" "kong_oidc_consumer" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongConsumer"
    metadata = {
      name      = "oidcuser"
      namespace = "gateway"
    }
    username   = "oidcuser"
    custom_id  = "oidcuser"
  }
  depends_on = [time_sleep.wait_for_kong]
}

# Kong OIDC Plugin for Root Domain
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
      issuer                   = "https://keycloak.aldous.info/realms/mindfield"
      client_id                = "mindfield-root"
      redirect_uri             = "https://aldous.info/callback"
      consumer_name            = "oidcuser"
      scopes                   = ["openid", "email", "profile"]
      cookie_name              = "root_session"
    }
    configFrom = {
      secretKeyRef = {
        name = "oidc-client-secrets"
        key  = "root_client_secret"
      }
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}

# Kong OIDC Plugin for PostGraphile
resource "kubernetes_manifest" "kong_oidc_postgraphile" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "configuration.konghq.com/v1"
    kind       = "KongPlugin"
    metadata = {
      name      = "oidc-postgraphile"
      namespace = "data"
    }
    plugin = "oidcify"
    config = {
      issuer                   = "https://keycloak.aldous.info/realms/mindfield"
      client_id                = "mindfield-postgraphile"
      redirect_uri             = "https://postgraphile.aldous.info/callback"
      consumer_name            = "oidcuser"
      scopes                   = ["openid", "email", "profile"]
      cookie_name              = "postgraphile_session"
    }
    configFrom = {
      secretKeyRef = {
        name = "oidc-client-secrets"
        key  = "postgraphile_client_secret"
      }
    }
  }
  depends_on = [time_sleep.wait_for_kong]
}

# HTTPRoute for PostGraphile with OIDC
resource "kubernetes_manifest" "postgraphile_httproute" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "postgraphile-route"
      namespace = "data"
      annotations = {
        "konghq.com/plugins" = "oidc-postgraphile"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["postgraphile.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "postgraphile"
          port = 5000
        }]
      }]
    }
  }
  depends_on = [kubernetes_manifest.kong_gateway]
}