# MindField – **Execution Tracker (`README.todo.md`)**

> **Read me line-by-line.**
> Every checkbox represents work that must be completed in **order**.
> A task is “Done” only when its **acceptance tests** pass in CI and the
> corresponding **documentation** is updated.

---

## ~~0 Scaffolding Baseline `P1 S`~~

| ~~#~~   | ~~Item~~                    | ~~Deliverable~~                                                                          | ~~Acceptance test~~                                              |
| ------- | --------------------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| ~~0.1~~ | ~~`.gitignore` refresh~~    | ~~Ignore `dist/`, `nx/cache`, `*.age`, `.DS_Store`~~                                     | ~~`git status` shows **no** unstaged build artefacts~~           |
| ~~0.2~~ | ~~`.editorconfig`~~         | ~~2-space YAML, 4-space TS, final newline~~                                              | ~~VS Code detects config automatically~~                         |
| ~~0.3~~ | ~~`CODEOWNERS`~~            | ~~`* @maldous` + domain folders~~                                                        | ~~Opening a PR assigns owners automatically~~                    |
| ~~0.4~~ | ~~Directory skeleton~~      | ~~`infra/ secrets/ backups/` sub-dirs created~~                                          | ~~`tree -dL 1` lists the dirs~~                                  |
| ~~0.5~~ | ~~**Compose split**~~       | ~~`docker-compose.base.yml`, `docker-compose.dev.yml`, `docker-compose.monitoring.yml`~~ | ~~`make dev` spins up the union without port conflicts~~         |
| ~~0.6~~ | ~~**CI stub**~~             | ~~`.github/workflows/ci.yml` (lint+unit), `reusable-compose.yml` (future)~~              | ~~Green run on clean checkout~~                                  |
| ~~0.7~~ | ~~**Husky + lint-staged**~~ | ~~Pre-commit runs `pnpm lint && pnpm format`~~                                           | ~~Commit with a lint error fails locally~~                       |
| ~~0.8~~ | ~~`.env.example`~~          | ~~Consolidated: `DOMAIN, LETSENCRYPT_EMAIL, OIDC_*, STRIPE_* ...`~~                      | ~~./setup.sh`copies →`.env`and`docker compose config` succeeds~~ |

---

## 1 Edge / Auth Hardening `P1 M`

| #       | Item                         | Deliverable                                                 | Acceptance test                                          |
| ------- | ---------------------------- | ----------------------------------------------------------- | -------------------------------------------------------- |
| ~~1.1~~ | ~~OIDC envs~~                | ~~Add vars listed in docs (see README)~~                    | ~~`grep OIDC_ .env` prints all~~                         |
| 1.2     | `services/kong/configure.sh` | Template `${OIDC_*}` plus Google & Apple IdPs               | Script exits 0; `kong reload` logs show plugin config    |
| 1.3     | `kong/kong.yml`              | Declarative config sections per IdP                         | `curl :8001/routes` shows `/auth/google` & `/auth/apple` |
| 1.4     | Health probe                 | Add `/status` route → `return 200`                          | Prometheus target up                                     |
| 1.5     | Flow validation              | `curl -I https://app.local/api/secure` redirects → Keycloak | Cypress E2E passes                                       |

**Code snippets**

`kong/kong.yml` (excerpt):

```yaml
plugins:
  - name: openid-connect
    config:
      issuer: ${OIDC_ISSUER}
      client_id: ${OIDC_CLIENT_ID}
      client_secret: ${OIDC_SECRET}
      scopes: ["openid", "email"]
      auth_methods:
        - name: google
          client_id: ${GOOGLE_CLIENT_ID}
          client_secret: ${GOOGLE_CLIENT_SECRET}
```

`Caddyfile` addition:

```caddyfile
@kong_openapi {
  path /api/*
}
reverse_proxy @kong_openapi kong:8000
```

---

## 2 Compose Refactor `P1 M`

