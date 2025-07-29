Prompt 1 — Infra Blueprint (plan, addons, file tree)

You are a senior Kubernetes/Terraform platform engineer.

Notes:

Network: Use Calico instead of Cilium.
Storage: Use Rook-Ceph for block + MinIO for S3; Postgres + PgBouncer; Redis.
Bitnami catalog changes (Aug 28, 2025): monitor image repo/tag migrations; prefer hardened bitnamisecure images where available. 
Loki charts: avoid loki-stack; use grafana/loki v6.x. 
Cloudflare permissions: ExternalDNS needs Zone:Read + DNS:Edit; cert‑manager needs DNS Edit and typically Zone Read. If scoping to a single zone, set --zone-id-filter. 
Kong Gateway choices: classic kong chart vs Gateway Operator (CRD‑native). Operator adds extra CRDs; ensure version compatibility. 
Jaeger vs Tempo: using Tempo per requirement; omit Jaeger charts. (Grafana recommends Tempo for traces; Jaeger v2 exists if ever needed.) 
Security baselines: enable Pod Security (baseline/restricted) and Calico NetworkPolicies; lock down namespaces, and place admin UIs behind OIDC + group mapping in Keycloak. 
metallb_pool: 192.168.1.250-192.168.1.254
kong_proxy_ip: 192.168.1.251   # A/AAAA: aldous.info, *.aldous.info -> 103.138.244.121
Kong OSS vs Enterprise OIDC: Enterprise plugin is first-party and better supported.
If using OSS, rely on community OIDC plugins or forward-auth patterns. Pin chart 2.51.0 and test. 
MicroK8s “observability” addon is not used: we install upstream charts directly to pin versions and persistence.
Rook-Ceph on single-node: tolerate single failure domain only; set replica=1 pools; monitor disk pressure.
Loki: use chart `grafana/loki` (v6.x). Avoid loki-stack. 
Tempo: choose distributed for parity; requires object storage (S3/MinIO). 
Bitnami images: prefer non-root, watch VMware/Bitnami image/tag changes; validate “secure” variants when available. 
Cloudflare proxy: if orange-cloud, ensure HTTP/2/HTTP/3, websockets, and increase body size as needed; configure real IPs on Kong.
GPU: addon exposes NVIDIA runtime; workloads must request GPU resources. Verify host driver/toolkit. 
Security: apply Pod Security labels (baseline/restricted) per namespace; add Calico NetworkPolicies to default-deny then open per app.
Backups: enable Velero or snapshots; persist Grafana, Prometheus TSDB retention, Loki/Tempo object storage, Postgres backups.
GitOps: keep Argo CD module stubbed until the platform is stable; then migrate releases to GitOps.
ExternalDNS Chart values: provider cloudflare, CF_API_TOKEN with Zone:Read + DNS:Edit; if scoping to a single zone use --zone-id-filter=<zone_id>. 
cert‑manager: ClusterIssuer using ACME Let’s Encrypt, DNS‑01 with Cloudflare API token. Issue *.aldous.info and aldous.info. 
Kong OIDC: Use Kong’s OIDC plugin with auth code + session for browser UIs; PKCE public client for mobile. Configure discovery, client_id, client_secret (confidential admin UIs), redirect_uri, scopes, session_secret, upstream_headers. Enforce group/role claims for admin UIs.

Goal: design a production‑like *dev* platform on MicroK8s for a Node/Python + React web app with mobile client and billing. All external UIs behind Keycloak OIDC via Kong Gateway. TLS via cert-manager using Cloudflare DNS‑01. External DNS records auto-managed. Wildcard cert for *.aldous.info and apex. All service UIs must require auth. Top-level aldous.info serves the web app; mobile app authenticates (PKCE) and then uses the same gateway.

Constraints:
- MicroK8s node, MetalLB for LB IPs.
- Prefer Helm releases over raw YAML when available.
- Use Terraform to orchestrate MicroK8s addons (null_resource) + `helm` and `kubernetes` providers for charts/manifests.
- Storage: Rook-Ceph for block + MinIO for S3; Postgres + PgBouncer; Redis.
- Observability: Prometheus, Alertmanager, Grafana, Loki, Tempo, Promtail, Blackbox, OTel Collector.
- Security: RBAC, PodSecurity (baseline/restricted), NetworkPolicies (CNI = Calico), rate-limiting at Kong, ESO for secrets (SOPS-compatible), Trivy for image scan.
- GitOps optional (Argo CD) but include module stub.
- GPU addon enabled (dev parity).
- Services to include or equivalents via charts: 
  - Kong Gateway (edge), Keycloak, Postgres, PgBouncer, Redis
  - SonarQube, Mailhog, pgAdmin4
  - Prometheus, Alertmanager, Grafana, Node Exporter, Loki, Promtail, Tempo, Blackbox, OTel Collector
  - Uptime‑Kuma
  - MinIO, OpenSearch + Dashboards
  - Trivy
  - Swagger UI, Redoc, MkDocs Material, PostGraphile
