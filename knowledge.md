# MicroCeph + MinIO Setup

## Overview
This project uses MicroCeph for distributed storage with MinIO object storage on MicroK8s.

## Setup Process
1. **MicroCeph**: Creates 3x 100GB loop devices for Ceph storage
2. **Rook-Ceph**: Connects MicroCeph to MicroK8s via external cluster
3. **MinIO**: Uses `ceph-rbd` storage class for persistent volumes

## Key Commands
- `make microceph`: Sets up MicroCeph with loop devices and connects to MicroK8s
- `make minio`: Deploys MinIO operator and tenant using Ceph storage

## Storage Classes
- `ceph-rbd`: Primary storage class for Ceph RBD volumes
- `microk8s-hostpath`: Default hostpath storage (not used for production)

## Troubleshooting
- If MinIO PVCs remain pending, restart CSI drivers:
  ```bash
  microk8s kubectl delete pods -n rook-ceph -l app=csi-rbdplugin
  microk8s kubectl delete pods -n rook-ceph -l app=csi-rbdplugin-provisioner
  ```
- CSI driver restart is included in `make microceph` for reproducibility

## Verification
```bash
# Check storage classes
microk8s kubectl get storageclass

# Check MinIO status
microk8s kubectl get pods,pvc -n minio

# Check MicroCeph status
sudo microceph disk list
```

## Architecture
- **MicroCeph**: Provides Ceph cluster with 4 OSDs (1 original + 3 loop devices)
- **Rook-Ceph**: External cluster integration with CSI drivers
- **MinIO**: Object storage with 4x 100GB volumes per tenant
- **PostgreSQL**: Primary database with 50GB persistent storage
- **Redis**: Cache/session store with 8GB persistent storage
- **PostGraphile**: GraphQL API layer for PostgreSQL

## Datastores
- All datastores use `ceph-rbd` storage class for persistence
- PostgreSQL: Configured with extensions (uuid-ossp, pgcrypto, citext)
- Redis: AOF persistence enabled with LRU eviction policy
- Network policies allow access from apps/auth/temporal namespaces

## Authentication & Gateway
- **Keycloak**: OIDC provider using external PostgreSQL database
- **Kong Gateway**: API Gateway with OIDC authentication and rate limiting
- **Gateway API**: HTTPRoutes for all services with OIDC protection
- **Rate Limiting**: Global 100 req/min per IP via Kong plugin
- **TLS**: Wildcard certificate (*.aldous.info) via cert-manager

## Public URLs (all require Keycloak OIDC login)
- alertmanager.aldous.info → observability/alertmanager:9093
- grafana.aldous.info → observability/kube-prometheus-stack-grafana:80
- keycloak.aldous.info → auth/keycloak:8080 (no OIDC required)
- kuma.aldous.info → observability/uptime-kuma:3001
- mailhog.aldous.info → devtools/mailhog:8025
- opensearch.aldous.info → search/opensearch-cluster-master:9200
- pgadmin.aldous.info → data/pgadmin4:80
- prometheus.aldous.info → observability/kube-prometheus-stack-prometheus:9090
- sonarqube.aldous.info → devtools/sonarqube:9000
- temporal.aldous.info → temporal/temporal-web:8080
- web.aldous.info → apps/web:3000
