# MindField – **Full-Stack OSS Platform**

---

## 0. Table of Contents
1. [High-Level Overview](#1-high-level-overview)
2. [System Architecture](#2-system-architecture)
3. [Repository Layout](#3-repository-layout)
4. [Prerequisites](#4-prerequisites)
5. [Local & Production Setup](#5-local--production-setup)
6. [Service Catalogue](#6-service-catalogue)
7. [Make & Docker-Compose Workflow](#7-make--docker-compose-workflow)
8. [Ordered Task Roadmap](#8-ordered-task-roadmap)
9. [Operations Guide](#9-operations-guide)
10. [Security Hardening](#10-security-hardening)
11. [Disaster Recovery & Back-ups](#11-disaster-recovery--back-ups)
12. [Future Enhancements](#12-future-enhancements)
13. [License](#13-license)

---

## 1. High-Level Overview
All services run in Docker containers and communicate through
Kong 3.x acting as the API edge behind a TLS-terminating Caddy reverse proxy.
Keycloak provides single sign-on. Observability is handled by the
Prometheus / Grafana / Loki / Jaeger stack. Billing is powered by
Kill Bill, backed by PostgreSQL. Every component is **open-source and
self-hostable** – no paid SaaS dependencies.

---

## 2. System Architecture
```text
                       ┌────────────────────────┐
Internet ──► HTTPS ───►│        Caddy           │◄─ Let's Encrypt
                       │  (TLS + vHost router)  │
                       └────────▲───────────────┘
                                │
                                │ /api/*
                                ▼
                       ┌────────────────────────┐
                       │         Kong           │
                       │  (OIDC, Rate-Limit,    │
                       │   Transform, Metrics)  │
                       └────────▲───────────────┘
                                │ JWT
             ┌──────────────────┼───────────────┐
             │                  │               │
             ▼                  ▼               ▼
    ┌──────────────┐   ┌────────────────┐  ┌──────────────┐
    │ services/api │   │  Kill Bill     │  │  Postgraphile│
    │ NestJS REST  │   │  Billing       │  │  GraphQL     │
    └──────────────┘   └────────────────┘  └──────────────┘
             │               │                     │
             ▼               │                     ▼
    ┌──────────────┐         │            ┌────────────────┐
    │ PostgreSQL   │◄────────┴────────────┤   PgBouncer    │
    └──────────────┘                      └────────────────┘
````

Full description in *docs/architecture.md*.

---

## 3. Repository Layout

```text
mindfield/
├── apps/                 # Next.js web + Expo mobile
├── core/                 # Shared business & UI packages
├── services/             # API, workers, docs, etc.
├── infra/                # k3s, Helmfile, Terraform, Flux
├── dockerfiles/          # One Dockerfile per service
├── docs/                 # MkDocs site (served by mkdocs svc)
├── scripts/              # Bash helpers & scaffolding
├── backups/              # Velero schedules & scripts
├── secrets-templates/    # *.env.example & Vault policies
└── Makefile              # Dev & CI shortcuts
```

---

## 4. Prerequisites

* **Docker 20.10+** & **Docker Compose v2**
* **Git** and a GitHub account (optional for GitOps)
* Open ports **80/443** (production)
* DNS A-records for `*.aldous.info` pointing at the host
* *Optional / Production*: 4 vCPU, 8 GiB RAM VM or better
  (k3s, FluxCD, Velero, etc.)

---

## 5. Local & Production Setup

### 5.1 One-Liner Quick Start (dev mode)

```bash
git clone https://github.com/you/mindfield.git
cd mindfield
./setup.sh        # creates .env with sane defaults
make dev          # base + dev overrides + monitoring
open http://localhost:3000   # Next.js web
```

### 5.2 Production on a Single Host

```bash
cp .env.example .env     # fill DOMAIN, LETSENCRYPT_EMAIL, passwords
make start               # base compose via Caddy + HTTPS
```

### 5.3 GitOps (k3s + Flux)

```bash
# Provision Ubuntu VM, then:
curl -sfL https://get.k3s.io | sh -
flux bootstrap github \
  --owner=you --repository=mindfield-infra \
  --path=clusters/dev
```

---

## 6. Service Catalogue

* **Edge & Auth** – Caddy, Kong, Keycloak
* **Core** – `services/api`, BullMQ workers, Postgraphile
* **Data Stores** – PostgreSQL 15 + PgBouncer, Redis 7, MinIO, OpenSearch
* **Privacy** – Presidio (analyzer, anonymizer, image-redactor)
* **Billing** – Kill Bill + Stripe plugin
* **Observability** – Prometheus, Grafana, Loki, Jaeger, Alertmanager
* **Developer Tools** – Storybook, Swagger-UI, ReDoc, SonarQube, PgAdmin,
  Redis-Insight, Mailhog, MkDocs

*All UI containers are fronted by Caddy under `https://{service}.{DOMAIN}` when
authenticated; internal-only services expose no public ports.*

---

## 7. Make & Docker-Compose Workflow

```bash
make help        # list every target
make dev         # base + dev + monitoring overrides
make start       # production-composition via Caddy TLS
make stop        # stop & keep volumes
make reset       # DANGER – remove volumes & images
make logs        # follow all service logs
make test        # pnpm test across monorepo
make lint        # eslint + prettier
make ports       # print local port map (dev mode)
```

Compose layering strategy:

| File                            | Purpose                                                    |
| ------------------------------- | ---------------------------------------------------------- |
| `docker-compose.base.yml`       | Core runtime (api, postgres, redis, kong, keycloak, caddy) |
| `docker-compose.dev.yml`        | Dev-only extras (mailhog, minio, mkdocs, presidio)         |
| `docker-compose.monitoring.yml` | Prometheus, Grafana, Loki, etc.                            |

Health-checks are applied to every long-running container.

---

## 8. Ordered Task Roadmap

> **Must be executed sequentially** – each phase unblocks the next.

| #      | Task Group                      | Priority | Outcome                                        |
| ------ | ------------------------------- | -------- | ---------------------------------------------- |
| **0**  | **Repo & Scaffolding Baseline** | **P1 S** | Git hygiene, split compose, CI stub            |
| **1**  | **Edge / Auth Hardening**       | **P1 M** | Kong OIDC plugin, social IdPs, flow validation |
| **2**  | **Compose Refactor**            | **P1 M** | Layered \*.yml, health-checks, `make dev`      |
| **3**  | **CI Baseline**                 | **P1 S** | GitHub Actions lint+test+Trivy                 |
| **4**  | **Web Testing Seed**            | **P2 S** | Jest + RTL smoke test in apps/web              |
| **5**  | **Postgraphile Adoption**       | **P2 M** | Replace Hasura, GraphQL reverse proxy          |
| **6**  | **Frontend State/Styles**       | **P2 M** | RTK Query, Tailwind shared config              |
| **7**  | **Billing Loop v0**             | **P2 L** | Kill Bill units, BullMQ usage worker           |
| **8**  | **Stripe Sandbox Gateway**      | **P2 L** | Kill Bill Stripe plugin, \$0.01 test txn       |
| **9**  | **Secrets Hardening**           | **P1 S** | Docker Secrets / Vault, remove plain envs      |
| **10** | **GitOps Bootstrap**            | **P3 L** | k3s, FluxCD, Helmfile skeleton                 |
| **11** | **Backup & DR**                 | **P3 M** | Velero daily schedule, runbook                 |
| **12** | **Observability & Alerts**      | **P3 M** | Grafana dashboards, alert rules                |
| **13** | **Feature Flags / Analytics**   | **P3 M** | PostHog, Unleash                               |
| **14** | **Customer Portal MVP**         | **P3 L** | Next.js `/account` invoices + usage            |
| **15** | **Performance Baseline**        | **P3 S** | k6 p95 latency test, perf-baseline doc         |

Detailed check-boxes for every sub-task live in
`README.todo.md` (generated from this table).

---

## 9. Operations Guide

### 9.1 Back-ups

* **PostgreSQL** – nightly `pg_dump` via `backup` container
* **MinIO** – bucket replication rule to secondary disk
* **Velero** – cluster snapshot at 02:00 UTC
  Back-ups land in `backups/` and are encrypted with **age**.

### 9.2 Monitoring

* Grafana dashboards auto-provisioned from `services/grafana/dashboards/`
* Prometheus scrapes `/metrics` on every service
* Alertmanager pages when:

  * API p95 > 750 ms for 10 min
  * billing-usage queue length > 100 for 10 min
* Loki retains 14 days logs; Promtail tails `/var/log/containers/*.log`.

### 9.3 Common Commands

```bash
docker compose exec postgres psql -U mindfield
docker compose exec kong curl -s localhost:8001/services | jq
docker compose restart api
docker compose down -v   # Wipes data – be careful!
```

---

## 10. Security Hardening

* All ingress on TLS – automatic renewal via Caddy ACME
* OIDC everywhere: Caddy ► Kong ► Keycloak ► services
* Secrets stored in Docker Secrets / Vault
* Trivy scans in CI – build fails on **HIGH** vulnerabilities
* RBAC enforced in Keycloak; Kong OPA plugin gate-keeps admin routes.

---

## 11. Disaster Recovery & Back-ups

1. **Detect failure** – Loki alert / Pingdom outage
2. **Provision new VM / cluster** – `make deploy` (Terraform + Flux)
3. **Restore** –

   ```bash
   make restore                 # decrypt + velero restore + SQL import
   ```
4. **Validate** – health probe `GET /healthz` returns 200
5. **Post-mortem** – fill template in `docs/runbook.md`.

---

## 12. Future Enhancements

* HashiCorp Vault side-car injector
* Istio service mesh with mTLS for east-west traffic
* Blue/Green deploys via Argo-Rollouts
* Kubecost show-back & budget alerts
* Marketplace of Helm extensions (ChartMuseum)

