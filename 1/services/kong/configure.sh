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
  -d "{
    \"name\":\"${svc}-route\",
    \"hosts\":[\"${fqdn}\"],
    \"methods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\"],
    \"preserve_host\":true,
    \"service\":{\"id\":\"${svc_id}\"}
  }"
  local plugin_cfg
  plugin_cfg="{\"issuer\":\"https://keycloak.${DOMAIN}/realms/${NAME}\",\
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
  -d "{
  \"name\":\"root-route\",
  \"hosts\":[\"${DOMAIN}\"],
  \"paths\":[\"/\"],
  \"strip_path\":false,
  \"methods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\"],
  \"preserve_host\":true,
  \"service\":{\"id\":\"${root_id}\"}
}"

root_cfg="{\"issuer\":\"https://keycloak.${DOMAIN}/realms/${NAME}\",\
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
create_stack blackbox blackbox 9115 "blackbox.${DOMAIN}" "${CLIENT_ID_BLACKBOX}" "${CLIENT_SECRET_BLACKBOX}" blackbox "${KONG_COOKIE_HASH_BLACKBOX}" "${KONG_COOKIE_BLOCK_BLACKBOX}"
create_stack grafana grafana 3000 "grafana.${DOMAIN}" "${CLIENT_ID_GRAFANA}" "${CLIENT_SECRET_GRAFANA}" grafana "${KONG_COOKIE_HASH_GRAFANA}" "${KONG_COOKIE_BLOCK_GRAFANA}"
create_stack jaeger jaeger 16686 "jaeger.${DOMAIN}" "${CLIENT_ID_JAEGER}" "${CLIENT_SECRET_JAEGER}" jaeger "${KONG_COOKIE_HASH_JAEGER}" "${KONG_COOKIE_BLOCK_JAEGER}"
create_stack kuma kuma 3001 "kuma.${DOMAIN}" "${CLIENT_ID_KUMA}" "${CLIENT_SECRET_KUMA}" kuma "${KONG_COOKIE_HASH_KUMA}" "${KONG_COOKIE_BLOCK_KUMA}"
create_stack promtail promtail 9080 "promtail.${DOMAIN}" "${CLIENT_ID_PROMTAIL}" "${CLIENT_SECRET_PROMTAIL}" promtail "${KONG_COOKIE_HASH_PROMTAIL}" "${KONG_COOKIE_BLOCK_PROMTAIL}"
create_stack search search 5601 "search.${DOMAIN}" "${CLIENT_ID_SEARCH}" "${CLIENT_SECRET_SEARCH}" search "${KONG_COOKIE_HASH_SEARCH}" "${KONG_COOKIE_BLOCK_SEARCH}"
create_stack sonarqube sonarqube 9000 "sonarqube.${DOMAIN}" "${CLIENT_ID_SONARQUBE}" "${CLIENT_SECRET_SONARQUBE}" sonarqube "${KONG_COOKIE_HASH_SONARQUBE}" "${KONG_COOKIE_BLOCK_SONARQUBE}"
create_stack docs docs 8005 "docs.${DOMAIN}" "${CLIENT_ID_DOCS}" "${CLIENT_SECRET_DOCS}" docs "${KONG_COOKIE_HASH_DOCS}" "${KONG_COOKIE_BLOCK_DOCS}"
create_stack postgraphile postgraphile 5002 "postgraphile.${DOMAIN}" "${CLIENT_ID_POSTGRAPHILE}" "${CLIENT_SECRET_POSTGRAPHILE}" postgraphile "${KONG_COOKIE_HASH_POSTGRAPHILE}" "${KONG_COOKIE_BLOCK_POSTGRAPHILE}"
create_stack gitlab gitlab 80 "gitlab.${DOMAIN}" "${CLIENT_ID_GITLAB}" "${CLIENT_SECRET_GITLAB}" gitlab "${KONG_COOKIE_HASH_GITLAB}" "${KONG_COOKIE_BLOCK_GITLAB}"
create_stack cadence cadence 8088 "cadence.${DOMAIN}" "${CLIENT_ID_CADENCE}" "${CLIENT_SECRET_CADENCE}" cadence "${KONG_COOKIE_HASH_CADENCE}" "${KONG_COOKIE_BLOCK_CADENCE}"
create_stack sentry sentry 9000 "sentry.${DOMAIN}" "${CLIENT_ID_SENTRY}" "${CLIENT_SECRET_SENTRY}" sentry "${KONG_COOKIE_HASH_SENTRY}" "${KONG_COOKIE_BLOCK_SENTRY}"
create_stack nui nui 31311 "nui.${DOMAIN}" "${CLIENT_ID_NUI}" "${CLIENT_SECRET_NUI}" nui "${KONG_COOKIE_HASH_NUI}" "${KONG_COOKIE_BLOCK_NUI}"
create_stack akhq akhq 8080 "akhq.${DOMAIN}" "${CLIENT_ID_AKHQ}" "${CLIENT_SECRET_AKHQ}" akhq "${KONG_COOKIE_HASH_AKHQ}" "${KONG_COOKIE_BLOCK_AKHQ}"
create_stack netdata netdata 19999 "netdata.${DOMAIN}" "${CLIENT_ID_NETDATA}" "${CLIENT_SECRET_NETDATA}" netdata "${KONG_COOKIE_HASH_NETDATA}" "${KONG_COOKIE_BLOCK_NETDATA}"
create_stack kong kong 8002 "kong.${DOMAIN}" "${CLIENT_ID_KONG}" "${CLIENT_SECRET_KONG}" kong "${KONG_COOKIE_HASH_KONG}" "${KONG_COOKIE_BLOCK_KONG}"

echo -e "\nservices/kong/configure.sh"
