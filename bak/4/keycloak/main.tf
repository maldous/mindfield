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
            echo "Creating keycloak user..."
            psql -h postgres-postgresql.data.svc.cluster.local -U postgres -d postgres -c "CREATE USER keycloak WITH PASSWORD 'keycloak';"
            echo "Creating keycloak database..."
            createdb -h postgres-postgresql.data.svc.cluster.local -U postgres -O keycloak keycloak
            echo "Granting privileges..."
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
  depends_on = [var.postgres_dependency]
}
resource "kubernetes_secret" "keycloak_db_secret" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "keycloak-db-secret"
    namespace = "auth"
  }
  data = {
    password = "keycloak"
  }
}
resource "kubernetes_secret" "keycloak_admin_secret" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "keycloak-admin-secret"
    namespace = "auth"
  }
  data = {
    password = "admin123"
  }
}
resource "kubernetes_network_policy" "auth_default_deny" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "default-deny-all"
    namespace = "auth"
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}
resource "kubernetes_network_policy" "auth_allow_dns" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "allow-dns"
    namespace = "auth"
  }
  spec {
    pod_selector {}
    policy_types = ["Egress"]
    egress {
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
  }
}
resource "kubernetes_network_policy" "auth_internal_communication" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "allow-internal-auth"
    namespace = "auth"
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        pod_selector {}
      }
    }
    egress {
      to {
        pod_selector {}
      }
    }
  }
}
resource "kubernetes_network_policy" "keycloak_external_access" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  metadata {
    name      = "keycloak-external-access"
    namespace = "auth"
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "keycloakx"
      }
    }
    policy_types = ["Ingress", "Egress"]
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "gateway"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }
    egress {
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "data"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}
