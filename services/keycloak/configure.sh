#!/usr/bin/env sh
set -euo pipefail
set -x

KC_URL=http://keycloak:8080
until curl -fs "${KC_URL}/realms/master" >/dev/null; do sleep 5; done

if curl -fs -X GET "${KC_URL}/realms/${NAME}" >/dev/null; then
  exit 0
fi

################################################################################

KC_TOKEN=$(curl -fs \
  -d "client_id=admin-cli" \
  -d "username=${KC_BOOTSTRAP_ADMIN_USERNAME}" \
  -d "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "scope=openid profile email roles offline_access" \
  "${KC_URL}/realms/master/protocol/openid-connect/token" |
  jq -r '.access_token')

[ -z "${KC_TOKEN}" ] || [ "${KC_TOKEN}" = "null" ] && exit 1

curl -fs -X POST \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
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
  -d '{
  "smtpServer":{
    "host":"mailhog",
    "port":"1025",
    "from":"noreply@aldous.info",
    "auth":false
    }
  }' \
  "${KC_URL}/admin/realms/${NAME}"

################################################################################

curl -fs \
  -H "Authorization: Bearer ${KC_TOKEN}" \
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

curl -fs \
  -H "Authorization: Bearer ${KC_TOKEN}" \
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

curl -fs \
  -H "Authorization: Bearer ${KC_TOKEN}" \
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

curl -fs \
  -H "Authorization: Bearer ${KC_TOKEN}" \
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

curl -fs \
  -H "Authorization: Bearer ${KC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
  "clientId": "'"${CLIENT_ID_MINIO}"'",
  "enabled": true,
  "clientAuthenticatorType": "client-secret",
  "secret": "'"${CLIENT_SECRET_MINIO}"'",
  "redirectUris": ["https://minio.'"${DOMAIN}"'/callback"],
  "webOrigins":   ["https://minio.'"${DOMAIN}"'"],
  "standardFlowEnabled": true,
  "publicClient": false,
  "protocol": "openid-connect"
  }' \
  "${KC_URL}/admin/realms/${NAME}/clients"

################################################################################

curl -fs -X POST \
  -H "Authorization: Bearer $KC_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
  "name": "user",
  "description": "role_user"
  }' \
  "${KC_URL}/admin/realms/${NAME}/roles"

USER_ROLE=$( curl -fs\
  -H "Authorization: Bearer $KC_TOKEN" \
  "${KC_URL}/admin/realms/${NAME}/roles/user" \
  | jq -c '{ id: .id, name: .name, containerId: .containerId }'
)

DEFAULT_ROLE_ID=$( curl -fs\
  -H "Authorization: Bearer $KC_TOKEN" \
  "${KC_URL}/admin/realms/${NAME}/roles/default-roles-${NAME}" \
  | jq -r .id
)

curl -fs -X POST \
  -H "Authorization: Bearer $KC_TOKEN" \
  -H "Content-Type: application/json" \
  -d "[${USER_ROLE}]" \
  "${KC_URL}/admin/realms/${NAME}/roles-by-id/${DEFAULT_ROLE_ID}/composites" 

################################################################################

curl -fs -X PUT \
  -H "Authorization: Bearer $KC_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "cookieSameSite": "none",
    "cookieSecure": true,
    "authSessionCookiePath": "/"
  }' \
  "${KC_URL}/admin/realms/${NAME}"

################################################################################

echo "services/keycloak/configure.sh"
