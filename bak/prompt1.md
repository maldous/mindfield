---

## 1) MicroK8s addons to enable

```bash
microk8s enable \
  dns rbac helm3 metrics-server \
  cert-manager \
  metallb:192.168.1.250-192.168.1.254 \
  gpu
# Do NOT enable: ingress, observability. Calico is default CNI.
```

* Calico is the default CNI in MicroK8s ≥1.19 (VXLAN). ([microk8s.io][1], [microk8s.io][2])
* MetalLB pool above; assign **192.168.1.251** to Kong proxy. ([microk8s.io][3])
* GPU addon installs NVIDIA container runtime/toolkit; host must have drivers. ([microk8s.io][4])

---

## 2) Terraform root & modules tree

```text
infra/
└── terraform
    ├── helm-values/
    │   ├── cert-manager.yaml
    │   ├── external-dns.yaml
    │   ├── external-secrets.yaml
    │   ├── kong.yaml
    │   ├── keycloak.yaml
    │   ├── postgres.yaml
    │   ├── pgbouncer.yaml
    │   ├── redis.yaml
    │   ├── rook-operator.yaml
    │   ├── rook-cluster.yaml
    │   ├── minio-operator.yaml
    │   ├── minio-tenant.yaml
    │   ├── kube-prometheus-stack.yaml
    │   ├── loki.yaml
    │   ├── promtail.yaml
    │   ├── tempo-distributed.yaml
    │   ├── blackbox-exporter.yaml
    │   ├── otel-collector.yaml
    │   ├── opensearch.yaml
    │   ├── opensearch-dashboards.yaml
    │   ├── sonarqube.yaml
    │   ├── uptime-kuma.yaml
    │   ├── mailhog.yaml
    │   ├── pgadmin4.yaml
    │   ├── trivy-operator.yaml
    │   └── velero.yaml
    ├── main.tf
    ├── providers.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
        ├── microk8s_addons/
        │   └── main.tf
        ├── metallb/
        │   └── main.tf
        ├── cert_manager/
        │   ├── main.tf   # installs chart + ClusterIssuers
        │   └── variables.tf
        ├── external_dns/
        │   └── main.tf
        ├── external_secrets/
        │   └── main.tf
        ├── kong/
        │   └── main.tf   # CRDs, Gateway, HTTPRoutes, OIDC plugins
        ├── keycloak/
        │   └── main.tf
        ├── storage/
        │   ├── rook_operator.tf
        │   ├── rook_cluster.tf
        │   ├── minio_operator.tf
        │   └── minio_tenant.tf
        ├── datastores/
        │   ├── postgres.tf
        │   ├── pgbouncer.tf
        │   └── redis.tf
        ├── observability/
        │   ├── prometheus_stack.tf
        │   ├── loki.tf
        │   ├── promtail.tf
        │   ├── tempo.tf
        │   ├── blackbox.tf
        │   └── otel_collector.tf
        ├── search/
        │   ├── opensearch.tf
        │   └── dashboards.tf
        ├── dev_tools/
        │   ├── sonarqube.tf
        │   ├── uptime_kuma.tf
        │   ├── mailhog.tf
        │   └── pgadmin4.tf
        ├── security/
        │   ├── trivy_operator.tf
        │   └── policies.tf   # Pod Security, NetworkPolicies
        └── backup/
            └── velero.tf
```

---

## 3) Helm releases (pinned)

