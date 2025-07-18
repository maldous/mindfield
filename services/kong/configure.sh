#!/usr/bin/env sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001
until curl -fs "${KONG_URL}/status" >/dev/null; do sleep 5; done

if curl -fs -X GET "${KONG_URL}/services/root" >/dev/null; then
  exit 0
fi

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

REDISINSIGHT_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/redisinsight" \
  -H 'Content-Type: application/json' \
  -d '{"name":"redisinsight","host":"redisinsight","port":5540,"protocol":"http"}')
REDISINSIGHT_SERVICE_ID=$(echo "${REDISINSIGHT_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/redisinsight-route" -H 'Content-Type: application/json' \
  -d '{"name":"redisinsight-route",
       "hosts":["redisinsight.'"${DOMAIN}"'"],
       "service":{"id":"'"${REDISINSIGHT_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
        "name":"oidcify",
        "service":{"id":"'"${REDISINSIGHT_SERVICE_ID}"'"},
        "config":{
          "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
          "client_id":"'"${CLIENT_ID_REDISINSIGHT}"'",
          "client_secret":"'"${CLIENT_SECRET_REDISINSIGHT}"'",
          "redirect_uri":"https://redisinsight.'"${DOMAIN}"'/callback",
          "consumer_name":"oidcuser",
          "scopes":["openid","email","profile"],
          "cookie_name":"redisinsight_session",
          "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_REDISINSIGHT}"'",
          "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_REDISINSIGHT}"'"
        }
      }' | jq '.name, .service.id'

################################################################################

MINIO_SERVICE_JSON=$(curl -fs -X PUT "${KONG_URL}/services/minio" \
  -H 'Content-Type: application/json' \
  -d '{"name":"minio","host":"minio","port":9001,"protocol":"http"}')
MINIO_SERVICE_ID=$(echo "${MINIO_SERVICE_JSON}" | jq -r '.id')
curl -fs -X PUT "${KONG_URL}/routes/minio-route" -H 'Content-Type: application/json' \
  -d '{"name":"minio-route",
       "hosts":["minio.'"${DOMAIN}"'"],
       "service":{"id":"'"${MINIO_SERVICE_ID}"'"}}' >/dev/null
curl -fs -X POST "${KONG_URL}/plugins" -H 'Content-Type: application/json' \
  -d '{
        "name":"oidcify",
        "service":{"id":"'"${MINIO_SERVICE_ID}"'"},
        "config":{
          "issuer":"https://keycloak.'"${DOMAIN}"'/realms/mindfield",
          "client_id":"'"${CLIENT_ID_MINIO}"'",
          "client_secret":"'"${CLIENT_SECRET_MINIO}"'",
          "redirect_uri":"https://minio.'"${DOMAIN}"'/callback",
          "consumer_name":"oidcuser",
          "scopes":["openid","email","profile"],
          "cookie_name":"minio_session",
          "cookie_hash_key_hex":"'"${KONG_COOKIE_HASH_MINIO}"'",
          "cookie_block_key_hex":"'"${KONG_COOKIE_BLOCK_MINIO}"'"
        }
      }' | jq '.name, .service.id'

################################################################################

echo "services/kong/configure.sh"
