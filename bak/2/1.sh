#!/usr/bin/env bash
set -xeuo pipefail
rm -fr ~/.kube
mkdir -p ~/.kube
sudo sysctl -w vm.max_map_count=262144
sudo sysctl -w fs.file-max=65536
sudo microk8s reset
sudo microk8s status --wait-ready
sudo microk8s enable dns
sudo microk8s enable hostpath-storage
sudo microk8s enable registry
sudo microk8s enable rbac
sudo microk8s enable helm3
sudo microk8s enable metrics-server
sudo microk8s enable metallb:192.168.1.129-192.168.1.254
#microk8s config > ~/.kube/config
# --- config: env overrides ----------------------------------------------------
: "${EXTSEC_SA_NAME:=external-secrets}"
: "${EXTSEC_SA_NS:=external-secrets-system}"
: "${POSTGRES_NS:=data}"
: "${POSTGRES_STS:=statefulset/postgresql}"
: "${PGBOUNCER_HOST:=pgbouncer.data.svc.cluster.local}"
: "${PGBOUNCER_PORT:=6432}"
: "${TEMPO_OTLP_HTTP:=http://tempo.observability.svc.cluster.local:4318}"
# Optional GitLab Runner registration. Leave empty to skip registration.
: "${GITLAB_RUNNER_URL:=}"
: "${GITLAB_RUNNER_REGISTRATION_TOKEN:=}"
# Namespaces used by the stack
NAMESPACES=("apps" "auth" "ci" "data" "docs" "gateway" "messaging" "observability" "temporal" "external-secrets-system" "cert-manager")
# --- helpers ------------------------------------------------------------------
log() { printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\n[%s] WARNING: %s\n' "$(date +%H:%M:%S)" "$*"; }
wait_api() {
  for i in {1..120}; do
    if microk8s kubectl get --raw=/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  microk8s kubectl get --raw=/readyz || true
  return 1
}
apply_yaml() {
  if ! microk8s kubectl apply -f - >/dev/null 2>&1; then
    microk8s kubectl apply --validate=false -f -
  fi
}
wait_crd() {
  local crd="$1" to="${2:-120s}"
  microk8s kubectl wait --for=condition=Established "crd/$crd" --timeout="$to" >/dev/null 2>&1 || true
}
wait_rollout() {
  local ns="$1" kind="$2" name="$3" to="${4:-180s}"
  microk8s kubectl -n "$ns" rollout status "$kind/$name" --timeout="$to" >/dev/null 2>&1 || true
}
ns() {
  local name="$1"
  microk8s kubectl create ns "$name" --dry-run=client -o yaml | microk8s kubectl apply -f - >/dev/null
}
label_psa() {
  for n in "$@"; do
    microk8s kubectl label ns "$n" \
      pod-security.kubernetes.io/enforce=baseline \
      pod-security.kubernetes.io/warn=restricted \
      pod-security.kubernetes.io/audit=restricted \
      pod-security.kubernetes.io/enforce-version=latest \
      --overwrite >/dev/null
  done
}
gen_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n'
  else
    head -c 32 /dev/urandom | base64 | tr -d '\n'
  fi
}
get_secret_val() {
  local ns="$1" name="$2" key="$3"
  microk8s kubectl get secret -n "$ns" "$name" -o "jsonpath={.data.$key}" 2>/dev/null | base64 -d || true
}
helm_up() {
  local ns="$1" rel="$2" chart="$3"
  shift 3
  if microk8s helm3 -n "$ns" status "$rel" >/dev/null 2>&1; then
    microk8s helm3 upgrade --install "$rel" "$chart" -n "$ns" --reuse-values "$@"
  else
    microk8s helm3 upgrade --install "$rel" "$chart" -n "$ns" "$@"
  fi
}
wait_for_selector() {
  local ns="$1" selector="$2" timeout="${3:-180s}"
  microk8s kubectl wait --for=condition=Ready -n "$ns" pod -l "$selector" --timeout="$timeout" || true
}
ensure_tls_secret() {
  # Create a self-signed edge-cert in gateway if missing, so Kong and mirrors have a secret.
  if ! microk8s kubectl -n gateway get secret edge-cert >/dev/null 2>&1; then
    log "Creating self-signed TLS secret gateway/edge-cert (placeholder)"
    local tmpdir
    tmpdir="$(mktemp -d)"
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "${tmpdir}/tls.key" -out "${tmpdir}/tls.crt" \
      -subj "/CN=example.com/O=example" >/dev/null 2>&1
    microk8s kubectl -n gateway create secret tls edge-cert \
      --cert="${tmpdir}/tls.crt" --key="${tmpdir}/tls.key"
    rm -rf "${tmpdir}"
  fi
}
log "Waiting for Kubernetes API to be ready"
wait_api
# --- namespaces and PSA -------------------------------------------------------
log "Ensuring namespaces exist"
for n in "${NAMESPACES[@]}"; do ns "$n"; done
log "Applying PSA baseline across app namespaces"
label_psa "${NAMESPACES[@]}"
# --- microk8s helm3 repositories --------------------------------------------------------
log "Adding Helm repositories (full set)"
microk8s helm3 repo add akhq https://akhq.io >/dev/null
microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami >/dev/null
microk8s helm3 repo add codecentric https://codecentric.github.io/helm-charts >/dev/null
microk8s helm3 repo add external-secrets https://charts.external-secrets.io >/dev/null
microk8s helm3 repo add gitlab https://charts.gitlab.io >/dev/null
microk8s helm3 repo add grafana https://grafana.github.io/helm-charts >/dev/null
microk8s helm3 repo add jetstack https://charts.jetstack.io >/dev/null
microk8s helm3 repo add kong https://charts.konghq.com >/dev/null
microk8s helm3 repo add nats https://nats-io.github.io/k8s/helm/charts >/dev/null
microk8s helm3 repo add netdata https://netdata.github.io/helmchart >/dev/null
microk8s helm3 repo add opensearch https://opensearch-project.github.io/helm-charts >/dev/null
microk8s helm3 repo add opentelemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
microk8s helm3 repo add ot-helm https://ot-container-kit.github.io/helm-charts >/dev/null
microk8s helm3 repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
microk8s helm3 repo add redisinsight https://raw.githubusercontent.com/hansehe/redisinsight-helm/master/helm/charts >/dev/null
microk8s helm3 repo add runix https://helm.runix.net >/dev/null
microk8s helm3 repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube >/dev/null
microk8s helm3 repo add strimzi https://strimzi.io/charts/ >/dev/null
microk8s helm3 repo add temporal https://go.temporal.io/helm-charts >/dev/null
microk8s helm3 repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts >/dev/null
microk8s helm3 repo add icoretech https://icoretech.github.io/helm >/dev/null
microk8s helm3 repo update >/dev/null
# --- cert-manager (optional) --------------------------------------------------
# Installing cert-manager in case you later switch to DNS-01.
log "Installing cert-manager (CRDs)"
ns cert-manager
label_psa cert-manager
helm_up cert-manager cert-manager jetstack/cert-manager --set crds.enabled=true
wait_crd certificates.cert-manager.io 180s
wait_crd issuers.cert-manager.io 180s
wait_crd clusterissuers.cert-manager.io 180s
wait_rollout cert-manager deploy cert-manager 300s
wait_rollout cert-manager deploy cert-manager-webhook 300s
wait_rollout cert-manager deploy cert-manager-cainjector 300s
# --- external-secrets operator ------------------------------------------------
log "Installing External Secrets Operator"
ns external-secrets-system
label_psa external-secrets-system
microk8s kubectl delete clusterrole external-secrets-cert-controller        --ignore-not-found
helm_up external-secrets-system external-secrets external-secrets/external-secrets --set installCRDs=true
wait_crd clustersecretstores.external-secrets.io 180s
wait_crd externalsecrets.external-secrets.io 180s
wait_rollout external-secrets-system deploy external-secrets 300s
wait_rollout external-secrets-system deploy external-secrets-webhook 300s
wait_rollout external-secrets-system deploy external-secrets-cert-controller 300s
# --- edge TLS secret and mirrors ---------------------------------------------
log "Ensuring gateway/edge-cert TLS secret exists"
ensure_tls_secret
log "Creating ClusterSecretStore to read from gateway namespace"
microk8s kubectl wait --for=condition=established crd clustersecretstores.external-secrets.io --timeout=60s
wait_crd clustersecretstores.external-secrets.io 180s
CA_BUNDLE=$(base64 -w0 /var/snap/microk8s/current/certs/ca.crt)
apply_yaml <<EOF
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: k8s-gateway-secrets
spec:
  provider:
    kubernetes:
      remoteNamespace: gateway
      server:
        caBundle: "${CA_BUNDLE}"
      auth:
        serviceAccount:
          name: ${EXTSEC_SA_NAME}
          namespace: ${EXTSEC_SA_NS}