```yaml
# Repos (OCI where possible)
repos:
  jetstack: https://charts.jetstack.io
  external-dns: https://kubernetes-sigs.github.io/external-dns/
  external-secrets: https://charts.external-secrets.io
  kong: https://charts.konghq.com
  bitnami: oci://registry-1.docker.io/bitnamicharts
  prometheus-community: https://prometheus-community.github.io/helm-charts
  grafana: https://grafana.github.io/helm-charts
  opentelemetry: https://open-telemetry.github.io/opentelemetry-helm-charts
  opensearch: https://opensearch-project.github.io/helm-charts
  sonarqube: https://SonarSource.github.io/helm-chart-sonarqube
  dirsigler: https://helm.irsigler.cloud
  codecentric: https://codecentric.github.io/helm-charts
  runix: https://helm.runix.net
  aquasecurity: https://aquasecurity.github.io/helm-charts
  vmware-tanzu: https://vmware-tanzu.github.io/helm-charts

releases:
  - name: cert-manager
    chart: jetstack/cert-manager
    version: v1.18.2
    namespace: cert-manager
    values: [helm-values/cert-manager.yaml]
  - name: external-dns
    chart: external-dns/external-dns
    version: 1.18.0
    namespace: networking
    values: [helm-values/external-dns.yaml]
  - name: external-secrets
    chart: external-secrets/external-secrets
    version: 0.18.2
    namespace: eso
    values: [helm-values/external-secrets.yaml]
  - name: kong
    chart: kong/kong
    version: 2.51.0
    namespace: kong
    values: [helm-values/kong.yaml]
  - name: keycloak
    chart: bitnami/keycloak
    version: 24.8.1
    namespace: auth
    values: [helm-values/keycloak.yaml]
  - name: postgresql
    chart: bitnami/postgresql
    version: 16.7.21
    namespace: data
    values: [helm-values/postgres.yaml]
  - name: pgbouncer
    chart: icoretech/pgbouncer
    version: 2.8.1
    namespace: data
    values: [helm-values/pgbouncer.yaml]
  - name: redis
    chart: bitnami/redis
    version: 21.2.13
    namespace: data
    values: [helm-values/redis.yaml]
  - name: kube-prometheus-stack
    chart: prometheus-community/kube-prometheus-stack
    version: 75.15.0
    namespace: monitoring
    values: [helm-values/kube-prometheus-stack.yaml]
  - name: loki
    chart: grafana/loki
    version: 6.24.0
    namespace: monitoring
    values: [helm-values/loki.yaml]
  - name: promtail
    chart: grafana/promtail
    version: 6.17.0
    namespace: monitoring
    values: [helm-values/promtail.yaml]
  - name: tempo
    chart: grafana/tempo-distributed
    version: 1.46.0
    namespace: monitoring
    values: [helm-values/tempo-distributed.yaml]
  - name: blackbox-exporter
    chart: prometheus-community/prometheus-blackbox-exporter
    version: 11.1.1
    namespace: monitoring
    values: [helm-values/blackbox-exporter.yaml]
  - name: otel-collector
    chart: opentelemetry/opentelemetry-collector
    version: 0.103.1    # example: pin to current at install time
    namespace: monitoring
    values: [helm-values/otel-collector.yaml]
  - name: opensearch
    chart: opensearch/opensearch
    version: 3.1.0
    namespace: search
    values: [helm-values/opensearch.yaml]
  - name: opensearch-dashboards
    chart: opensearch/opensearch-dashboards
    version: 3.1.0
    namespace: search
    values: [helm-values/opensearch-dashboards.yaml]
  - name: minio-operator
    chart: minio/operator
    version: 6.0.4
    namespace: minio-operator
    values: [helm-values/minio-operator.yaml]
  - name: minio-tenant
    chart: minio/tenant
    version: 6.0.4
    namespace: minio
    values: [helm-values/minio-tenant.yaml]
  - name: sonarqube
    chart: sonarqube/sonarqube
    version: 2025.3.1
    namespace: devtools
    values: [helm-values/sonarqube.yaml]
  - name: uptime-kuma
    chart: dirsigler/uptime-kuma
    version: 2.21.3
    namespace: devtools
    values: [helm-values/uptime-kuma.yaml]
  - name: mailhog
    chart: codecentric/mailhog
    version: 5.8.0
    namespace: devtools
    values: [helm-values/mailhog.yaml]
  - name: pgadmin4
    chart: runix/pgadmin4
    version: 1.47.0
    namespace: devtools
    values: [helm-values/pgadmin4.yaml]
  - name: trivy-operator
    chart: aquasecurity/trivy-operator
    version: 0.29.3
    namespace: trivy-system
    values: [helm-values/trivy-operator.yaml]
  - name: velero
    chart: vmware-tanzu/velero
    version: 10.0.10
    namespace: velero
    values: [helm-values/velero.yaml]
```

