#!/usr/bin/env bash
set -euo pipefail
METALLB_RANGE="192.168.1.240-192.168.1.250"
IMAGE_NAME="localhost:32000/kong-oidc"
IMAGE_TAG="3.7.0"

microk8s enable metallb:${METALLB_RANGE}
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile.kong .
docker push ${IMAGE_NAME}:${IMAGE_TAG}
microk8s helm repo add kong https://charts.konghq.com || true
microk8s helm repo update
microk8s helm show crds kong/kong | kubectl apply -f -
for c in $(kubectl get crd | awk '/konghq.com/ {print $1}'); do
  kubectl label crd "$c" app.kubernetes.io/managed-by=Helm --overwrite
  kubectl annotate crd "$c" meta.helm.sh/release-name=kong meta.helm.sh/release-namespace=default --overwrite
done

microk8s helm upgrade --install kong kong/kong \
  --skip-crds \
  --set ingressController.enabled=true \
  --set ingressController.env.KONGHQ_COM_GLOBAL_PLUGINS=true \
  --set image.repository="${IMAGE_NAME}" \
  --set image.tag="${IMAGE_TAG}" \
  --set proxy.type=LoadBalancer \
  --set admin.enabled=true \
  --set admin.http.enabled=true \
  --set env.database=postgres \
  --set env.pg_host=pg-cluster-rw.default.svc.cluster.local \
  --set env.pg_user=kong \
  --set env.pg_password=kong \
  --set env.pg_database=kong \
  --set env.redis_host=redis-master.default.svc.cluster.local \
  --set env.redis_port=6379 \
  --set-string env.plugins="bundled\,oidcify\,cors\,rate-limiting\,ip-restriction" \
  --set env.pluginserver_names=oidcify \
  --set env.pluginserver_oidcify_start_cmd="/usr/local/bin/oidcify -kong-prefix /kong_prefix" \
  --set env.pluginserver_oidcify_query_cmd="/usr/local/bin/oidcify -dump"

microk8s kubectl -n default rollout status deployment/kong-kong --timeout=300s

cat <<'EOF' | microk8s kubectl apply -f -
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: oidcify-global
  labels:
    global: "true"
  annotations:
    kubernetes.io/ingress.class: kong
plugin: oidcify
config:
  issuer: "http://keycloak.default.svc.cluster.local/realms/master"
  client_id: kong
  client_secret: kong-secret
  insecure_skip_verify: true
  redirect_uri: "http://192.168.1.240/callback"
  consumer_name: "oidc-user"
---
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: rate-limit-global
  labels:
    global: "true"
  annotations:
    kubernetes.io/ingress.class: kong
plugin: rate-limiting
config:
  policy: redis
  redis_host: redis-master.default.svc.cluster.local
  redis_port: 6379
  second: 10
  limit_by: consumer
---
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: oidc-consumer
username: oidc-user
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: catch-all-ingress
  annotations:
    kubernetes.io/ingress.class: kong
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes
            port:
              number: 443
EOF