EOF
mirror_edge() {
  local target_ns="$1"
  wait_crd externalsecrets.external-secrets.io 180s
  wait_rollout external-secrets-system deploy external-secrets-webhook 300s
  apply_yaml <<YAML
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: edge-cert
  namespace: ${target_ns}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: k8s-gateway-secrets
  target:
    name: edge-cert
    template:
      type: kubernetes.io/tls
  data:
    - secretKey: tls.crt
      remoteRef:
        key: edge-cert
        property: tls.crt
    - secretKey: tls.key
      remoteRef:
        key: edge-cert
        property: tls.key
YAML
}
for n in auth ci apps data messaging observability temporal; do ns "$n"; done
label_psa auth ci apps data messaging observability temporal
log "Mirroring edge-cert to namespaces"
microk8s kubectl wait --for=condition=established crd externalsecrets.external-secrets.io --timeout=60s || true
for n in auth ci apps data messaging observability temporal; do mirror_edge "$n"; done
# --- Postgres and PgBouncer ---------------------------------------------------
log "Installing PostgreSQL (Bitnami) in data namespace"
# Note: For idempotency, do not set explicit passwords here; chart will create secrets.
helm_up data postgresql bitnami/postgresql \
  --set auth.enablePostgresUser=true \
  --set primary.persistence.size=8Gi \
  --set primary.persistence.storageClass=microk8s-hostpath
