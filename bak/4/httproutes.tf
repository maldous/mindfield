resource "kubernetes_manifest" "keycloak_httproute" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "keycloak"
      namespace = "auth"
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["keycloak.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "keycloak-keycloakx-http"
          port = 80
        }]
      }]
    }
  }
  depends_on = [kubernetes_manifest.kong_gateway]
}
resource "kubernetes_manifest" "root_httproute" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "root"
      namespace = "gateway"
      annotations = {
        "konghq.com/plugins" = "oidc-root"
      }
    }
    spec = {
      parentRefs = [{
        name = "edge"
      }]
      hostnames = ["aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "web"
          port = 3000
        }]
      }]
    }
  }
  depends_on = [
    kubernetes_manifest.kong_gateway,
    kubernetes_manifest.kong_oidc_root
  ]
}
