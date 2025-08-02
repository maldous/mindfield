# modules/kong/main.tf
# Kong chart pinned @ 2.51.0 :contentReference[oaicite:0]{index=0}
resource "helm_release" "kong" {
  name             = "kong"
  namespace        = "gateway"
  create_namespace = true

  repository = "https://charts.konghq.com"
  chart      = "kong"
  version    = "2.51.0"

  values = [file("${path.module}/values.yaml")]
}

# helm-values/kong-values.yaml
# ─── Kong Gateway on MetalLB single‑edge (LB IP 192.168.1.251) ───
# OIDC, rate‑limit, CORS, Prometheus
# chart 2.51.0 :contentReference[oaicite:1]{index=1}
image:
  repository: kong/kong-gateway
  tag: "3.7"

proxy:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.251
  annotations:
    metallb.universe.tf/address-pool: default
    external-dns.alpha.kubernetes.io/hostname: "*.aldous.info,aldous.info"

env:
  database: "off"
  KONG_LOG_LEVEL: "info"
  KONG_PLUGINS: "bundled,oidc,cors,rate-limiting,ip-restriction"
  KONG_ANONYMOUS_REPORTS: "off"

ingressController:
  enabled: true
  installCRDs: true
  gateway:
    enabled: true

admin:
  enabled: true
  tls:
    enabled: true

metrics:
  enabled: true
serviceMonitor:
  enabled: true

# modules/keycloak/main.tf
# Bitnami Keycloak chart pinned @ 24.8.1 :contentReference[oaicite:2]{index=2}
resource "helm_release" "keycloak" {
  name             = "keycloak"
  namespace        = "auth"
  create_namespace = true

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"
  version    = "24.8.1"

  values = [file("${path.module}/values.yaml")]
}

# helm-values/keycloak-values.yaml
# ─── Keycloak realm `prod` + external Postgres + ESO secrets ───
auth:
  existingSecret: keycloak-admin        # created by External Secrets
  usernameKey:  username
  passwordKey:  password

extraEnvVars:
  - name: KEYCLOAK_IMPORT
    value: "/realm/realm-prod.json"

extraVolumes:
  - name: realm-file
    configMap:
      name: kc-realm-prod
extraVolumeMounts:
  - name: realm-file
    mountPath: /realm

externalDatabase:
  host: postgres-rw.data.svc.cluster.local
  port: 5432
  user: keycloak
  database: keycloak
  existingSecret: keycloak-db-creds      # ESO‑managed

service:
  ports:
    http: 80
    https: 8443
proxy: edge

# auth/kc-realm-prod-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kc-realm-prod
  namespace: auth
data:
  realm-prod.json: |
    {
      "realm": "prod",
      "enabled": true,
      "clients": [
        {
          "clientId": "web",
          "protocol": "openid-connect",
          "publicClient": false,
          "redirectUris": ["https://aldous.info/*","https://*.aldous.info/*"],
          "serviceAccountsEnabled": true
        },
        {
          "clientId": "mobile",
          "protocol": "openid-connect",
          "publicClient": true,
          "standardFlowEnabled": true,
          "directAccessGrantsEnabled": true
        },
        {
          "clientId": "admin",
          "protocol": "openid-connect",
          "publicClient": false,
          "redirectUris": ["https://ops.aldous.info/*"]
        }
      ],
      "groups": [
        {"name": "admins"},
        {"name": "users"}
      ]
    }

# gateway/kong-gateway.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: kong
spec:
  controllerName: konghq.com/kic-gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: edge
  namespace: gateway
spec:
  gatewayClassName: kong
  listeners:
  - name: https
    hostname: "*.aldous.info"
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: edge-cert

# gateway/plugins.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: oidc
  namespace: gateway
  labels: {global: "true"}
config:
  issuer: https://auth.aldous.info/realms/prod
  client_id: web
  client_secret: "${WEB_CLIENT_SECRET}"
  scopes: openid,profile,email,offline_access
  session_secret: "${SESSION_SECRET}"
  redirect_uri_path: /_oauth
  cookie_path: /
  cookie_domain: aldous.info
  bearer_only: "no"
  session_cookie_secure: "true"
  session_cookie_httponly: "true"
  session_cookie_samesite: "lax"
plugin: oidc
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-1m
  namespace: gateway
config:
  minute: 60
  policy: local
plugin: rate-limiting
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: cors
  namespace: gateway
config:
  origins: "*"
  methods: "GET,POST,PUT,PATCH,DELETE,OPTIONS"
  headers: "Accept,Authorization,Content-Type,Origin"
  credentials: true
plugin: cors
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: ip-admin
  namespace: gateway
config:
  allow:
    - 192.168.0.0/16
plugin: ip-restriction

# routes/web.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: web
  namespace: apps
  annotations:
    konghq.com/plugins: oidc,rate-limit-1m,cors
spec:
  hostnames: ["aldous.info"]
  rules:
  - backendRefs:
    - name: web
      port: 80
---
# routes/grafana.yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: observability
  annotations:
    konghq.com/plugins: oidc,rate-limit-1m,cors
spec:
  hostnames: ["grafana.aldous.info"]
  rules:
  - backendRefs:
    - name: grafana
      port: 3000
---
# metrics bypass (same host)
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: grafana-metrics
  namespace: observability
  annotations:
    konghq.com/plugins: ip-admin
spec:
  hostnames: ["grafana.aldous.info"]
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /metrics
    backendRefs:
    - name: grafana
      port: 3000

# tests/curl.sh  – basic flows
set -e
# 1) unauthenticated → 302 to Keycloak
curl -k -I https://aldous.info | grep -E "HTTP/.*302"

# 2) token request (PKCE) – device/mobile
curl -X POST -d "grant_type=authorization_code&code=$CODE&client_id=mobile&code_verifier=$VERIFIER" \
  https://auth.aldous.info/realms/prod/protocol/openid-connect/token

# 3) authenticated access
curl -k -H "Authorization: Bearer $ACCESS" https://grafana.aldous.info/api/health

# 4) metrics scrape bypass (should be 200 without auth from admin CIDR)
curl -k https://grafana.aldous.info/metrics

# 5) Prometheus endpoint on Kong
curl -k https://edge.gateway.svc.cluster.local:9542/metrics

# host → service quick audit
| Hostname              | Namespace      | Service  |
|-----------------------|----------------|----------|
| aldous.info           | apps           | web      |
| grafana.aldous.info   | observability  | grafana  |
| kibana.aldous.info    | observability  | kibana   |
| sonarqube.aldous.info | ci             | sonarqube|
| ...                   | ...            | ...      |

# enable modules via TF root (excerpt)
module "kong" {
  source   = "./modules/kong"
  enabled  = true
}

module "keycloak" {
  source   = "./modules/keycloak"
  enabled  = true
}

# make targets
make phase2-kong
make phase2-keycloak

# verify Gateway & Routes
kubectl get gateways -n gateway
kubectl get httproutes -A