log "Installing PgBouncer (icoretech) in data namespace"
PB_ADMIN_PASS="$(gen_password)"
helm_up data pgbouncer icoretech/pgbouncer \
   --set replicaCount=1 \
   --set service.type=ClusterIP \
   --set service.port=6432 \
   --set podSecurityContext.runAsNonRoot=true \
   --set podSecurityContext.fsGroup=1001 \
   --set containerSecurityContext.runAsUser=1001 \
   --set containerSecurityContext.allowPrivilegeEscalation=false \
   --set containerSecurityContext.capabilities.drop="{ALL}" \
   --set containerSecurityContext.seccompProfile.type=RuntimeDefault \
   --set config.adminPassword="${PB_ADMIN_PASS}"
# --- Keycloak with aligned DB password ---------------------------------------
log "Ensuring Keycloak DB password secret and DB alignment"
KC_SECRET_NS="auth"
KC_SECRET_NAME="keycloak-externaldb"
KC_SECRET_KEY="db-password"
KC_PASS="$(get_secret_val "$KC_SECRET_NS" "$KC_SECRET_NAME" "$KC_SECRET_KEY")"
if [ -z "$KC_PASS" ]; then
  KC_PASS="$(gen_password)"
  apply_yaml <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${KC_SECRET_NAME}
  namespace: ${KC_SECRET_NS}
type: Opaque
stringData:
  ${KC_SECRET_KEY}: ${KC_PASS}
YAML
fi
# Ensure Helm-ownership labels/annotations so the Bitnami chart can adopt it
microk8s kubectl -n "${KC_SECRET_NS}" annotate secret "${KC_SECRET_NAME}" \
  meta.helm.sh/release-name=keycloak \
  meta.helm.sh/release-namespace=auth \
  --overwrite
microk8s kubectl -n "${KC_SECRET_NS}" label secret "${KC_SECRET_NAME}" \
  app.kubernetes.io/managed-by=Helm \
  --overwrite
# Fetch Bitnami Postgres superuser password (key: postgres-password)
POSTGRES_SECRET="$(microk8s kubectl get secret -n "${POSTGRES_NS}" \
  -l app.kubernetes.io/instance=postgresql \
  -o jsonpath='{.items[0].metadata.name}')"
POSTGRES_PASSWORD="$(microk8s kubectl get secret -n "${POSTGRES_NS}" "${POSTGRES_SECRET}" \
  -o jsonpath='{.data.postgres-password}' | base64 -d)"
# Align DB (retry loop to wait for postgres availability)
set +e
for i in {1..20}; do
  microk8s kubectl -n "${POSTGRES_NS}" exec "${POSTGRES_STS}" -- bash -lc "
    set -e
    export PGPASSWORD='${POSTGRES_PASSWORD}'
    /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='keycloak'\" | grep -q 1 || \
    /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE DATABASE keycloak OWNER postgres;\"
    /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='keycloak'\" | grep -q 1 || \
    /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE USER keycloak WITH LOGIN;\"
    /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;\"
    /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"ALTER USER keycloak WITH PASSWORD '${KC_PASS}';\"
  " && break
  sleep 6