* cert‑manager **v1.18.2**. ([Artifact Hub][5], [cert-manager][6])
* external‑dns **1.18.0** (controller uses image v0.18.0). ([Artifact Hub][7], [GitHub][8])
* ESO **0.18.2**. ([Artifact Hub][9])
* Kong **2.51.0**. ([Artifact Hub][10], [GitHub][11], [GitHub][11])
* Keycloak (Bitnami) **24.8.1**. ([Artifact Hub][12], [GitHub][13])
* PostgreSQL (Bitnami) **16.7.21**. ([Artifact Hub][14], [Artifact Hub][14], [GitHub][15])
* PgBouncer **2.8.1** (icoretech chart). ([Artifact Hub][16], [IcoreTech][17])
* Redis (Bitnami) **21.2.13**. ([Artifact Hub][18], [GitHub][19])
* kube‑prometheus‑stack **75.15.0**. ([Artifact Hub][20], [GitHub][21])
* Loki **6.24.0**; Promtail **6.17.0**. ([Artifact Hub][22], [Artifact Hub][23])
* Tempo‑distributed **1.46.0**. ([Artifact Hub][24], [GitHub][25], [Grafana Labs][26])
* Blackbox Exporter **11.1.1**. ([Artifact Hub][27], [GitHub][28])
* OpenTelemetry Collector chart (pin to current; verify at install — latest series is fast‑moving; example shown). ([Artifact Hub][29], [Artifact Hub][30], [GitHub][31], [GitHub][32])
* OpenSearch **3.1.0**; Dashboards **3.1.0**. ([Artifact Hub][33], [GitHub][34])
* MinIO Operator **6.0.4** (operator & tenant). ([GitHub][35], [Artifact Hub][36])
* SonarQube **2025.3.1**. ([GitHub][37], [Artifact Hub][38])
* Uptime‑Kuma **2.21.3**. ([Artifact Hub][39], [GitHub][40])
* Mailhog **5.8.0**. ([Artifact Hub][41], [GitHub][42])
* pgAdmin4 **1.47.0**. ([Artifact Hub][43], [GitHub][44])
* Trivy Operator **0.29.3** (chart) / Trivy scan engine. ([Artifact Hub][45], [Artifact Hub][46], [GitHub][47])
* Velero **10.0.10** (chart). ([GitHub][48], [Artifact Hub][49])
* Bitnami “Secure Images” catalog shift (plan for repo/tag changes after **Aug 28, 2025**). ([GitHub][13], [GitHub][50], [GitHub][51])

> Tools without robust charts (Swagger UI, ReDoc, MkDocs, PostGraphile) should be shipped as simple Deployments + Services templated by Terraform `kubernetes_manifest`, fronted by Kong HTTPRoutes & OIDC. Cite image tags in app repos when you add them.

---

## 4) Dependency / apply order

```text
0. microk8s_addons       # dns, rbac, helm3, metrics-server, cert-manager, metallb, gpu
1. metallb               # IPAddressPool + L2Advertisement -> reserve 192.168.1.251 for Kong
2. namespaces + PSA      # create namespaces with Pod Security labels (baseline/restricted)
3. cert-manager          # install chart
4. secrets               # CF API token secret (or ESO bootstrap secret)
5. external-dns          # Cloudflare provider; zone-id filter
6. external-secrets      # cluster-scoped ESO + SecretStore(s)
7. storage operators     # rook-operator -> rook-cluster (replicas=1); minio-operator -> tenant
8. datastores            # postgres, pgbouncer, redis
9. keycloak              # realm=prod; clients web (confidential), mobile (public PKCE), admin
10. kong                 # Gateway, listener on 80/443, OIDC plugins, session/PKCE, rate-limits
11. observability        # kube-prom-stack, loki, promtail, tempo, blackbox, otel-collector
12. search               # opensearch + dashboards
13. dev tools            # sonarqube, uptime-kuma, mailhog, pgadmin4
14. security             # trivy-operator
15. backup               # velero (object store = MinIO)
```

---

