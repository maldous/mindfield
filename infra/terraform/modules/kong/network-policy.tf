# Kong Network Policy for OIDC and Gateway functionality
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
    
    # Allow ingress on Kong proxy ports
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
    
    # Allow ingress on Kong admin port
    ingress {
      ports {
        port     = "8001"
        protocol = "TCP"
      }
    }
    
    # Allow DNS
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
    
    # Allow HTTPS to external Keycloak (for OIDC)
    egress {
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }
    
    # Allow HTTP to internal Keycloak (when deployed)
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
    
    # Allow connection to PostGraphile
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
    
    # Allow connection to other backend services
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