done
set -e
# --- Keycloak (direct Postgres) ----------------------------------------------
log "Installing Keycloak (Bitnami) using direct Postgres backend"
POSTGRES_HOST="postgresql.data.svc.cluster.local"
POSTGRES_PORT=5432
helm_up auth keycloak bitnami/keycloak \
  --set postgresql.enabled=false \
  --set externalDatabase.host="${POSTGRES_HOST}" \
  --set externalDatabase.port="${POSTGRES_PORT}" \
  --set externalDatabase.user="keycloak" \
  --set externalDatabase.password="${KC_PASS}" \
  --set externalDatabase.database="keycloak" \
  --set proxy=edge \
  --set proxyAddressForwarding=true
# --- Kong Gateway -------------------------------------------------------------
log "Installing Kong Ingress/Gateway"
helm_up gateway kong kong/kong \
  --set manager.enabled=true \
  --set portal.enabled=false \
  --set portalapi.enabled=false \
  --set env.router_flavor=traditional_compatible \
  --set ingressController.enabled=true \
  --set admin.enabled=true \
  --set admin.http.enabled=false \
  --set admin.tls.enabled=true \
  --set proxy.tls.enabled=true \
  --set proxy.tls.secretName=edge-cert
# --- Observability stack ------------------------------------------------------
log "Installing kube-prometheus-stack (Grafana fsGroup workaround)"
helm_up observability kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --set grafana.adminPassword=admin \
  --set grafana.initChownData.enabled=false \
  --set grafana.securityContext.runAsUser=472 \
  --set grafana.securityContext.runAsGroup=472 \
  --set grafana.podSecurityContext.fsGroup=472 \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=microk8s-hostpath
log "Installing Loki with structured metadata disabled (boltdb-shipper) and explicit schema_config"
helm_up observability loki grafana/loki \
  --namespace observability \
  --version 6.33.0 \
  --set loki.limits_config.allow_structured_metadata=false \
  -f - <<'EOF'
deploymentMode: SingleBinary
singleBinary: 
  replicas: 1 
  persistence:
    enabled: true
    size: 50Gi
    storageClass: microk8s-hostpath
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2025-01-01"
        store: boltdb-shipper
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h
  storageConfig:
    boltdb_shipper:
      active_index_directory: /var/loki/index
      cache_location: /var/loki/boltdb-cache
      shared_store: filesystem
    filesystem:
      directory: /var/loki/chunks
  ruler:
    storage:
      type: local
      local:
        directory: /var/loki/rules
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
gateway:
  enabled: false
EOF
log "Installing Tempo"
helm_up observability tempo grafana/tempo \
  --set tempo.storage.trace.backend=local \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=microk8s-hostpath \
  --set server.http_listen_port=3200 \
  --set tempo.search.enabled=true
microk8s helm upgrade --install opentelemetry-collector opentelemetry/opentelemetry-collector \
  -n observability --create-namespace \
  --version 0.97.1 \
  --set image.repository=otel/opentelemetry-collector-k8s \
  --set image.tag=0.104.0 \
  --set mode=daemonset \
  -f - <<'OTEL'
hostNetwork: false
ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
    hostPort: null
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    hostPort: null
  jaeger-grpc:
    enabled: true
    containerPort: 14250
    servicePort: 14250
    hostPort: null
  jaeger-thrift-http:
    enabled: true
    containerPort: 14268
    servicePort: 14268
    hostPort: null
  jaeger-compact:
    enabled: true
    containerPort: 6831
    servicePort: 6831
    hostPort: null
  zipkin:
    enabled: false
service:
  enabled: true
  type: ClusterIP
  annotations: {}
  labels: {}
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
    - name: otlp-http
      port: 4318
      targetPort: 4318
    - name: jaeger-grpc
      port: 14250
      targetPort: 14250
    - name: jaeger-thrift
      port: 14268
      targetPort: 14268
    - name: jaeger-compact
      port: 6831
      targetPort: 6831
