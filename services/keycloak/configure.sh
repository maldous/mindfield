#!/usr/bin/env sh
set -euo pipefail
set -x

KC_URL="http://keycloak:8080"

until curl -fs "${KC_URL}/realms/master" >/dev/null; do sleep 5; done

KC_TOKEN=$(curl -fs \
  -d "client_id=admin-cli" \
  -d "username=${KC_BOOTSTRAP_ADMIN_USERNAME}" \
  -d "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  "${KC_URL}/realms/master/protocol/openid-connect/token" | jq -r '.access_token')

[ -z "${KC_TOKEN}" ] || [ "${KC_TOKEN}" = "null" ] && exit 1

curl -fs -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${NAME}" || \
curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  "${KC_URL}/admin/realms" -d '{
  "realm":"'"${NAME}"'",
  "enabled":true,
  "registrationAllowed":true,
  "verifyEmail":true,
  "resetPasswordAllowed":true,
  "sslRequired":"external",
  "bruteForceProtected":true,
  "passwordPolicy":"length(8) and notUsername() and digits(1) and lowerCase(1) and upperCase(1)",
  "displayName":"Mindfield"
}'

REALM_JSON=$(curl -fs -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${NAME}" | \
  jq ".smtpServer = {host:\"mailhog\",port:\"1025\",from:\"noreply@aldous.info\",auth:false}")

curl -fs -X PUT -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  --data "${REALM_JSON}" \
  "${KC_URL}/admin/realms/${NAME}"

CLIENT_JSON_PGADMIN=$(jq -nc --arg cid "${CLIENT_ID_PGADMIN}" --arg sec "${CLIENT_SECRET_PGADMIN}" --arg dom "pgadmin.${DOMAIN}" '{
  clientId:$cid,
  enabled:true,
  clientAuthenticatorType:"client-secret",
  secret:$sec,
  redirectUris:["https://\($dom)/callback"],
  webOrigins:["https://\($dom)"],
  standardFlowEnabled:true,
  publicClient:false,
  protocol:"openid-connect"
}')

CLIENT_JSON_MAILHOG=$(jq -nc --arg cid "${CLIENT_ID_MAILHOG}" --arg sec "${CLIENT_SECRET_MAILHOG}" --arg dom "mailhog.${DOMAIN}" '{
  clientId:$cid,
  enabled:true,
  clientAuthenticatorType:"client-secret",
  secret:$sec,
  redirectUris:["https://\($dom)/callback"],
  webOrigins:["https://\($dom)"],
  standardFlowEnabled:true,
  publicClient:false,
  protocol:"openid-connect"
}')

CID_PGADMIN=$(curl -fs -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${NAME}/clients" | \
  jq -r '.[] | select(.clientId=="'"${CLIENT_ID_PGADMIN}"'") | .id')
if [ -z "${CID_PGADMIN}" ]; then
  curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d "${CLIENT_JSON_PGADMIN}" \
  "${KC_URL}/admin/realms/${NAME}/clients"
else
  curl -fs -X PUT -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d "${CLIENT_JSON_PGADMIN}" \
  "${KC_URL}/admin/realms/${NAME}/clients/${CID_PGADMIN}"
fi

CID_MAILHOG=$(curl -fs -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${NAME}/clients" | \
  jq -r '.[] | select(.clientId=="'"${CLIENT_ID_MAILHOG}"'") | .id')
if [ -z "${CID_MAILHOG}" ]; then
  curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d "${CLIENT_JSON_MAILHOG}" \
  "${KC_URL}/admin/realms/${NAME}/clients"
else
  curl -fs -X PUT -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d "${CLIENT_JSON_MAILHOG}" \
  "${KC_URL}/admin/realms/${NAME}/clients/${CID_MAILHOG}"
fi

USER_ROLE_ID=$(curl -fs -H "Authorization: Bearer ${KC_TOKEN}" "${KC_URL}/admin/realms/${NAME}/roles" | \
  jq -r '.[] | select(.name=="user") | .id')

if [ -z "${USER_ROLE_ID}" ]; then
  USER_ROLE_ID=$(curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  -d '{"name":"user"}' \
  "${KC_URL}/admin/realms/${NAME}/roles" | jq -r '.id')
fi

curl -fs -X POST -H "Authorization: Bearer ${KC_TOKEN}" -H "Content-Type: application/json" \
  "${KC_URL}/admin/realms/${NAME}/default-roles/${NAME}/roles" \
  -d '[{"id":"'"${USER_ROLE_ID}"'","name":"user"}]'