- Use Tempo over Jaeger
- All external UIs go through Kong with OIDC (Keycloak realm “prod”, clients: web, mobile (PKCE), admin), group/role mapping, session limits, and refresh token rotation.
- Cloudflare: ExternalDNS + cert-manager DNS‑01 via API token (scoped: Zone:DNS Edit). Wildcard cert + apex.
- Single ingress/edge via Kong Gateway (Gateway API). No public nginx.

Deliver:
1) Final MicroK8s addon list (enable lines).
2) Terraform root and modules file tree.
3) Exact list of Helm releases with chart versions.
4) High-level dependency graph (apply order).
5) IPs/hosts model: which hostnames route to which services via Kong.
6) Risks/notes.

Output: concise bullets and code blocks only.
Key Improvements: Focused scope, explicit components, single edge (Kong), security posture, dependency order, concrete deliverables.

Techniques Applied: Role assignment, constraint-based planning, structure-first.

Include versions pinned to current stable releases.

################################################################################

Prompt 2 — Terraform Scaffolding & Providers

Act as a Terraform lead. Generate the initial working Terraform project for the platform described earlier.

Produce:
- `providers.tf` with `helm`, `kubernetes`, `null`, `random`, `tls` providers; lock versions.
- `variables.tf` with sensible defaults for: metallb_range, domain, cloudflare_zone_id, cloudflare_email, cloudflare_api_token (sensitive), acme_email, cidr_allow_admin, postgres versions, storage sizes.
- `outputs.tf` with key endpoints and secrets (marked sensitive).
- `main.tf` wiring modules in dependency order.

Create module folders and stub `main.tf/variables.tf/outputs.tf` for:
`microk8s_addons`, `cilium`, `cert_manager`, `external_dns`, `external_secrets`,
`postgres`, `pgbouncer`, `redis`, `minio`, `rook_ceph`, `opensearch`,
`kong`, `keycloak`, `observability`, `uptime_kuma`, `sonarqube`,
`mailhog`, `pgadmin`, `swagger_ui`, `redoc`, `mkdocs`, `postgraphile`,
`trivy`, `gitops_argocd` (disabled by default).

Include:
- `modules/microk8s_addons/main.tf` using `null_resource` with a `triggers` hash and the final addon list.
- `helm-values/` placeholders for each chart.
- A `README.md` with `terraform init/apply`, and post‑apply smoke tests.

Output everything as code blocks ready to paste.
Key Improvements: Complete scaffolding, modules listed, stub files, reproducible apply path.

Techniques Applied: Mechanical few-shot generation with precise structure.

Add a locals.tf for common labels/annotations.

################################################################################

Prompt 3 — Cloudflare DNS01 + ExternalDNS + Wildcard Certs

Generate Kubernetes and Helm config for:
- cert-manager ClusterIssuer using Cloudflare DNS-01 (production + staging).
- `external-dns` Helm values for Cloudflare provider, limited to the zone of `var.domain`, ownership TXT records, and sync policy = upsert-only.
- A wildcard Certificate for `*.aldous.info` and `aldous.info` in `gateway` namespace, referenced by Kong.
- Secret manifests or ESO templates for the Cloudflare API token and ACME private key.
- Security: the CF token must be least-privilege (Zone:DNS Edit). Store secret via ESO.

Provide:
1) `helm_release` for cert-manager and external-dns with pinned versions and required CRDs.
2) YAML for `ClusterIssuer` (staging + prod) and the wildcard `Certificate`.
3) Example ESO `ExternalSecret` pulling `cloudflare-api-token` from a `ClusterSecretStore k8s-secrets-store` (dev).
4) Notes on reconcilers and how to verify issuance (`kubectl describe certificate ...`).

Only code blocks.
Key Improvements: Ties DNS, ACME, ESO together; enforces least-privilege.

Techniques Applied: Constraint optimization, security emphasis.

Include retry/backoff settings for ExternalDNS.

################################################################################

Prompt 4 — Edge: Kong + Keycloak OIDC (all UIs protected)

Design Kong Gateway + Keycloak OIDC to protect *all* external UIs.