## 5) IPs / Hostnames via Kong

```text
Public LB IP (MetalLB → Kong proxy): 192.168.1.251
Cloudflare DNS:
  A/AAAA: aldous.info        -> 103.138.244.121 (CF orange-cloud to your WAN/NAT to 192.168.1.251)
  CNAME: *.aldous.info       -> aldous.info
  (ExternalDNS manages records post‑bootstrap)

Routes (all via Kong, TLS from cert‑manager LE DNS‑01):
  https://aldous.info                 -> web-app service (React SPA)
  https://api.aldous.info             -> backend gateway (Node/Python APIs)
  https://auth.aldous.info            -> Keycloak
  https://grafana.aldous.info         -> Grafana
  https://prometheus.aldous.info      -> Prometheus
  https://alertmanager.aldous.info    -> Alertmanager
  https://loki.aldous.info            -> Loki (admin restricted)
  https://tempo.aldous.info           -> Tempo (admin restricted)
  https://ops.aldous.info             -> Uptime-Kuma
  https://sonar.aldous.info           -> SonarQube
  https://mailhog.aldous.info         -> Mailhog
  https://pgadmin.aldous.info         -> pgAdmin4
  https://search.aldous.info          -> OpenSearch Dashboards
  https://docs.aldous.info            -> MkDocs Material
  https://swagger.aldous.info         -> Swagger UI
  https://redoc.aldous.info           -> Reoc
```

---

## 6) Key values snippets

**cert‑manager ClusterIssuers (Cloudflare DNS‑01):**

```yaml
# kubernetes_manifest via Terraform
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: you@aldous.info
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef: { name: le-account-key }
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: token
        selector:
          dnsZones: ["aldous.info"]
```

**external‑dns (Cloudflare):**

```yaml
provider:
  name: cloudflare
  cloudflare:
    proxied: true
extraArgs:
  - --zone-id-filter=<YOUR_ZONE_ID>
  - --txt-prefix=k8s.
  - --ingress-class=kong
sources: ["ingress", "gateway-httproute"]
domainFilters: ["aldous.info"]
env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: token
serviceMonitor:
  enabled: true
```

Cloudflare token must grant **Zone\:Read** + **DNS\:Edit**. ([GitHub][52])

**Kong OIDC (browser + mobile PKCE):**

```yaml
# helm-values/kong.yaml (extract)
env:
  headers: "on"
  trusted_ips: "0.0.0.0/0,::/0"
  real_ip_header: "CF-Connecting-IP"
  real_ip_recursive: "on"
proxy:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.251
ingressController:
  enabled: true
  ingressClass: kong
  watchNamespaceSelector: {}
  admissionWebhook:
    enabled: true
  gateway:
    enabled: true
enterprise: { enabled: false }  # OSS
plugins:
  configMaps:
    - name: oidc-plugin
      pluginName: openid-connect
      config:
        issuer: "https://auth.aldous.info/realms/prod"
        client_id: "${WEB_CLIENT_ID}"
        client_secret: "${WEB_CLIENT_SECRET}"
        scopes: "openid,profile,email,offline_access"
        auth_methods: "authorization_code"
        bearer_only: "no"
        session_secret: "${KONG_SESSION_SECRET}"
        redirect_uri: "https://aldous.info/_callback"
        filters: "~^/healthz"
        verify_claims: "yes"
        roles_claim: "realm_access.roles"
        logout_path: "/logout"
```

(If you move to **Kong Enterprise**, switch to the first‑party OIDC plugin for supportability.)

**Tempo object storage (MinIO/S3):**

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      endpoint: minio.minio.svc.cluster.local:9000
      access_key: ${MINIO_ACCESS_KEY}
      secret_key: ${MINIO_SECRET_KEY}
      insecure: true
