# Mindfield – TODO

---

## 0  Repo & Scaffolding Baseline  `P1  S`
> Establish clean git hygiene, directory conventions, split-compose skeleton, CI stub.

### 0.1  Repo House-Keeping
- [ ] **`.gitignore` refresh** → add: `/secrets/`, `/backups/`, `.env*`, `coverage/`, `.turbo/`, `*.age`, `*.tgz`.
- [ ] **`.editorconfig`** → LF, UTF-8, `indent_style = space`, `yaml_indent_size = 2`, `ts_indent_size = 4`.

### 0.2  Top-level Layout Extensions

* [ ] Create folders:

  ```text
  infra/               # GitOps shim
    k3s/               # bootstrap manifests
    helmfile.yaml      # root Helmfile
    flux/              # Flux Kustomizations
    terraform/         # (empty) infra modules

  secrets-templates/
    oidc.env.example
    stripe.env.example
    db.env.example

  backups/
    policies/          # Velero Schedule CRDs
    scripts/
      backup.sh
      restore.sh
  ```

### 0.3  Compose Split Stub

* [ ] Copy current **`docker-compose.yml` ➜ `docker-compose.base.yml`**.
* [ ] Generate blank overrides:

  * `docker-compose.dev.yml`
  * `docker-compose.monitoring.yml`
* [ ] **Makefile** targets:

  ```makefile
  dev:  ; docker compose -f docker-compose.base.yml -f docker-compose.dev.yml        up -d
  prod: ; docker compose -f docker-compose.base.yml                                  up -d
  ```

### 0.4  CI/CD Skeleton

* [ ] `.github/workflows/ci.yml` – **lint + unit tests only**
* [ ] `.github/workflows/reusable-compose.yml` – blank reusable job (future compose spin-up).

### 0.5  Postgraphile On-Ramp

* [ ] Add service **placeholder** to `docker-compose.base.yml`:

  ```yaml
  postgraphile:
    image: graphile/postgraphile
    command: >
      --connection postgres://mindfield:mindfield@postgres:5432/mindfield
      --schema public --watch
    ports: ["5000:5000"]
    depends_on: [postgres]
  ```

### 0.6  Frontend Conventions

* [ ] Shared `tailwind.config.js` in repo root -> include `"core/ui/**/*.{ts,tsx}"`.
* [ ] `src/features/README.md` in both `apps/web` & `apps/mobile` describing slice layout.

### 0.7  Script Bootstrap

* [ ] `scripts/scaffold-service.sh` → scaffold `services/<name>/` + `Dockerfile`.
* [ ] `scripts/discover-services.sh` → `curl http://kong:8001/services | jq`.

### 0.8  Docs & Runbooks

* [ ] Move `docs/mkdocs.yml` to `docs/` root.
* [ ] Add empty `docs/runbook.md`, `docs/perf-baseline.md`.

### 0.9  Lint & Hooks

* [ ] **Husky + lint-staged**:

  ```bash
  pnpm dlx husky-init && pnpm husky add .husky/pre-commit "pnpm lint && pnpm format"
  ```

### 0.10  ENV Examples

* [ ] Consolidated `.env.example` including OIDC, Stripe, Postgres.

---

## 1  Edge / Auth Hardening  `P1  M`

> Secure perimeter: Kong ↔ Keycloak (OIDC), social IdPs.

### 1.1  Add OIDC Vars

```dotenv
OIDC_ISSUER=https://keycloak.local/auth/realms/mindfield
OIDC_CLIENT_ID=mindfield-client
OIDC_SECRET=change-me
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
APPLE_CLIENT_ID=
APPLE_TEAM_ID=
APPLE_KEY_ID=
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
```

### 1.2  Update Kong Bootstrap

* Inject `${OIDC_*}` envs in `services/kong/configure.sh`.

### 1.3  Kong Declarative Config (`kong/kong.yml`)

* Under `openid-connect` plugin add Google & Apple IdP sections.

### 1.4  End-to-End Validation

```bash
docker compose up -d kong caddy keycloak api
open https://app.local/api/secure
# ✅ Redirect to Keycloak, Google sign-in, JWT → email + roles
```

---

## 2  Compose Refactor  `P1  M`

> Layered files, health-checks, smoother dev / CI.

### 2.1  `docker-compose.base.yml`

`api, postgres, redis, keycloak, kong, caddy`

### 2.2  `docker-compose.dev.yml` *(extends base)*

`mailhog, minio, mkdocs, presidio*`

### 2.3  `docker-compose.monitoring.yml`

`prometheus, grafana, loki, jaeger, alertmanager`

