# HTTPRoutes for all services

# Keycloak (no OIDC auth needed)
resource "kubernetes_manifest" "httproute_keycloak" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "keycloak"
      namespace = "auth"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate"
      }
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
          name = "keycloak"
          port = 8080
        }]
      }]
    }
  }
}

# Grafana
resource "kubernetes_manifest" "httproute_grafana" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "grafana"
      namespace = "observability"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["grafana.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "kube-prometheus-stack-grafana"
          port = 80
        }]
      }]
    }
  }
}

# Prometheus
resource "kubernetes_manifest" "httproute_prometheus" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "prometheus"
      namespace = "observability"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["prometheus.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "kube-prometheus-stack-prometheus"
          port = 9090
        }]
      }]
    }
  }
}

# Alertmanager
resource "kubernetes_manifest" "httproute_alertmanager" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "alertmanager"
      namespace = "observability"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["alertmanager.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "alertmanager"
          port = 9093
        }]
      }]
    }
  }
}

# Temporal
resource "kubernetes_manifest" "httproute_temporal" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "temporal-web"
      namespace = "temporal"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["temporal.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "temporal-web"
          port = 8080
        }]
      }]
    }
  }
}

# Uptime Kuma
resource "kubernetes_manifest" "httproute_kuma" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "uptime-kuma"
      namespace = "observability"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["kuma.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "uptime-kuma"
          port = 3001
        }]
      }]
    }
  }
}

# MailHog
resource "kubernetes_manifest" "httproute_mailhog" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "mailhog"
      namespace = "devtools"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["mailhog.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "mailhog"
          port = 8025
        }]
      }]
    }
  }
}

# OpenSearch
resource "kubernetes_manifest" "httproute_opensearch" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "opensearch"
      namespace = "search"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["opensearch.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "opensearch-cluster-master"
          port = 9200
        }]
      }]
    }
  }
}

# PgAdmin
resource "kubernetes_manifest" "httproute_pgadmin" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "pgadmin4"
      namespace = "data"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["pgadmin.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "pgadmin4"
          port = 80
        }]
      }]
    }
  }
}

# SonarQube
resource "kubernetes_manifest" "httproute_sonarqube" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "sonarqube"
      namespace = "devtools"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["sonarqube.aldous.info"]
      rules = [{
        matches = [{
          path = {
            type  = "PathPrefix"
            value = "/"
          }
        }]
        backendRefs = [{
          name = "sonarqube"
          port = 9000
        }]
      }]
    }
  }
}

# Web Application
resource "kubernetes_manifest" "httproute_web" {
  count = var.enabled ? 1 : 0
  depends_on = [kubernetes_manifest.kong_gatewayclass]
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "web"
      namespace = "apps"
      annotations = {
        "konghq.com/cluster-plugins" = "global-rate,oidc-auth"
      }
    }
    spec = {
      parentRefs = [{
        name      = "edge"
        namespace = "gateway"
      }]
      hostnames = ["web.aldous.info"]
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
}