```

Grafana recommends Tempo for traces; Loki chart v6.x is current. ([Grafana Labs][53], [Grafana Labs][26])

---

## 7) Risks / notes

* **Bitnami catalog change (Aug 28, 2025):** tags move to hardened *bitnamisecure*; non-latest tags pruned. Plan for repo/tag updates and image pull secrets if required. ([GitHub][13], [GitHub][50], [GitHub][51])
* **Calico & PSA:** enforce namespace Pod Security `baseline/restricted`; add Calico `NetworkPolicy` default‑deny and open per app/monitoring. Calico is default in MicroK8s. ([microk8s.io][1], [Calico Documentation][54])
* **Single‑node Rook‑Ceph:** set pool replicas=1; monitor disk pressure; this is for dev parity only. (Inference from Rook docs best practices.)
* **Observability scope:** kube‑prometheus‑stack does **not** include blackbox exporter; you’re installing it separately (correct). ([GitHub][21])
* **Grafana Agent deprecation → Alloy:** stick with **OTel Collector**; Alloy/Agent reach EOL Nov 1, 2025. ([Grafana Labs][55], [Grafana Labs][56], [Grafana Labs][57])
* **GPU:** ensure host NVIDIA drivers match CUDA/toolkit; addon deploys toolkit daemonset. Validate with `nvidia-smi` and a CUDA test pod. ([microk8s.io][4])
* **External UIs:** put every UI behind Kong OIDC; admin UIs require Keycloak group claim checks (Kong route‑level plugin instances).
* **DNS propagation:** first apply will create/validate DNS‑01; allow time for Cloudflare TXT records.
* **Backups:** Velero to MinIO; schedule nightly; also dump Postgres; snapshot Ceph PVCs.

---

## 8) Next actions

```bash
# 1) Enable base addons
terraform apply -target=module.microk8s_addons

# 2) Configure MetalLB pool
terraform apply -target=module.metallb

# 3) Install cert-manager
terraform apply -target=module.cert_manager

# 4) Create CF token secret (bootstrap) then ExternalDNS + ESO
terraform apply -target=module.external_dns -target=module.external_secrets

# 5) Storage, Datastores, Keycloak, Kong
terraform apply -target=module.storage -target=module.datastores -target=module.keycloak -target=module.kong