### 2.4  Health-checks *(all core)*

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/healthz"]
  interval: 30s
  timeout: 3s
  retries: 5
```

### 2.5  Dev Shortcut

```bash
make dev
```

---

## 3  CI Baseline  `P1  S`

* [ ] `.github/workflows/ci.yml`

  1. Checkout
  2. `docker compose -f docker-compose.base.yml up --abort-on-container-exit -d`
  3. `pnpm test`
  4. **Trivy** scan → fail on HIGH vulns.

---

## 4  Web Testing Seed  `P2  S`

* [ ] `apps/web`

  ```bash
  pnpm add -D jest @testing-library/react @testing-library/jest-dom
  npx jest --init
  ```
* [ ] Add `__tests__/App.test.tsx` (renders `<App />`).
* [ ] Include in CI step.

---

## 5  Postgraphile Adoption  `P2  M`

* [ ] Remove Hasura from compose if present.
* [ ] Ensure **single** `postgraphile` service in base (0.5).
* [ ] Caddy snippet:

  ```caddyfile
  reverse_proxy /graphql* postgraphile:5000
  ```

---

## 6  Frontend State & Styles Baseline  `P2  M`

```bash
pnpm add @reduxjs/toolkit react-redux @tanstack/react-query
```

* Shared `core/ui/tailwind.config.js`.
* Scaffold `features/profile` slice with RTK Query calling Postgraphile.

---

## 7  Billing Loop v0  `P2  L`

### 7.1  Kill Bill Catalog

* `catalog.xml` units: `api_call`, `storage_gb`, `email_sent`; monthly plan.

### 7.2  API Instrumentation

```ts
billingQueue.add('recordUsage',{
  accountId: user.id,
  unitType: 'api_call',
  quantity: 1,
  timestamp: new Date().toISOString()
});
```

### 7.3  Billing Worker

`core/logic/src/billing.worker.ts` → BullMQ → Kill Bill Usage API.

### 7.4  Add Worker Container

`billing-worker` in `docker-compose.base.yml`.

### 7.5  Smoke Test

* Generate fake `/items` call, verify invoice in Kill Bill UI.

---

## 8  Stripe Sandbox Gateway  `P2  L`

* Install Kill Bill Stripe plugin container.
* `.env` sandbox keys → plugin config.
* Issue **\$0.01** test invoice, expect success.

---

## 9  Secrets Hardening  `P1  S`

* Move sensitive envs to `docker/secrets/{db,oidc,stripe}.txt`.
* Update service definitions with:

  ```yaml
  secrets:
    - db_password
  ```

---

## 10  GitOps Bootstrap  `P3  L`

1. Provision VM (Ubuntu 22, 4 CPU, 8 GB RAM).
2. Install k3s single-node.
3. New repo **`mindfield-infra`**:

   ```bash
   flux bootstrap github \
     --owner=maldous --repository=mindfield-infra \
     --path=clusters/dev
   ```
4. Helm releases: postgres, api, postgraphile, kong, keycloak, killbill.

---

## 11  Backup & DR  `P3  M`

* Deploy Velero + MinIO (S3 backend).
* `Schedule` CRD `daily-full` (02:00 UTC).
* Document restore in `docs/runbook.md`.

---

## 12  Observability & Alerts  `P3  M`

* Grafana dashboards:

  * API p95 latency
  * Kong 5xx rate
  * Kill Bill payment failures
* Alertmanager rule: `billing-worker queue length > 100 for 10m`.

---

## 13  Feature Flags / Analytics  `P3  M`

* Deploy **PostHog** chart.
* Env `POSTHOG_KEY` to web & mobile.
* Flag `new_ui` gating experimental components.

---

## 14  Customer Portal MVP  `P3  L`

* Next.js `/account` route:

  * Fetch invoices via Kill Bill API
  * Usage chart (`react-chartjs-2`)
  * “Pay with Stripe (test)” button → Checkout Session
* Header social login buttons (Keycloak auth-link).

---

## 15  Performance Baseline  `P3  S`

```bash
k6 run - <(cat <<'EOF'
import http from 'k6/http';
export const options = { vus: 100, duration: '60s' };
export default () => { http.get('http://api.local/api/items'); };
EOF
)
```

* Record **p95** latency → append to `docs/perf-baseline.md` table.

---

### ✨  Completion Definition

Roadmap is **done** when:

1. All check-boxes ticked ✔
2. `make prod` spins up k3s cluster end-to-end with HTTPS, OIDC login, billing, monitoring.
3. `docs/runbook.md` + `docs/perf-baseline.md` fully populated.

---