| #   | Item         | Deliverable                                                    | Acceptance                                           |
| --- | ------------ | -------------------------------------------------------------- | ---------------------------------------------------- |
| 2.1 | Networks     | `frontend`, `backend`, `monitoring` declared                   | `docker network ls` lists three                      |
| 2.2 | Healthchecks | Add `CMD curl -f http://localhost/healthz` to every Dockerfile | `docker ps --format "{{.Status}}"` shows `(healthy)` |
| 2.3 | `make dev`   | Wrapper: `docker compose -f base -f dev -f monitoring up`      | CLI prints port map                                  |
| 2.4 | `make ports` | Bash helper parsing `docker compose ps`                        | Output includes service, internal, published         |
| 2.5 | Dev shortcut | Documented in root README                                      | Works from clean checkout                            |

---

## 3 CI Baseline `P1 S`

1. `ci.yml` steps: Checkout → Build **base** stack (`--abort-on-container-exit`) → `pnpm test` → **Trivy** scan fail-on-high.
2. Badge added to README (`build: passing`).
3. Self-hosted runner image caching (GitHub Actions cache layer).

Pass when `gh run watch` ends green.

---

## 4 Web Testing Seed `P2 S`

| #   | Item           | Details                                                             |
| --- | -------------- | ------------------------------------------------------------------- |
| 4.1 | Jest + RTL     | `pnpm add -D jest @testing-library/react @testing-library/jest-dom` |
| 4.2 | Config         | `jest.config.ts` with `testEnvironment: jsdom`                      |
| 4.3 | Example test   | `apps/web/__tests__/index.test.tsx` renders page                    |
| 4.4 | CI integration | Step `pnpm coverage` uploads artefact                               |

---

## 5 PostGraphile Adoption `P2 M`

| Step | Command / File | Expectation                                       |                                            |
| ---- | -------------- | ------------------------------------------------- | ------------------------------------------ |
| 5.1  | Remove Hasura  | Delete service from compose; update docs          | No container named `hasura_*`              |
| 5.2  | Add service    | `postgraphile` snippet already provided           | Port 5000 listens                          |
| 5.3  | Caddy route    | `reverse_proxy /graphql* postgraphile:5000`       | `curl /graphql` returns GraphQL Playground |
| 5.4  | Client update  | React Query hook points to `/graphql`             | Web loads data                             |
| 5.5  | DB Role        | Create DB role `postgraphile` with limited grants |                                            |

---

## 6 Frontend State + Styles `P2 M`

| #   | Item          | Deliverable                                                      |
| --- | ------------- | ---------------------------------------------------------------- |
| 6.1 | **RTK Query** | `core/ui/src/store.ts` with `configureStore`                     |
| 6.2 | **Tailwind**  | Central `tailwind.config.ts` referencing `core/ui/**/*.{ts,tsx}` |
| 6.3 | Decisions doc | `docs/frontend/state.md` comparing RTK vs Recoil                 |
| 6.4 | Feature slice | `features/profile/profile.slice.ts` with CRUD                    |
| 6.5 | Storybook     | Story for `<ProfileCard>` loads Tailwind styles                  |

---

## 7 Billing Loop v0 `P2 L`

| #   | Item                  | Deliverable                                               | Test                               |
| --- | --------------------- | --------------------------------------------------------- | ---------------------------------- |
| 7.1 | **catalog.xml**       | Units `api_call`, `storage_gb`, plan `starter-monthly`    | Upload via Kill Bill admin         |
| 7.2 | Usage instrumentation | Middleware increments BullMQ queue (`REDIS_URL`)          | Local call shows msg in queue      |
| 7.3 | `billing-worker`      | Worker consumes queue → Kill Bill `/usages` API           | Kill Bill invoice line item exists |
| 7.4 | Worker container      | Service added under `docker-compose.base.yml`             |                                    |
| 7.5 | Smoke E2E             | Cypress script: login → Hit `/items` → Check Kill Bill UI |                                    |

---

## 8 Stripe Sandbox Gateway `P2 L`

1. Deploy Kill Bill **Stripe** plugin (container `killbill-stripe`).
2. Map env: `STRIPE_SECRET, STRIPE_PUBLISHABLE` .
3. Execute `$0.01` checkout from `/account/billing`.
4. Validate `Succeeded` event in Stripe dashboard webhook & Kill Bill invoice.

---

## 9 Secrets Hardening `P1 S`

| Step | Action                                                            |
| ---- | ----------------------------------------------------------------- |
| 9.1  | `docker/secrets/{db,oidc,stripe}.txt` containing single value     |
| 9.2  | `docker-compose.*.yml` services reference `secrets:` block        |
| 9.3  | `docs/security.md` describes Vault path `secret/data/mindfield/*` |
| 9.4  | Git pre-commit prevents committing raw secrets (regex hook)       |

