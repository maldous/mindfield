resource "kubernetes_job" "keycloak_admin_setup" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "keycloak-admin-setup"
    namespace = "auth"
  }
  spec {
    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"
        container {
          name  = "admin-setup"
          image = "postgres:16"
          command = ["/bin/bash"]
          args = ["-c", <<-EOT
            set -e
            export PGPASSWORD=keycloak
            echo "Waiting for Keycloak to initialize database..."
            until psql -h postgres-postgresql.data.svc.cluster.local -U keycloak -d keycloak -c "SELECT 1 FROM realm WHERE name='master'" 2>/dev/null; do
              echo "Waiting for master realm..."
              sleep 5
            done
            if ! psql -h postgres-postgresql.data.svc.cluster.local -U keycloak -d keycloak -tAc "SELECT 1 FROM user_entity WHERE username='admin' AND realm_id=(SELECT id FROM realm WHERE name='master')" | grep -q 1; then
              echo "Creating admin user..."
              REALM_ID=$(psql -h postgres-postgresql.data.svc.cluster.local -U keycloak -d keycloak -tAc "SELECT id FROM realm WHERE name='master'")
              psql -h postgres-postgresql.data.svc.cluster.local -U keycloak -d keycloak <<SQL
                INSERT INTO user_entity (id, email, email_constraint, email_verified, enabled, federation_link, first_name, last_name, realm_id, username, created_timestamp, service_account_client_link, not_before)
                VALUES (gen_random_uuid()::text, NULL, gen_random_uuid()::text, false, true, NULL, NULL, NULL, '$REALM_ID', 'admin', extract(epoch from now()) * 1000, NULL, 0);
                INSERT INTO credential (id, salt, type, user_id, created_date, user_label, secret_data, credential_data, priority)
                SELECT gen_random_uuid()::text, NULL, 'password', id, extract(epoch from now()) * 1000, NULL,
                  '{"value":"JDJhJDEwJGNZS2JpZmJjTjlwN0lTSldSQ0NOcnVmQ2FDdGFOL0YxNS9IYlhJZDdpN1BhU3k4RDBPNW1T","salt":null,"additionalParameters":{}}',
                  '{"hashIterations":27500,"algorithm":"pbkdf2-sha256","additionalParameters":{}}',
                  10
                FROM user_entity WHERE username='admin' AND realm_id='$REALM_ID';
                INSERT INTO user_role_mapping (role_id, user_id)
                SELECT r.id, u.id
                FROM keycloak_role r, user_entity u
                WHERE r.name = 'admin' AND r.realm_id = '$REALM_ID'
                  AND u.username = 'admin' AND u.realm_id = '$REALM_ID';
SQL
              echo "Admin user created successfully"
            else
              echo "Admin user already exists"
            fi
          EOT
          ]
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
    time_sleep.wait_for_keycloak
  ]
}
resource "time_sleep" "wait_for_keycloak" {
  count = var.enabled ? 1 : 0
  depends_on = [helm_release.keycloak]
  create_duration = "60s"
}
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
            echo "Waiting for Keycloak to be ready..."
            until curl -fs http://keycloak-keycloakx-http.auth.svc.cluster.local:80/auth/realms/master >/dev/null; do
              echo "Waiting for Keycloak..."
              sleep 5
            done
            echo "Waiting for admin user to be created automatically..."
            sleep 30
            echo "Getting admin token..."
            KC_TOKEN=$(curl -fs \
              -d "client_id=admin-cli" \
              -d "username=admin" \
              -d "password=admin123" \
              -d "grant_type=password" \
              "http://keycloak-keycloakx-http.auth.svc.cluster.local:80/auth/realms/master/protocol/openid-connect/token" \
              | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
            if [ -z "$KC_TOKEN" ]; then
              echo "Failed to get admin token"
              exit 1
            fi
            echo "Successfully authenticated as admin"
            echo "Creating mindfield realm..."
            curl -fs -X POST "http://keycloak-keycloakx-http.auth.svc.cluster.local:80/auth/admin/realms" \
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
            echo "Creating root client..."
            curl -fs -X POST "http://keycloak-keycloakx-http.auth.svc.cluster.local:80/auth/admin/realms/mindfield/clients" \
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
            echo "Creating postgraphile client..."
            curl -fs -X POST "http://keycloak-keycloakx-http.auth.svc.cluster.local:80/auth/admin/realms/mindfield/clients" \
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
            echo "Keycloak configuration completed successfully"
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