config:
  receivers:
    otlp:
      protocols:
        grpc: {}
        http: {}
    jaeger:
      protocols:
        grpc: {}
        thrift_http: {}
        compact: {}
  processors:
    batch: {}
  exporters:
    otlphttp/tempo:
      endpoint: ${TEMPO_OTLP_HTTP}
      tls:
        insecure: true
    debug: {}
  service:
    pipelines:
      traces:
        receivers: [otlp, jaeger]
        processors: [batch]
        exporters: [otlphttp/tempo, debug]
      logs:
        receivers: [otlp]
        processors: [batch]
        exporters: [debug]
OTEL
# --- Temporal (SQL only; ES/Cassandra disabled; Web exposed) ------------------
log "Installing Temporal (SQL driver, pinned chart, Web enabled)"
# Postgres superuser password (Bitnami secret)
TEMP_PG_SECRET="$(microk8s kubectl get secret -n "${POSTGRES_NS}" \
  -l app.kubernetes.io/instance=postgresql \
  -o jsonpath='{.items[0].metadata.name}')"
TEMP_SUPER_PW="$(microk8s kubectl get secret -n "${POSTGRES_NS}" "${TEMP_PG_SECRET}" \
  -o jsonpath='{.data.postgres-password}' | base64 -d)"
# Desired Temporal SQL creds (set once; change if you prefer)
TEMP_DEF_DB="temporal"
TEMP_DEF_USER="temporal"
TEMP_DEF_PASS="temporal_pwd"
TEMP_VIS_DB="temporal_visibility"
TEMP_VIS_USER="temporal_visibility"
TEMP_VIS_PASS="temporal_vis_pwd"
# Ensure DBs and users exist in PostgreSQL (direct, not via PgBouncer)
set +e
microk8s kubectl -n "${POSTGRES_NS}" exec "${POSTGRES_STS}" -- bash -lc "
  set -e
  export PGPASSWORD='${TEMP_SUPER_PW}'
  /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='${TEMP_DEF_DB}'\" | grep -q 1 || \
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE DATABASE ${TEMP_DEF_DB};\"
  /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${TEMP_DEF_USER}'\" | grep -q 1 || \
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE USER ${TEMP_DEF_USER} WITH LOGIN PASSWORD '${TEMP_DEF_PASS}';\"
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"GRANT ALL PRIVILEGES ON DATABASE ${TEMP_DEF_DB} TO ${TEMP_DEF_USER};\"
  /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='${TEMP_VIS_DB}'\" | grep -q 1 || \
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE DATABASE ${TEMP_VIS_DB};\"
  /opt/bitnami/postgresql/bin/psql -U postgres -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${TEMP_VIS_USER}'\" | grep -q 1 || \
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"CREATE USER ${TEMP_VIS_USER} WITH LOGIN PASSWORD '${TEMP_VIS_PASS}';\"
  /opt/bitnami/postgresql/bin/psql -U postgres -v ON_ERROR_STOP=1 -c \"GRANT ALL PRIVILEGES ON DATABASE ${TEMP_VIS_DB} TO ${TEMP_VIS_USER};\"
"
set -e
# Helm install (version that works with SQL driver flags)
microk8s helm3 upgrade --install temporal temporal/temporal \
  --namespace temporal \
  --version 0.64.0 \
  --set server.config.persistence.default.driver=sql \
  --set server.config.persistence.default.sql.driver=postgres \
  --set server.config.persistence.default.sql.host=postgresql.data.svc.cluster.local \
  --set server.config.persistence.default.sql.port=5432 \
  --set server.config.persistence.default.sql.database="${TEMP_DEF_DB}" \
  --set server.config.persistence.default.sql.user="${TEMP_DEF_USER}" \
  --set server.config.persistence.default.sql.password="${TEMP_DEF_PASS}" \
  --set server.config.persistence.visibility.driver=sql \
  --set server.config.persistence.visibility.sql.driver=postgres \
  --set server.config.persistence.visibility.sql.host=postgresql.data.svc.cluster.local \
  --set server.config.persistence.visibility.sql.port=5432 \
  --set server.config.persistence.visibility.sql.database="${TEMP_VIS_DB}" \
  --set server.config.persistence.visibility.sql.user="${TEMP_VIS_USER}" \
  --set server.config.persistence.visibility.sql.password="${TEMP_VIS_PASS}" \
  --set web.enabled=true
# Ensure Gateway API CRDs for HTTPRoute v1
if ! microk8s kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
  log "Installing Gateway API CRDs (v1)"
  microk8s kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
  microk8s kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=120s
