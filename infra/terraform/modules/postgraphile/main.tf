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
            value = "postgres://mindfield:mindfield@postgresql:5432/mindfield"
          }
          env {
            name  = "POSTGRAPHILE_OPTIONS"
            value = "--enhance-graphiql --allow-explain --dynamic-json --no-setof-functions-contain-nulls --no-ignore-rbac --show-error-stack=json --extended-errors hint,detail,errcode --append-plugins @graphile-contrib/pg-simplify-inflector --export-schema-graphql schema.graphql --graphiql / --enhance-graphiql --allow-explain --enable-query-batching --legacy-relations omit --connection postgresql://mindfield:mindfield@postgresql:5432/mindfield"
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
