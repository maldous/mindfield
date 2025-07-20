#!/usr/bin/env sh
set -euo pipefail
set -x

KC_URL=http://keycloak:8080

until curl -fs "${KC_URL}/realms/master" >/dev/null; do sleep 5; done

KC_TOKEN=$(curl -fs \
  -d "client_id=admin-cli" \
  -d "username=${KC_BOOTSTRAP_ADMIN_USERNAME}" \
  -d "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  "${KC_URL}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token' | tr -d "\n\r")

[ -z "${KC_TOKEN}" ] || [ "${KC_TOKEN}" = "null" ] && { echo "Could not obtain admin token"; exit 1; }

AUTH_HEADER="Authorization: Bearer ${KC_TOKEN}"
JSON_HEADER="Content-Type: application/json"

if curl -fs -H "${AUTH_HEADER}" "${KC_URL}/admin/realms/${NAME}" -o /dev/null; then
  curl -fs -X PUT "${KC_URL}/admin/realms/${NAME}" \
       -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
       -d "{
            \"realm\":\"${NAME}\",
            \"enabled\":true,
            \"smtpServer\":{\"host\":\"mailhog\",\"port\":\"1025\",\"from\":\"noreply@aldous.info\"},
            \"displayName\":\"Mindfield\"
          }"
else
  curl -fs -X POST "${KC_URL}/admin/realms" \
       -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
       -d "{
            \"realm\":\"${NAME}\",
            \"enabled\":true,
            \"registrationAllowed\":true,
            \"verifyEmail\":true,
            \"resetPasswordAllowed\":true,
            \"sslRequired\":\"external\",
            \"bruteForceProtected\":true,
            \"passwordPolicy\":\"length(8) and notUsername() and digits(1) and lowerCase(1) and upperCase(1)\",
            \"smtpServer\":{\"host\":\"mailhog\",\"port\":\"1025\",\"from\":\"noreply@aldous.info\",\"auth\":false},
            \"displayName\":\"Mindfield\"
          }"
fi

ensure_client() {
  cid="$1" secret="$2" redirect="$3" origin="$4"
  uid=$(curl -fs "${KC_URL}/admin/realms/${NAME}/clients?clientId=${cid}" -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
  | jq -r '.[0].id // empty')
  client_json="{
  \"clientId\":\"${cid}\",
  \"enabled\":true,
  \"clientAuthenticatorType\":\"client-secret\",
  \"secret\":\"${secret}\",
  \"redirectUris\":[\"${redirect}\"],
  \"webOrigins\":[\"${origin}\"],
  \"standardFlowEnabled\":true,
  \"publicClient\":false,
  \"protocol\":\"openid-connect\"
  }"
  if [ -z "${uid}" ]; then
    curl -fs -X POST "${KC_URL}/admin/realms/${NAME}/clients" -H "${AUTH_HEADER}" -H "${JSON_HEADER}" -d "${client_json}"
  else
    curl -fs -X PUT "${KC_URL}/admin/realms/${NAME}/clients/${uid}" -H "${AUTH_HEADER}" -H "${JSON_HEADER}" -d "${client_json}"
  fi
}

ensure_client "${CLIENT_ID_ROOT}" "${CLIENT_SECRET_ROOT}" "https://${DOMAIN}/callback" "https://${DOMAIN}"
ensure_client "${CLIENT_ID_PGADMIN}" "${CLIENT_SECRET_PGADMIN}" "https://pgadmin.${DOMAIN}/callback" "https://pgadmin.${DOMAIN}"
ensure_client "${CLIENT_ID_MAILHOG}" "${CLIENT_SECRET_MAILHOG}" "https://mailhog.${DOMAIN}/callback" "https://mailhog.${DOMAIN}"
ensure_client "${CLIENT_ID_REDISINSIGHT}" "${CLIENT_SECRET_REDISINSIGHT}" "https://redisinsight.${DOMAIN}/callback" "https://redisinsight.${DOMAIN}"
ensure_client "${CLIENT_ID_MINIO}" "${CLIENT_SECRET_MINIO}" "https://minio.${DOMAIN}/callback" "https://minio.${DOMAIN}"
ensure_client "${CLIENT_ID_ALERTMANAGER}" "${CLIENT_SECRET_ALERTMANAGER}" "https://alertmanager.${DOMAIN}/callback" "https://alertmanager.${DOMAIN}"
ensure_client "${CLIENT_ID_BLACKBOX}" "${CLIENT_SECRET_BLACKBOX}" "https://blackbox.${DOMAIN}/callback" "https://blackbox.${DOMAIN}"
ensure_client "${CLIENT_ID_GRAFANA}" "${CLIENT_SECRET_GRAFANA}" "https://grafana.${DOMAIN}/callback" "https://grafana.${DOMAIN}"
ensure_client "${CLIENT_ID_JAEGER}" "${CLIENT_SECRET_JAEGER}" "https://jaeger.${DOMAIN}/callback" "https://jaeger.${DOMAIN}"

role_json=$( curl -sS -H "${AUTH_HEADER}" -H "${JSON_HEADER}" "${KC_URL}/admin/realms/${NAME}/roles/user" || true)
role_uid=$(printf '%s' "$role_json" | jq -r '.id // empty')

if [ -z "$role_uid" ]; then
  curl -fs -X POST \
  "${KC_URL}/admin/realms/${NAME}/roles" \
  -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
  -d '{"name":"user","description":"role_user"}'
  role_uid=$( curl -fs \
  -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
  "${KC_URL}/admin/realms/${NAME}/roles/user" \
  | jq -r '.id'
  )
fi

default_uid=$(curl -fs "${KC_URL}/admin/realms/${NAME}/roles/default-roles-${NAME}" -H "${AUTH_HEADER}" -H "${JSON_HEADER}" | jq -r '.id')

if ! curl -fs "${KC_URL}/admin/realms/${NAME}/roles-by-id/${default_uid}/composites" -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
  | jq -e 'map(select(.name=="user")) | length>0' >/dev/null; then
  curl -fs -X POST \
  "${KC_URL}/admin/realms/${NAME}/roles-by-id/${default_uid}/composites" \
  -H "${AUTH_HEADER}" -H "${JSON_HEADER}" \
  -d "[{\"id\":\"${role_uid}\",\"name\":\"user\",\"containerId\":\"${NAME}\"}]"
fi

echo "services/keycloak/configure.sh"