fi
log "Creating HTTPRoute for Temporal Web UI"
microk8s kubectl apply -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: temporal-web
  namespace: temporal
spec:
  parentRefs:
    - name: edge
      namespace: gateway
  hostnames:
    - temporal.aldous.info
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: temporal-web
          port: 8080
EOF
# --- Messaging and data UIs (lightweight) ------------------------------------
log "Installing NATS (PSA friendly security contexts)"
helm_up messaging nats nats/nats \
  --set nats.replicas=1 \
  --set config.cluster.enabled=false \
  --set podTemplate.securityContext.runAsNonRoot=true \
  --set podTemplate.securityContext.seccompProfile.type=RuntimeDefault \
  --set container.env[0].name="TZ" \
  --set container.env[0].value="UTC" \
  --set nats.securityContext.runAsNonRoot=true \
  --set nats.securityContext.allowPrivilegeEscalation=false \
  --set nats.securityContext.capabilities.drop="{ALL}"
log "Installing Mailhog"
helm_up apps mailhog codecentric/mailhog \
  --set service.type=ClusterIP \
  --set containerSecurityContext.runAsNonRoot=true \
  --set containerSecurityContext.allowPrivilegeEscalation=false \
  --set containerSecurityContext.capabilities.drop="{ALL}" \
  --set podSecurityContext.runAsUser=1001 \
  --set podSecurityContext.fsGroup=1001
log "Installing Redis (Bitnami) and RedisInsight UI"
helm_up data redis bitnami/redis \
  --set architecture=standalone \
  --set master.persistence.storageClass=microk8s-hostpath \
  --set master.persistence.size=5Gi \
  --set auth.enabled=false
helm_up data redisinsight redisinsight/redisinsight \
  --set image.tag=2.50.0 \
  --set service.type=ClusterIP \
  --set persistence.enabled=true \
  --set persistence.size=2Gi \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.runAsUser=1000 \
  --set podSecurityContext.fsGroup=1000 \
  --set containerSecurityContext.runAsNonRoot=true \
  --set containerSecurityContext.runAsUser=1000 \
  --set containerSecurityContext.allowPrivilegeEscalation=false \
  --set containerSecurityContext.capabilities.drop={ALL} \
  --set containerSecurityContext.seccompProfile.type=RuntimeDefault
log "Installing pgAdmin4"
helm_up data pgadmin4 runix/pgadmin4 \
  --set env.email=admin@example.com \
  --set env.password=admin \
  --set persistence.enabled=true \
  --set persistence.storageClass=microk8s-hostpath \
  --set persistence.size=2Gi
log "Installing AKHQ (Kafka UI) with placeholder config"
helm_up messaging akhq akhq/akhq \
  --repo https://akhq.io \
  --set akhq.connections.local.properties.bootstrap.servers="kafka-kafka-bootstrap.messaging.svc.cluster.local:9092" \
  --set akhq.security.default-roles="{topic/read}" \
  --set akhq.server.servlet.context-path="/" \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.runAsUser=1000 \
  --set podSecurityContext.fsGroup=1000 \
  --set containerSecurityContext.runAsNonRoot=true \
  --set containerSecurityContext.runAsUser=1000 \
  --set containerSecurityContext.allowPrivilegeEscalation=false \
  --set "containerSecurityContext.capabilities.drop={ALL}" \
  --set containerSecurityContext.seccompProfile.type=RuntimeDefault
log "Installing Strimzi Kafka Operator (single node friendly)"
microk8s kubectl delete clusterrole strimzi-cluster-operator-namespaced    --ignore-not-found
helm_up messaging strimzi-kafka-operator strimzi/strimzi-kafka-operator --set watchAnyNamespace=true
# Minimal single-broker Kafka if not present
if ! microk8s kubectl -n messaging get kafka my-cluster >/dev/null 2>&1; then
  apply_yaml <<'KAFKA'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: messaging
