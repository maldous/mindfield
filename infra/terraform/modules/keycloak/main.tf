resource "helm_release" "keycloak" {
  count            = var.enabled ? 1 : 0
  name             = "keycloak"
  namespace        = "auth"
  create_namespace = true

  repository      = "https://codecentric.github.io/helm-charts"
  chart           = "keycloakx"
  version         = "~> 7.0"
  timeout         = 600
  atomic          = true
  cleanup_on_fail = true

  values = [file("${path.root}/helm-values/keycloak.yaml")]

  depends_on = [var.postgres_dependency]
}

# Create Keycloak database and user in PostgreSQL
resource "kubernetes_job" "keycloak_db_setup" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "keycloak-db-setup"
    namespace = "auth"
  }
  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"
        container {
          name  = "db-setup"
          image = "postgres:16"
          command = ["/bin/bash"]
          args = ["-c", <<-EOT
            set -e
            export PGPASSWORD=postgres
            
            # Connect as postgres superuser
            # Check if database exists, create if not
            if ! psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d postgres -lqt | cut -d \| -f 1 | grep -qw keycloak; then
              createdb -h postgres-postgresql.data.svc.cluster.local -U postgres keycloak
            fi
            
            # Check if user exists, create if not
            if ! psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='keycloak'" | grep -q 1; then
              psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d postgres -c "CREATE USER keycloak WITH PASSWORD 'keycloak';"
            fi
            
            # Grant privileges
            psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d keycloak -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
            psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d keycloak -c "GRANT ALL ON SCHEMA public TO keycloak;"
            
            echo "Keycloak database setup completed successfully"
          EOT
          ]
        }
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "5m"
    update = "5m"
  }
}

# Keycloak database secret
resource "kubernetes_secret" "keycloak_db_secret" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "keycloak-db-secret"
    namespace = "auth"
  }
  data = {
    password = "keycloak"
  }
}

# Keycloak admin secret
resource "kubernetes_secret" "keycloak_admin_secret" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "keycloak-admin-secret"
    namespace = "auth"
  }
  data = {
    password = "admin123"
  }
}
