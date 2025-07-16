#!/bin/sh
set -euo pipefail
set -x

KC_URL="http://keycloak:8080"

until curl -s "$KC_URL/realms/master" >/dev/null; do sleep 5; done

KC_TOKEN=$(curl -s -d "client_id=admin-cli" -d "username=$KC_BOOTSTRAP_ADMIN_USERNAME" -d "password=$KC_BOOTSTRAP_ADMIN_PASSWORD" -d "grant_type=password" "$KC_URL/realms/master/protocol/openid-connect/token" | jq -r '.access_token')
[ -z "$KC_TOKEN" || "$KC_TOKEN" == "null" ] && echo "Failed to get admin token" && exit 1

curl -s -f -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/admin/realms/$NAME" || \
curl -s -X POST -H "Authorization: Bearer $KC_TOKEN" -H "Content-Type: application/json" "$KC_URL/admin/realms" -d "{\"realm\":\"$NAME\",\"enabled\":true}"

CLIENT_JSON=$(jq -n \
  --arg id "$NAME" \
  --arg secret "$KC_SECRET" \
  --arg domain "$DOMAIN" \
  '{
    clientId: $id,
    enabled: true,
    clientAuthenticatorType: "client-secret",
    secret: $secret,
    redirectUris: [
      "https://\($domain)/callback"
    ],
    webOrigins: [
      "https://\($domain)"
    ],
    standardFlowEnabled: true,
    implicitFlowEnabled: false,
    directAccessGrantsEnabled: false,
    serviceAccountsEnabled: false,
    publicClient: false,
    protocol: "openid-connect",
    fullScopeAllowed: true
  }')

CID=$(curl -s -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/admin/realms/$NAME/clients" | jq -r ".[] | select(.clientId==\"$NAME\") | .id")

JSON_PGADMIN=$(jq -n --arg cid "$CLIENT_ID_PGADMIN" --arg sec "$CLIENT_SECRET_PGADMIN" --arg dom "pgadmin.${DOMAIN}" '
  { clientId:$cid, enabled:true, clientAuthenticatorType:"client-secret",
    secret:$sec, redirectUris:["https://\($dom)/callback"],
    webOrigins:["https://\($dom)"], standardFlowEnabled:true }' )

curl -s -H "Authorization: Bearer $KC_TOKEN" "$KC_URL/admin/realms/$NAME/clients" | \
     jq -e ".[] | select(.clientId==\"$CLIENT_ID_PGADMIN\")" >/dev/null || \
curl -s -X POST -H "Authorization: Bearer $KC_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PGADMIN" "$KC_URL/admin/realms/$NAME/clients"

if [ -z "$CID" ]; then
  curl -s -X POST -H "Authorization: Bearer $KC_TOKEN" -H "Content-Type: application/json" "$KC_URL/admin/realms/$NAME/clients" -d "$CLIENT_JSON"
else
  curl -s -X PUT -H "Authorization: Bearer $KC_TOKEN" -H "Content-Type: application/json" "$KC_URL/admin/realms/$NAME/clients/$CID" -d "$CLIENT_JSON"
fi