spec:
  kafka:
    version: 3.7.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    storage:
      type: ephemeral
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
  zookeeper:
    replicas: 1
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
KAFKA
fi
# --- OpenSearch (single master, dashboards) -----------------------------------
log "Installing OpenSearch (single master) and Dashboards"
helm_up data opensearch opensearch/opensearch \
  --set replicas=1 \
  --set masterService="opensearch-cluster-master" \
  --set singleNode=true \
  --set persistence.enabled=true \
  --set persistence.size=10Gi \
  --set persistence.storageClass=microk8s-hostpath \
  --set resources.requests.cpu="100m" \
  --set resources.requests.memory="512Mi" \
  --set resources.limits.cpu="1000m" \
  --set resources.limits.memory="2Gi" \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.fsGroup=1000 \
  --set initSecurityContext.runAsNonRoot=true \
  --set initSecurityContext.runAsUser=1000 \
  --set initSecurityContext.fsGroup=1000 \
  --set initSecurityContext.allowPrivilegeEscalation=false \
  --set initSecurityContext.capabilities.drop={ALL} \
  --set initSecurityContext.seccompProfile.type=RuntimeDefault \
  --set securityContext.runAsNonRoot=true \
  --set securityContext.runAsUser=1000 \
  --set securityContext.fsGroup=1000 \
  --set securityContext.allowPrivilegeEscalation=false \
  --set securityContext.capabilities.drop={ALL} \
  --set securityContext.seccompProfile.type=RuntimeDefault
helm_up data opensearch-dashboards opensearch/opensearch-dashboards \
  --set replicas=1 \
  --set service.type=ClusterIP \
  --set opensearchHosts="http://opensearch-cluster-master.data.svc.cluster.local:9200" \
  --set podSecurityContext.runAsNonRoot=true \
  --set podSecurityContext.fsGroup=1000 \
  --set securityContext.runAsNonRoot=true \
  --set securityContext.runAsUser=1000 \
  --set securityContext.fsGroup=1000 \
  --set securityContext.allowPrivilegeEscalation=false \
  --set securityContext.capabilities.drop={ALL} \
  --set securityContext.seccompProfile.type=RuntimeDefault
# --- Netdata ------------------------------------------------------------------
log "Installing Netdata"
helm_up observability netdata netdata/netdata \
  --set parent.enabled=false \
  --set child.enabled=true \
  --set child.claiming.enabled=false \
  --set child.database.persistence.enabled=true \
  --set child.database.persistence.size=5Gi \
  --set child.database.persistence.storageClass=microk8s-hostpath
# --- GitLab Runner (optional, if token provided) ------------------------------
if [ -n "${GITLAB_RUNNER_URL}" ] && [ -n "${GITLAB_RUNNER_REGISTRATION_TOKEN}" ]; then
  log "Installing GitLab Runner"
  helm_up ci gitlab-runner gitlab/gitlab-runner \
    --set gitlabUrl="${GITLAB_RUNNER_URL}" \
    --set runnerRegistrationToken="${GITLAB_RUNNER_REGISTRATION_TOKEN}"
else
  log "Skipping GitLab Runner install (no registration token provided)"
fi
# --- waits (best-effort) ------------------------------------------------------
log "Best-effort waits for core components"
wait_for_selector auth "app.kubernetes.io/name=keycloak" 600s
wait_for_selector gateway "app.kubernetes.io/name=kong" 600s
wait_for_selector observability "app.kubernetes.io/name=grafana" 600s
wait_for_selector observability "app.kubernetes.io/name=loki" 600s
wait_for_selector observability "app.kubernetes.io/name=tempo" 600s
wait_for_selector observability "app.kubernetes.io/name=opentelemetry-collector" 600s
wait_for_selector temporal "app.kubernetes.io/name=temporal" 600s
wait_for_selector messaging "strimzi.io/kind=cluster-operator" 600s
wait_for_selector messaging "strimzi.io/name=my-cluster-kafka" 600s
wait_for_selector data "app.kubernetes.io/name=opensearch" 600s
# --- diagnostics --------------------------------------------------------------
log "Non-running pods summary"
set +e
microk8s kubectl get pods -A -o wide | awk 'NR==1 || ($4!="Running" && $4!="Completed")'
set -e
cat <<'NEXT'
Next steps:
- microk8s kubectl get events -A --sort-by=.lastTimestamp | tail -n 200
- Check Keycloak logs: microk8s kubectl logs -n auth statefulset/keycloak --tail=200
- Check Loki:        microk8s kubectl logs -n observability loki-0 -c loki --tail=200
- Check OTel:        microk8s kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --all-containers --tail=200
- Check Temporal:     microk8s kubectl get pods -n temporal
- Check Kong:         microk8s kubectl logs -n gateway -l app.kubernetes.io/name=kong --tail=200
If any component still CrashLoops or is Pending, share events and the specific pod logs for a targeted patch.
NEXT
log "Done"
