#!/usr/bin/env sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001

until curl -fs "$KONG_URL/status" >/dev/null; do sleep 2; done

if ! curl -fs "$KONG_URL/plugins" | jq -e '.data[] | select(.name=="rate-limiting")' >/dev/null; then
  curl -fs -X POST "$KONG_URL/plugins" -H 'Content-Type: application/json' \
       -d '{"name":"rate-limiting",
            "config":{"minute":60,"policy":"local","limit_by":"ip"}}'
fi

curl -fs -X PUT "$KONG_URL/consumers/oidcuser" -H 'Content-Type: application/json' \
     -d '{"username":"oidcuser","custom_id":"oidcuser"}' >/dev/null

SERVICE_JSON=$(curl -fs -X PUT "$KONG_URL/services/pgadmin" \
  -H 'Content-Type: application/json' \
  -d '{"name":"pgadmin","host":"pgadmin","port":80,"protocol":"http"}')

SERVICE_ID=$(echo "$SERVICE_JSON" | jq -r '.id')

curl -fs -X PUT "$KONG_URL/routes/pgadmin-route" -H 'Content-Type: application/json' \
  -d '{"name":"pgadmin-route",
       "hosts":["pgadmin.'"$DOMAIN"'"],
       "service":{"id":"'"$SERVICE_ID"'"}}' >/dev/null

curl -fs -X POST "$KONG_URL/plugins" -H 'Content-Type: application/json' \
  -d '{
        "name":"oidcify",
        "service":{"id":"'"$SERVICE_ID"'"},
        "config":{
          "issuer":"https://keycloak.'"$DOMAIN"'/realms/mindfield",
          "client_id":"'"$CLIENT_ID_PGADMIN"'",
          "client_secret":"'"$CLIENT_SECRET_PGADMIN"'",
          "redirect_uri":"https://pgadmin.'"$DOMAIN"'/callback",
          "consumer_name":"oidcuser",
          "scopes":["openid","email","profile"],
          "cookie_name":"pgadmin_session",
          "cookie_hash_key_hex":"'"$KONG_COOKIE_HASH_PGADMIN"'",
          "cookie_block_key_hex":"'"$KONG_COOKIE_BLOCK_PGADMIN"'"
        }
      }' | jq '.name, .service.id'
