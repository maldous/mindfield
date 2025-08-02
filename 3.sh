#!/usr/bin/env bash
set -euo pipefail
# METALLB_RANGE="192.168.1.240-192.168.1.250"
# microk8s enable metallb:${METALLB_RANGE}

IMAGE_NAME="localhost:32000/kong-oidc"
IMAGE_TAG="3.7.0-oidc"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile.kong .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
microk8s helm repo add kong https://charts.konghq.com || true
microk8s helm repo update
microk8s helm upgrade --install kong kong/kong \
  --skip-crds \
  --set ingressController.enabled=true \
  --set image.repository=${IMAGE_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set proxy.type=LoadBalancer \
  --set admin.enabled=true \
  --set admin.http.enabled=true \
  --set env.DATABASE=postgres \
  --set env.PG_HOST=pg-cluster-rw.default.svc.cluster.local \
  --set env.PG_USER=kong \
  --set env.PG_PASSWORD=kong \
  --set env.PG_DATABASE=kong \
  --set env.REDIS_HOST=redis-master.default.svc.cluster.local \
  --set env.REDIS_PORT=6379 \
  --set env.PLUGINS="bundled\,oidcify\,cors\,rate-limiting\,ip-restriction" \
  --set env.PLUGINSERVER_NAMES=oidcify \
  --set env.PLUGINSERVER_OIDCIFY_START_CMD="/usr/local/bin/oidcify -kong-prefix /usr/local/kong" \
  --set env.PLUGINSERVER_OIDCIFY_QUERY_CMD="/usr/local/bin/oidcify -dump"
microk8s kubectl -n default rollout status deployment/kong-kong --timeout=300s
cat <<'EOF' | microk8s kubectl apply -f -
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-redis
config:
  policy: redis
  redis_host: redis-master.default.svc.cluster.local
  redis_port: 6379
  second: 10
  limit_by: consumer
plugin: rate-limiting
---
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: keycloak-oidc-global
  labels:
    global: "true"
config:
  client_id: kong
  client_secret: kong-secret
  discovery: http://keycloak.default.svc.cluster.local/realms/master/.well-known/openid-configuration
  ssl_verify: false
plugin: oidcify
---
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: oidc-consumer
username: oidc-user
EOF
