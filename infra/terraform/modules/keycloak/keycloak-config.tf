# Keycloak Configuration Job
resource "kubernetes_job" "keycloak_config" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "keycloak-config"
    namespace = "auth"
  }
  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"
        container {
          name  = "keycloak-config"
          image = "curlimages/curl:latest"
          command = ["/bin/sh"]
          args = ["-c", <<-EOT
            set -e
            
            # Wait for Keycloak to be ready
            until curl -fs http://keycloak.auth.svc.cluster.local:8080/realms/master >/dev/null; do
              echo "Waiting for Keycloak..."
              sleep 5
            done
            
            # Get admin token
            KC_TOKEN=$(curl -fs \
              -d "client_id=admin-cli" \
              -d "username=admin" \
              -d "password=admin123" \
              -d "grant_type=password" \
              "http://keycloak.auth.svc.cluster.local:8080/realms/master/protocol/openid-connect/token" \
              | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
            
            if [ -z "$KC_TOKEN" ]; then
              echo "Failed to get admin token"
              exit 1
            fi
            
            # Create realm
            curl -fs -X POST "http://keycloak.auth.svc.cluster.local:8080/admin/realms" \
              -H "Authorization: Bearer $KC_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{
                "realm": "mindfield",
                "enabled": true,
                "registrationAllowed": true,
                "verifyEmail": false,
                "resetPasswordAllowed": true,
                "sslRequired": "external",
                "displayName": "Mindfield"
              }' || echo "Realm might already exist"
            
            # Create root client
            curl -fs -X POST "http://keycloak.auth.svc.cluster.local:8080/admin/realms/mindfield/clients" \
              -H "Authorization: Bearer $KC_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{
                "clientId": "mindfield-root",
                "enabled": true,
                "clientAuthenticatorType": "client-secret",
                "secret": "'"$(cat /etc/secrets/root_client_secret)"'",
                "redirectUris": ["https://aldous.info/callback"],
                "webOrigins": ["https://aldous.info"],
                "standardFlowEnabled": true,
                "publicClient": false,
                "protocol": "openid-connect"
              }' || echo "Root client might already exist"
            
            # Create postgraphile client
            curl -fs -X POST "http://keycloak.auth.svc.cluster.local:8080/admin/realms/mindfield/clients" \
              -H "Authorization: Bearer $KC_TOKEN" \
              -H "Content-Type: application/json" \
              -d '{
                "clientId": "mindfield-postgraphile",
                "enabled": true,
                "clientAuthenticatorType": "client-secret",
                "secret": "'"$(cat /etc/secrets/postgraphile_client_secret)"'",
                "redirectUris": ["https://postgraphile.aldous.info/callback"],
                "webOrigins": ["https://postgraphile.aldous.info"],
                "standardFlowEnabled": true,
                "publicClient": false,
                "protocol": "openid-connect"
              }' || echo "PostGraphile client might already exist"
            
            echo "Keycloak configuration completed"
          EOT
          ]
          volume_mount {
            name       = "oidc-secrets"
            mount_path = "/etc/secrets"
            read_only  = true
          }
        }
        volume {
          name = "oidc-secrets"
          secret {
            secret_name = "oidc-client-secrets"
          }
        }
      }
    }
  }
  wait_for_completion = true
  timeouts {
    create = "10m"
    update = "10m"
  }
  depends_on = [
    helm_release.keycloak,
    kubernetes_secret.oidc_client_secrets_auth
  ]
}