Requirements:
- Single public LoadBalancer IP (MetalLB) -> Kong proxy.
- Gateway API resources for Kong.
- OIDC with Keycloak realm `prod`, clients:
  - `web` (confidential; redirect URIs for aldous.info and *.aldous.info),
  - `mobile` (public PKCE),
  - `admin` (confidential; admin consoles).
- Map user groups/roles to scopes/claims used by Kong authorization.
- Rate limiting and CORS policies.
- Session, refresh token rotation, cookie flags (Secure, HttpOnly, SameSite=Lax).
- Each UI/service exposed as a Kong Route with OIDC plugin attached.
- Health/metrics endpoints bypass OIDC but IP-restricted (`cidr_allow_admin`).
- Certificate secret name to reference: `edge-cert` in `gateway` namespace.

Deliver:
1) Helm release for Kong with values enabling: service type LB, proxy annotations, OIDC plugin, rate-limit plugin, Prometheus metrics.
2) Keycloak Helm release with external Postgres and admin secret via ESO; initial realm/clients/roles via `extraInitContainers` or `values.extraEnvVars` + realm import.
3) Kong manifests (GatewayClass, Gateway, HTTPRoutes, KongPlugin for OIDC, rate-limit, CORS).
4) Example route mappings:
   - `aldous.info` -> web app
   - `grafana.aldous.info`, `kibana.aldous.info`, `sonarqube.aldous.info`, etc., all OIDC-protected.
5) Tests: curl flows for OIDC, 401 vs 302, and Prometheus scrape.

Only code blocks; pin chart versions.
Key Improvements: Enforces single edge, PKCE, role-based access, admin bypass rules.

Techniques Applied: Multi-component integration, security-first, example mappings.

Emit a table of hostnames → services for quick audits.

################################################################################

Prompt 5 — Data, Storage & Observability

Produce Terraform `helm_release` + minimal values for:

Data:
- `postgres` (bitnami) with WAL settings for dev, persistent PVC, NetworkPolicy, strong auth.
- `pgbouncer` (bitnami) SCRAM-SHA-256, auth_query, connection limits; ClusterIP only.
- `redis` (bitnami) with auth, NetworkPolicy.
- `minio` (operator or standalone) with persistent volumes, S3 buckets for logs/backups/artifacts.
- `opensearch` + `opensearch-dashboards` (single-node dev, security enabled).

Observability:
- `kube-prometheus-stack` (Prom, Grafana, Alertmanager), `loki`, `promtail`, `tempo`, `blackbox-exporter`, `otel-collector`.
- Pre-configured dashboards + scrape configs for Kong, Keycloak, Postgres, Redis, MinIO, OpenSearch, Node Exporter.
- Alerting examples (high CPU, PV nearly full, cert expiring).

Utilities:
- `uptime-kuma`, `sonarqube`, `mailhog`, `pgadmin4`, `trivy` (daemonset scanner or on-demand job), optional `swagger-ui`, `redoc`, `mkdocs-material`, `postgraphile`.

Also provide:
- Sample `NetworkPolicy` defaults: namespace default‑deny, allow DNS, allow egress to Cloudflare ACME endpoints.
- PodSecurity labels for namespaces (baseline/restricted).
- Example SOPS+ESO `ClusterSecretStore` and a couple `ExternalSecret` objects.

Output as Terraform `helm_release` blocks and YAML manifests in code blocks only.
Key Improvements: Complete data + obs stack with security baselines.

Techniques Applied: Systematic decomposition, constraint-based outputs.

Grafana datasources and dashboards to be provisioned via ConfigMaps.

################################################################################

Prompt 6 — Smoke Tests & Runbook

Create a compact smoke-test and runbook:

1) Post-apply verification commands (pods, services, CRDs, issuers, certificates, routes).
2) DNS + cert issuance checks.
3) OIDC login flow test with curl and a headless browser hint.
4) Metrics/logs/traces validation queries.
5) Backup/restore drills for Postgres and MinIO.
6) Common failure modes with quick fixes (ExternalDNS permissions, ACME rate limits, Kong OIDC misconfig, Ceph not healthy, Tempo ingester issues).

Output as numbered shell blocks with expected outputs. Be concise.
Key Improvements: Operationalizes the platform; fast feedback.

Techniques Applied: Runbook synthesis, scenario coverage.

Include kubectl wait --for=condition=Available sequences.


################################################################################

# 2) Generate Terraform scaffolding (Prompt 2) and commit.
# 3) Implement DNS/ACME (Prompt 3) and verify wildcard cert issuance.
# 4) Stand up Kong + Keycloak (Prompt 4); test OIDC with a single UI (Grafana).
# 5) Bring up data + observability (Prompt 5); confirm dashboards.
# 6) Run smoke tests (Prompt 6); iterate.

################################################################################
