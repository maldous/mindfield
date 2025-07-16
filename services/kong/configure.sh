#!/bin/sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001

until curl -s "$KONG_URL/status" >/dev/null; do sleep 2; done

if ! curl -s "$KONG_URL/plugins" | grep -q '"name":"rate-limiting"'; then
  curl -s -X POST "$KONG_URL/plugins" -H "Content-Type: application/json" \
    -d '{"name":"rate-limiting","config":{"minute":60,"policy":"local","limit_by":"ip"}}'
fi

curl -s -X POST "$KONG_URL/consumers" \
     -H "Content-Type: application/json" \
     -d '{"username":"oidcuser","custom_id":"oidcuser"}'

curl -s -X POST "$KONG_URL/services" \
     -H "Content-Type: application/json" \
     -d '{"name":"pgadmin","url":"http://pgadmin:80"}'

curl -s -X POST "$KONG_URL/routes" \
     -H "Content-Type: application/json" \
     -d '{"service":{"name":"pgadmin"},"hosts":["pgadmin.'${DOMAIN}'"]}'

curl -s -X POST "$KONG_URL/plugins" \
     -H "Content-Type: application/json" \
     -d '{
           "name":"oidcify",
           "service":{"name":"pgadmin"},
           "config":{
             "issuer":"https://keycloak.'${DOMAIN}'/realms/mindfield",
             "client_id":"'"$CLIENT_ID_PGADMIN"'",
             "client_secret":"'"$CLIENT_SECRET_PGADMIN"'",
             "redirect_uri":"https://pgadmin.'${DOMAIN}'/callback",
	     "consumer_name":"oidcuser",
             "scopes":["openid","email","profile"],
	     "session":{
               "strategy":"cookie",
               "cookie_name":"pgadmin_session",
               "cookie_hash_key_hex":"'"$(openssl rand -hex 32)"'",
               "cookie_block_key_hex":"'"$(openssl rand -hex 32)"'"
             }
           }
         }'

