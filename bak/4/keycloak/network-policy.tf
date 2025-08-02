resource "kubernetes_network_policy" "keycloak_db_access" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "keycloak-db-access"
    namespace = "auth"
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "data"
          }
        }
      }
    }
  }
}