# 6) Observability & the rest
terraform apply
```

Want me to generate the initial `providers.tf`, `main.tf`, and a few key `values.yaml` files?

[1]: https://microk8s.io/docs/configure-cni?utm_source=chatgpt.com "MicroK8s CNI Configuration"
[2]: https://microk8s.io/docs/configure-host-interfaces?utm_source=chatgpt.com "Configure host interfaces used by MicroK8s"
[3]: https://microk8s.io/docs/addon-metallb?utm_source=chatgpt.com "MicroK8s - Addon: MetalLB"
[4]: https://microk8s.io/docs/addon-gpu?utm_source=chatgpt.com "MicroK8s - Add-on: gpu"
[5]: https://artifacthub.io/packages/helm/cert-manager/cert-manager?utm_source=chatgpt.com "cert-manager 1.18.2 · cert-manager/cert-manager - Artifact Hub"
[6]: https://cert-manager.io/docs/installation/helm/?utm_source=chatgpt.com "Helm - cert-manager Documentation"
[7]: https://artifacthub.io/packages/helm/external-dns/external-dns?utm_source=chatgpt.com "external-dns 1.18.0 · kubernetes-sigs/external-dns - Artifact Hub"
[8]: https://github.com/kubernetes-sigs/external-dns/releases?utm_source=chatgpt.com "Releases: kubernetes-sigs/external-dns - GitHub"
[9]: https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets?utm_source=chatgpt.com "external-secrets 0.18.2 · external-secrets/external-secrets-operator"
[10]: https://artifacthub.io/packages/helm/kong/kong?utm_source=chatgpt.com "kong 2.51.0 · kong/kong - Artifact Hub"
[11]: https://github.com/Kong/charts?utm_source=chatgpt.com "GitHub - Kong/charts: Helm charts for Kong"
[12]: https://artifacthub.io/packages/helm/bitnami/keycloak?utm_source=chatgpt.com "keycloak 24.8.1 · bitnami/bitnami - Artifact Hub"
[13]: https://github.com/bitnami/charts/blob/main/bitnami/keycloak/README.md?utm_source=chatgpt.com "charts/bitnami/keycloak/README.md at main - GitHub"
[14]: https://artifacthub.io/packages/helm/bitnami/postgresql?utm_source=chatgpt.com "postgresql 16.7.21 · bitnami/bitnami - Artifact Hub"
[15]: https://github.com/bitnami/charts/blob/main/bitnami/postgresql/README.md?utm_source=chatgpt.com "charts/bitnami/postgresql/README.md at main - GitHub"
[16]: https://artifacthub.io/packages/helm/icoretech/pgbouncer?utm_source=chatgpt.com "pgbouncer 2.8.1 · icoretech/icoretech - Artifact Hub"
[17]: https://icoretech.github.io/helm/charts/pgbouncer/?utm_source=chatgpt.com "PgBouncer Helm Chart | helm"
[18]: https://artifacthub.io/packages/helm/bitnami/redis?utm_source=chatgpt.com "redis 21.2.13 · bitnami/bitnami - Artifact Hub"
[19]: https://github.com/bitnami/charts/blob/main/bitnami/redis/README.md?utm_source=chatgpt.com "charts/bitnami/redis/README.md at main - GitHub"
[20]: https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack?utm_source=chatgpt.com "kube-prometheus-stack 75.15.0 · prometheus/prometheus-community"
[21]: https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md?utm_source=chatgpt.com "helm-charts/charts/kube-prometheus-stack/README.md at main · prometheus ..."
[22]: https://artifacthub.io/packages/helm/grafana/loki/6.24.0?utm_source=chatgpt.com "loki 6.24.0 · grafana/grafana - artifacthub.io"
[23]: https://artifacthub.io/packages/helm/grafana/promtail?utm_source=chatgpt.com "promtail 6.17.0 · grafana/grafana - Artifact Hub"
[24]: https://artifacthub.io/packages/helm/grafana/tempo-distributed?utm_source=chatgpt.com "tempo-distributed 1.46.0 · grafana/grafana - Artifact Hub"
[25]: https://github.com/grafana/helm-charts/blob/main/charts/tempo-distributed/README.md?utm_source=chatgpt.com "helm-charts/charts/tempo-distributed/README.md at main · grafana/helm ..."
[26]: https://grafana.com/docs/tempo/latest/setup/helm-chart/?utm_source=chatgpt.com "Deploy Tempo with Helm | Grafana Tempo documentation"
[27]: https://artifacthub.io/packages/helm/prometheus-community/prometheus-blackbox-exporter?utm_source=chatgpt.com "prometheus-blackbox-exporter 11.1.1 · prometheus/prometheus-community"
[28]: https://github.com/helm/charts/blob/master/stable/prometheus-blackbox-exporter/README.md?utm_source=chatgpt.com "charts/stable/prometheus-blackbox-exporter/README.md at master · helm ..."
[29]: https://artifacthub.io/packages/helm/opentelemetry-helm/opentelemetry-collector?utm_source=chatgpt.com "OpenTelemetry Collector Helm Chart - Artifact Hub"
[30]: https://artifacthub.io/packages/helm/opentelemetry-helm/opentelemetry-collector?modal=values&utm_source=chatgpt.com "OpenTelemetry Collector Helm Chart - artifacthub.io"
[31]: https://github.com/open-telemetry/opentelemetry-collector/releases?utm_source=chatgpt.com "Releases: open-telemetry/opentelemetry-collector - GitHub"
[32]: https://github.com/open-telemetry/opentelemetry-helm-charts/releases?utm_source=chatgpt.com "Releases: open-telemetry/opentelemetry-helm-charts - GitHub"
[33]: https://artifacthub.io/packages/helm/opensearch-project-helm-charts/opensearch?utm_source=chatgpt.com "opensearch 3.1.0 · opensearch-project/opensearch-project-helm-charts"
[34]: https://github.com/opensearch-project/helm-charts/releases?utm_source=chatgpt.com "Releases: opensearch-project/helm-charts - GitHub"
[35]: https://github.com/minio/operator/releases?utm_source=chatgpt.com "Releases · minio/operator - GitHub"
[36]: https://artifacthub.io/packages/helm/minio-operator/operator?utm_source=chatgpt.com "operator 7.1.1 · CodeScriptum/minio-operator - Artifact Hub"
[37]: https://github.com/SonarSource/helm-chart-sonarqube/releases?utm_source=chatgpt.com "Releases · SonarSource/helm-chart-sonarqube - GitHub"
[38]: https://artifacthub.io/packages/helm/sonarqube/sonarqube?utm_source=chatgpt.com "sonarqube 2025.3.1 · sonarsource/sonarqube - Artifact Hub"
[39]: https://artifacthub.io/packages/helm/uptime-kuma/uptime-kuma?utm_source=chatgpt.com "uptime-kuma 2.21.3 · dirsigler/uptime-kuma - Artifact Hub"
[40]: https://github.com/dirsigler/uptime-kuma-helm?utm_source=chatgpt.com "GitHub - dirsigler/uptime-kuma-helm: This Helm Chart installs Uptime ..."
[41]: https://artifacthub.io/packages/helm/codecentric/mailhog?utm_source=chatgpt.com "mailhog 5.8.0 · codecentric/codecentric"
[42]: https://github.com/helm/charts/blob/master/stable/mailhog/README.md?utm_source=chatgpt.com "charts/stable/mailhog/README.md at master · helm/charts"
[43]: https://artifacthub.io/packages/helm/runix/pgadmin4?utm_source=chatgpt.com "pgadmin4 1.47.0 · helm/runix - Artifact Hub"
[44]: https://github.com/rowanruseler/helm-charts/blob/master/charts/pgadmin4/README.md?utm_source=chatgpt.com "helm-charts/charts/pgadmin4/README.md at main - GitHub"
[45]: https://artifacthub.io/packages/helm/trivy-operator/trivy-operator?utm_source=chatgpt.com "trivy-operator 0.29.3 · deployment-aqua/trivy-operator - Artifact Hub"
[46]: https://artifacthub.io/packages/helm/trivy-operator/trivy?utm_source=chatgpt.com "trivy 0.16.1 · deployment-aqua/trivy-operator - Artifact Hub"
[47]: https://github.com/aquasecurity/trivy-operator?utm_source=chatgpt.com "GitHub - aquasecurity/trivy-operator: Kubernetes-native security toolkit"
[48]: https://github.com/vmware-tanzu/helm-charts/releases?utm_source=chatgpt.com "Releases: vmware-tanzu/helm-charts - GitHub"
[49]: https://artifacthub.io/packages/helm/vmware-tanzu/velero/2.12.0?utm_source=chatgpt.com "velero 2.12.0 · helm/vmware-tanzu - Artifact Hub"
[50]: https://github.com/bitnami/charts?utm_source=chatgpt.com "GitHub - bitnami/charts: Bitnami Helm Charts"
[51]: https://github.com/bitnami/charts/issues/35164?utm_source=chatgpt.com "Upcoming changes to the Bitnami catalog (effective August 28th, 2025)"
[52]: https://github.com/kubernetes-sigs/external-dns/blob/master/charts/external-dns/README.md?utm_source=chatgpt.com "external-dns/charts/external-dns/README.md at master - GitHub"
[53]: https://grafana.com/docs/loki/latest/setup/upgrade/upgrade-to-6x/?utm_source=chatgpt.com "Upgrade the Helm chart to 6.0 | Grafana Loki documentation"
[54]: https://docs.tigera.io/calico/latest/getting-started/kubernetes/microk8s?utm_source=chatgpt.com "Tutorial: Quickstart on microk8s | Calico Documentation - Tigera"
[55]: https://grafana.com/docs/agent/latest/operator/release-notes/?utm_source=chatgpt.com "Release notes for Grafana Agent Operator"
[56]: https://grafana.com/docs/agent/latest/?utm_source=chatgpt.com "Grafana Agent | Grafana Agent documentation"
[57]: https://grafana.com/blog/2024/04/09/grafana-agent-to-grafana-alloy-opentelemetry-collector-faq/?utm_source=chatgpt.com "From Agent to Alloy: Why we transitioned to the Alloy collector and why ..."

