#!/usr/bin/env bash
set -euo pipefail
IMAGE_NAME="localhost:32000/kong-oidc"
IMAGE_TAG="3.7.0-oidc"
METALLB_RANGE="192.168.1.240-192.168.1.250"
microk8s enable metallb:${METALLB_RANGE}
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile.kong .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
microk8s helm repo add kong https://charts.konghq.com || true
microk8s helm repo update
microk8s helm upgrade --install kong kong/kong \
  --set ingressController.enabled=true \
  --set image.repository=${IMAGE_NAME} \
  --set image.tag=${IMAGE_TAG} \
  --set image.pullPolicy=IfNotPresent \
  --set proxy.type=LoadBalancer \
  --set admin.enabled=true \
  --set admin.http.enabled=true \
  --set env.KONG_DATABASE=off \
  --set env.KONG_LOG_LEVEL=info \
  --set env.KONG_PLUGINS="bundled\,oidcify"
microk8s kubectl -n default rollout status deployment/kong-kong --timeout=300s
