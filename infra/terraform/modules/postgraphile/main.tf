resource "kubernetes_deployment" "postgraphile" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "postgraphile"
    namespace = "data"
    labels = {
      app = "postgraphile"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgraphile"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgraphile"
        }
      }
      spec {
        container {
          image = "graphile/postgraphile:4.13.0"
          name  = "postgraphile"
          port {
            container_port = 5000
          }
          env {
            name  = "DATABASE_URL"
            value = "postgres://mindfield:mindfield@postgres-postgresql.data.svc.cluster.local:5432/mindfield"
          }
          env {
            name  = "POSTGRAPHILE_OPTIONS"
            value = "--enhance-graphiql --allow-explain --dynamic-json --no-setof-functions-contain-nulls --no-ignore-rbac --show-error-stack=json --extended-errors hint,detail,errcode --append-plugins @graphile-contrib/pg-simplify-inflector --export-schema-graphql schema.graphql --graphiql / --enhance-graphiql --allow-explain --enable-query-batching --legacy-relations omit --retry-on-init-fail --connection postgresql://mindfield:mindfield@postgres-postgresql.data.svc.cluster.local:5432/mindfield"
          }
          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }
}

# Network policy to allow PostGraphile to connect to PostgreSQL
resource "kubernetes_network_policy" "postgraphile" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "postgraphile"
    namespace = "data"
  }
  spec {
    pod_selector {
      match_labels = {
        app = "postgraphile"
      }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      ports {
        port     = "5000"
        protocol = "TCP"
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "gateway"
          }
        }
      }
    }
    egress {
      # Allow DNS
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }
    egress {
      # Allow connection to PostgreSQL
      ports {
        port     = "5432"
        protocol = "TCP"
      }
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "postgresql"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgraphile" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "postgraphile"
    namespace = "data"
  }
  spec {
    selector = {
      app = "postgraphile"
    }
    port {
      port        = 5000
      target_port = 5000
    }
    type = "ClusterIP"
  }
}
