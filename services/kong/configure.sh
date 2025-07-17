#!/usr/bin/env sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001
until curl -fs "${KONG_URL}/status" >/dev/null; do sleep 5; done

################################################################################

curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{"name":"rate-limiting", "config":{"minute":6000,"policy":"local","limit_by":"ip"}}'

curl -fs -X PUT "${KONG_URL}/consumers/oidcuser" -H 'Content-Type: application/json' \
  -d '{"username":"oidcuser","custom_id":"oidcuser"}' >/dev/null

################################################################################

ROOT_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/root" \
  -H 'Content-Type: application/json' \
  -d '{"name":"root","host":"kong","port":8000,"protocol":"http"}')
ROOT_SERVICE_ID=$(echo "${ROOT_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/root-route" -H 'Content-Type: application/json' \
  -d '{"name":"root-route",
     "hosts":["'"${DOMAIN}"'"],
     "paths":["/"],"strip_path":false,
     "service":{"id":"'"${ROOT_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
     "name":"oidcify",
     "service":{"id":"'"${ROOT_SERVICE_ID}"'"},
     "config":{
       "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
       "client_id":"'"${CLIENT_ID_ROOT}"'",
       "client_secret":"'"${CLIENT_SECRET_ROOT}"'",
       "redirect_uri":"https://'"${DOMAIN}"'/callback",
       "consumer_name":"oidcuser",
       "scopes":["openid","email","profile"],
       "cookie_name":"root_session",
       "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_ROOT}"'",
       "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_ROOT}"'"
     }
     }' | jq '.name, .service.id'

################################################################################

PGADMIN_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/pgadmin" \
  -H 'Content-Type: application/json' \
  -d '{"name":"pgadmin","host":"pgadmin","port":80,"protocol":"http"}')
PGADMIN_SERVICE_ID=$(echo "${PGADMIN_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/pgadmin-route" -H 'Content-Type: application/json' \
  -d '{"name":"pgadmin-route",
     "hosts":["pgadmin.'"${DOMAIN}"'"],
     "service":{"id":"'"${PGADMIN_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
     "name":"oidcify",
     "service":{"id":"'"${PGADMIN_SERVICE_ID}"'"},
     "config":{
       "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
       "client_id":"'"${CLIENT_ID_PGADMIN}"'",
       "client_secret":"'"${CLIENT_SECRET_PGADMIN}"'",
       "redirect_uri":"https://pgadmin.'"${DOMAIN}"'/callback",
       "consumer_name":"oidcuser",
       "scopes":["openid","email","profile"],
       "cookie_name":"pgadmin_session",
       "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_PGADMIN}"'",
       "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_PGADMIN}"'"
     }
     }' | jq '.name, .service.id'

################################################################################

MAILHOG_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/mailhog" \
  -H 'Content-Type: application/json' \
  -d '{"name":"mailhog","host":"mailhog","port":8025,"protocol":"http"}')
MAILHOG_SERVICE_ID=$(echo "${MAILHOG_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/mailhog-route" -H 'Content-Type: application/json' \
  -d '{"name":"mailhog-route",
       "hosts":["mailhog.'"${DOMAIN}"'"],
       "service":{"id":"'"${MAILHOG_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
        "name":"oidcify",
        "service":{"id":"'"${MAILHOG_SERVICE_ID}"'"},
        "config":{
          "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
          "client_id":"'"${CLIENT_ID_MAILHOG}"'",
          "client_secret":"'"${CLIENT_SECRET_MAILHOG}"'",
          "redirect_uri":"https://mailhog.'"${DOMAIN}"'/callback",
          "consumer_name":"oidcuser",
          "scopes":["openid","email","profile"],
          "cookie_name":"mailhog_session",
          "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_MAILHOG}"'",
          "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_MAILHOG}"'"
        }
      }' | jq '.name, .service.id'

################################################################################

REDIS_INSIGHT_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/redis-insight" \
  -H 'Content-Type: application/json' \
  -d '{"name":"redis-insight","host":"redis-insight","port":5540,"protocol":"http"}')
REDIS_INSIGHT_SERVICE_ID=$(echo "${REDIS_INSIGHT_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/redis-insight-route" -H 'Content-Type: application/json' \
  -d '{"name":"redis-insight-route",
       "hosts":["redis-insight.'"${DOMAIN}"'"],
       "service":{"id":"'"${REDIS_INSIGHT_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
        "name":"oidcify",
        "service":{"id":"'"${REDIS_INSIGHT_SERVICE_ID}"'"},
        "config":{
          "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
          "client_id":"'"${CLIENT_ID_REDIS_INSIGHT}"'",
          "client_secret":"'"${CLIENT_SECRET_REDIS_INSIGHT}"'",
          "redirect_uri":"https://redis-insight.'"${DOMAIN}"'/callback",
          "consumer_name":"oidcuser",
          "scopes":["openid","email","profile"],
          "cookie_name":"redis-insight",
          "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_REDIS_INSIGHT}"'",
          "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_REDIS_INSIGHT}"'"
        }
      }' | jq '.name, .service.id'

################################################################################