---

## 10 GitOps Bootstrap `P3 L`

| #    | Item             | Deliverable                                                          | Validation                             |
| ---- | ---------------- | -------------------------------------------------------------------- | -------------------------------------- |
| 10.1 | Terraform        | `infra/terraform/` AWS EC2 module generating output `k3s_server_ips` | `terraform apply` prints IPs           |
| 10.2 | `k3s` install    | Ansible role or cloud-init script                                    | `kubectl get nodes` ready              |
| 10.3 | `flux bootstrap` | Path `clusters/dev` in new repo **mindfield-infra**                  | `flux get kustomizations` shows synced |
| 10.4 | `helmfile.yaml`  | Charts: postgres, api, kong, keycloak, killbill                      | All pods ready                         |
| 10.5 | Sealed Secrets   | Controller + example secret (`hello.yaml`)                           |                                        |

---

## 11 Backup & DR `P3 M`

| #    | Item            | Deliverable                                                     |
| ---- | --------------- | --------------------------------------------------------------- |
| 11.1 | Velero + MinIO  | Helm release with bucket `velero-backups`                       |
| 11.2 | Schedule        | `daily-full` 02:00 UTC CRD                                      |
| 11.3 | Restic hook     | Pre-backup `pg_dumpall` script                                  |
| 11.4 | Encrypt         | `age` encryption script in `backups/restore-scripts/encrypt.sh` |
| 11.5 | Restore runbook | `docs/runbook.md` step-by-step                                  |
| 11.6 | CI DR test      | Kind cluster → `make restore` → health 200                      |

---

## 12 Observability & Alerts `P3 M`

| Item           | Detail                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------- |
| Dashboards     | API latency, Kong 5xx, billing-queue length (Grafana JSON in `services/grafana/dashboards`) |
| Alertmanager   | Rule: queue >100 for 10 m → Slack                                                           |
| Loki retention | `retention_period = 14d`                                                                    |
| Sentry OSS     | `SENTRY_DSN` env; errors visible                                                            |

---

## 13 Feature Flags / Analytics `P3 M`

- Deploy **PostHog** (Helm chart).
- Wire React `useFeature` hook around experimental UI.
- Grafana panel “Feature adoption”.

---

## 14 Customer Portal MVP `P3 L`

| Feature         | Implementation                                                           |
| --------------- | ------------------------------------------------------------------------ |
| Usage graph     | React + @tanstack/react-charts querying PostGraphile `usage_by_day` view |
| Invoice list    | Kill Bill REST → SSR in Next.js                                          |
| Stripe checkout | `/api/pay/checkout` Lambda route → Stripe SDK                            |
| Auth            | Re-use Keycloak session cookie; fetch access-token silent                |

---

## 15 Performance Baseline `P3 S`

1. `performance/k6-load.js` hitting `/api/questions` with 100 VU.
2. Save p95 latency into `docs/perf-baseline.md`.
3. Grafana panel “API p95 over time”.

---

## 16 Mobile (Expo) Readiness `P3 M`

| Step        | Detail                                                        |
| ----------- | ------------------------------------------------------------- |
| Dockerfile  | `dockerfiles/expo.Dockerfile` from notes                      |
| Compose svc | Expose ports 19000-19002; depends_on: \[api,keycloak]         |
| OIDC flow   | Expo AuthSession with Keycloak public client                  |
| OTA builds  | `eas.json` profiles; GH Actions `eas build --non-interactive` |

---

## 17 Enterprise Enhancements (back-burner)

- HashiCorp Vault injector
- Istio + mTLS mesh
- Kubecost, Kiali, OPA Gatekeeper&#x20;
- ChartMuseum / Harbor marketplace

---

## Completion Criteria (Definition of Done)

1. All check-boxes ticked in ascending order.
2. `make prod` (compose) **or** `flux reconcile` (k3s) produces a green, healthy stack reachable at `https://{DOMAIN}` end-to-end.
3. Back-up and restore workflow proven on a clean VM.
4. Documentation (`docs/`) reflects every operational procedure.

---

> **Tip** Run `grep -R "\[ \]" README.todo.md` to list open tasks.
