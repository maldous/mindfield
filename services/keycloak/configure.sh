#!/usr/bin/env sh
set -euo pipefail
set -x

KC_URL=http://keycloak:8080
until curl -fs "${KC_URL}/realms/master" >/dev/null; do sleep 5; done

################################################################################

KC_TOKEN=$(curl -fs \
  -d "client_id=admin-cli" \
  -d "username=${KC_BOOTSTRAP_ADMIN_USERNAME}" \
  -d "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  "${KC_URL}/realms/master/protocol/openid-connect/token" | jq -r '.access_token')
[ -z "${KC_TOKEN}" ] || [ "${KC_TOKEN}" = "null" ] && exit 1
curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d '{
  "realm":"'"${NAME}"'",
  "enabled":true,
  "registrationAllowed":true,
  "verifyEmail":true,
  "resetPasswordAllowed":true,
  "sslRequired":"external",
  "bruteForceProtected":true,
  "passwordPolicy":"length(8) and notUsername() and digits(1) and lowerCase(1) and upperCase(1)",
  "displayName":"Mindfield"
  }' \
  "${KC_URL}/admin/realms" 
curl -fs -X PUT \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"smtpServer":{"host":"mailhog","port":"1025","from":"noreply@aldous.info","auth":false}}' \
  "${KC_URL}/admin/realms/${NAME}"

################################################################################

curl -fs -H "Authorization: Bearer ${KC_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{
     "clientId": "'"${CLIENT_ID_ROOT}"'",
     "enabled": true,
     "clientAuthenticatorType": "client-secret",
     "secret": "'"${CLIENT_SECRET_ROOT}"'",
     "redirectUris": ["https://'"${DOMAIN}"'/callback"],
     "webOrigins":   ["https://'"${DOMAIN}"'"],
     "standardFlowEnabled": true,
     "publicClient": false,
     "protocol": "openid-connect"
     }' \
     "${KC_URL}/admin/realms/${NAME}/clients"

################################################################################

curl -fs -H "Authorization: Bearer ${KC_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{
     "clientId": "'"${CLIENT_ID_PGADMIN}"'",
     "enabled": true,
     "clientAuthenticatorType": "client-secret",
     "secret": "'"${CLIENT_SECRET_PGADMIN}"'",
     "redirectUris": ["https://pgadmin.'"${DOMAIN}"'/callback"],
     "webOrigins":   ["https://pgadmin.'"${DOMAIN}"'"],
     "standardFlowEnabled": true,
     "publicClient": false,
     "protocol": "openid-connect"
     }' \
     "${KC_URL}/admin/realms/${NAME}/clients"

################################################################################

curl -fs -H "Authorization: Bearer ${KC_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{
     "clientId": "'"${CLIENT_ID_MAILHOG}"'",
     "enabled": true,
     "clientAuthenticatorType": "client-secret",
     "secret": "'"${CLIENT_SECRET_MAILHOG}"'",
     "redirectUris": ["https://mailhog.'"${DOMAIN}"'/callback"],
     "webOrigins":   ["https://mailhog.'"${DOMAIN}"'"],
     "standardFlowEnabled": true,
     "publicClient": false,
     "protocol": "openid-connect"
     }' \
     "${KC_URL}/admin/realms/${NAME}/clients"

################################################################################

curl -fs -H "Authorization: Bearer ${KC_TOKEN}" \
     -H "Content-Type: application/json" \
     -d '{
     "clientId": "'"${CLIENT_ID_REDISINSIGHT}"'",
     "enabled": true,
     "clientAuthenticatorType": "client-secret",
     "secret": "'"${CLIENT_SECRET_REDISINSIGHT}"'",
     "redirectUris": ["https://redisinsight.'"${DOMAIN}"'/callback"],
     "webOrigins":   ["https://redisinsight.'"${DOMAIN}"'"],
     "standardFlowEnabled": true,
     "publicClient": false,
     "protocol": "openid-connect"
     }' \
     "${KC_URL}/admin/realms/${NAME}/clients"

################################################################################

curl -fs -X PUT \
     -H "Authorization: Bearer ${KC_TOKEN}" \
     -H "Content-Type: application/json" \
     -d "[{\"id\":\"$(curl -fs -X POST \
     -H \"Authorization: Bearer ${KC_TOKEN}\" \
     -H \"Content-Type: application/json\" \
     -d '{\"name\":\"user\"}' \
     \"${KC_URL}/admin/realms/${NAME}/roles\" \
     | jq -r .id)\",\"name\":\"user\"}]" \
     "${KC_URL}/admin/realms/${NAME}/default-roles"

################################################################################

echo "services/keycloak/configure.sh"
