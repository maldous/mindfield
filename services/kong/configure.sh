#!/usr/bin/env sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001

until curl -fs "${KONG_URL}/status" >/dev/null; do sleep 5; done

ensure_global_plugin() {
  local name=$1   
  local cfg=$2    
  if curl -fs "${KONG_URL}/plugins?name=${name}" | jq -e '.data|length>0' >/dev/null; then
    local pid
    pid=$(curl -fs "${KONG_URL}/plugins?name=${name}" | jq -r '.data[0].id')
    curl -fs -X PATCH "${KONG_URL}/plugins/${pid}" \
    -H 'Content-Type: application/json' \
    -d "{\"config\":${cfg}}"
  else
    curl -fs -X POST "${KONG_URL}/plugins" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"${name}\",\"config\":${cfg}}"
  fi
}

ensure_service_plugin() {
  local svc_id=$1   
  local cfg=$2      
  local pid
  pid=$(curl -fs "${KONG_URL}/services/${svc_id}/plugins" | jq -r '.data[]|select(.name=="oidcify")|.id' || true)
  if [ -z "${pid}" ]; then
    curl -fs -X POST "${KONG_URL}/services/${svc_id}/plugins" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"oidcify\",\"config\":${cfg}}"
  else
    curl -fs -X PATCH "${KONG_URL}/plugins/${pid}" \
    -H 'Content-Type: application/json' \
    -d "{\"config\":${cfg}}"
  fi
}

create_stack() {
  local svc="$1" host="$2" port="$3" fqdn="$4"
  local client_id="$5" client_secret="$6" cookie="$7" hash="$8" block="$9"
  local svc_json svc_id
  svc_json=$(curl -fs -X PUT "${KONG_URL}/services/${svc}" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"${svc}\",\"host\":\"${host}\",\"port\":${port},\"protocol\":\"http\"}")
  svc_id=$(echo "${svc_json}" | jq -r '.id')
  curl -fs -X PUT "${KONG_URL}/routes/${svc}-route" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"${svc}-route\",\"hosts\":[\"${fqdn}\"],\"service\":{\"id\":\"${svc_id}\"}}"
  local plugin_cfg
  plugin_cfg="{\"issuer\":\"https://keycloak.${DOMAIN}/realms/mindfield\",\
  \"client_id\":\"${client_id}\",\"client_secret\":\"${client_secret}\",\
  \"redirect_uri\":\"https://${fqdn}/callback\",\"consumer_name\":\"oidcuser\",\
  \"scopes\":[\"openid\",\"email\",\"profile\"],\
  \"cookie_name\":\"${cookie}_session\",\"cookie_hash_key_hex\":\"${hash}\",\
  \"cookie_block_key_hex\":\"${block}\"}"
  ensure_service_plugin "${svc_id}" "${plugin_cfg}"
}

ensure_global_plugin "rate-limiting" '{"minute":6000,"policy":"local","limit_by":"ip"}'

curl -fs -X PUT "${KONG_URL}/consumers/oidcuser" \
  -H 'Content-Type: application/json' \
  -d '{"username":"oidcuser","custom_id":"oidcuser"}'

root_svc_json=$(curl -fs -X PUT "${KONG_URL}/services/root" \
  -H 'Content-Type: application/json' \
  -d '{"name":"root","host":"kong","port":8000,"protocol":"http"}')

root_id=$(echo "${root_svc_json}" | jq -r '.id')

curl -fs -X PUT "${KONG_URL}/routes/root-route" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"root-route\",\"hosts\":[\"${DOMAIN}\"],\"paths\":[\"/\"],\
  \"strip_path\":false,\"service\":{\"id\":\"${root_id}\"}}"

root_cfg="{\"issuer\":\"https://keycloak.${DOMAIN}/realms/mindfield\",\
  \"client_id\":\"${CLIENT_ID_ROOT}\",\"client_secret\":\"${CLIENT_SECRET_ROOT}\",\
  \"redirect_uri\":\"https://${DOMAIN}/callback\",\"consumer_name\":\"oidcuser\",\
  \"scopes\":[\"openid\",\"email\",\"profile\"],\
  \"cookie_name\":\"root_session\",\"cookie_hash_key_hex\":\"${KONG_COOKIE_HASH_ROOT}\",\
  \"cookie_block_key_hex\":\"${KONG_COOKIE_BLOCK_ROOT}\"}"

ensure_service_plugin "${root_id}" "${root_cfg}"

create_stack pgadmin pgadmin 80 "pgadmin.${DOMAIN}" "${CLIENT_ID_PGADMIN}" "${CLIENT_SECRET_PGADMIN}" pgadmin "${KONG_COOKIE_HASH_PGADMIN}" "${KONG_COOKIE_BLOCK_PGADMIN}"
create_stack mailhog mailhog 8025 "mailhog.${DOMAIN}" "${CLIENT_ID_MAILHOG}" "${CLIENT_SECRET_MAILHOG}" mailhog "${KONG_COOKIE_HASH_MAILHOG}" "${KONG_COOKIE_BLOCK_MAILHOG}"
create_stack redisinsight redisinsight 5540 "redisinsight.${DOMAIN}" "${CLIENT_ID_REDISINSIGHT}" "${CLIENT_SECRET_REDISINSIGHT}" redisinsight "${KONG_COOKIE_HASH_REDISINSIGHT}" "${KONG_COOKIE_BLOCK_REDISINSIGHT}"
create_stack minio minio 9001 "minio.${DOMAIN}" "${CLIENT_ID_MINIO}" "${CLIENT_SECRET_MINIO}" minio "${KONG_COOKIE_HASH_MINIO}" "${KONG_COOKIE_BLOCK_MINIO}"
create_stack alertmanager alertmanager 9093 "alertmanager.${DOMAIN}" "${CLIENT_ID_ALERTMANAGER}" "${CLIENT_SECRET_ALERTMANAGER}" alertmanager "${KONG_COOKIE_HASH_ALERTMANAGER}" "${KONG_COOKIE_BLOCK_ALERTMANAGER}"

echo "services/kong/configure.sh"
