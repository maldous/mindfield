resource "kubernetes_network_policy" "kong" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "kong"
    namespace = "gateway"
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "kong"
      }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      ports {
        port     = "8000"
        protocol = "TCP"
      }
      ports {
        port     = "8443"
        protocol = "TCP"
      }
    }
    ingress {
      ports {
        port     = "8001"
        protocol = "TCP"
      }
    }
    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53"
        protocol = "TCP"
      }
    }
    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
    egress {
      ports {
        port     = "8080"
        protocol = "TCP"
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "auth"
          }
        }
      }
    }
    egress {
      ports {
        port     = "5000"
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
    egress {
      ports {
        port     = "80"
        protocol = "TCP"
      }
      ports {
        port     = "443"
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
