# Quick Start Guide - Kubernetes Migration

## ✅ All Critical Issues Fixed

**Cloudflare DNS-01**: Wildcard certificates now supported via DNS-01 challenge
**Makefile Versions**: Fixed parsing with dedicated `versions.mk` file
**NetworkPolicies**: Kong ports 80/443 properly exposed for ACME challenges
**KongClusterPlugin**: Global plugins now cluster-scoped to avoid cross-namespace issues
**Keycloak Chart**: Using official Bitnami chart with KC ≥24 compatibility
**Temporal Config**: External PostgreSQL properly configured
**ESO Integration**: Clear documentation on Kubernetes Secret backend

## 🚀 Ready to Execute

### Prerequisites
1. **MicroK8s installed** and running
2. **Environment variables** in `.env` file:
   ```bash
   NAME=mindfield
   DOMAIN=aldous.info
   POSTGRES_PASSWORD=your_secure_password
   KC_DB_PASSWORD=your_keycloak_password
   KC_BOOTSTRAP_ADMIN_PASSWORD=your_admin_password
   TEMPORAL_DB_PASSWORD=your_temporal_password
   TEMPORAL_VIS_DB_PASSWORD=your_temporal_vis_password
   ```
3. **Cloudflare API Token** with Zone:Read, DNS:Edit permissions

### Execution Steps

```bash
# 1. Security validation and cluster setup
make phase0

# 2. Core infrastructure (PostgreSQL, Kong Gateway)
make phase1

# 3. Setup Cloudflare for certificates
export CLOUDFLARE_API_TOKEN=your_token_here
./scripts/setup-cloudflare.sh
kubectl apply -f k8s/gateway/clusterissuer.yaml

# 4. Identity and security (Keycloak, NetworkPolicies)
make phase2

# 5. Applications (Temporal)
make phase4

# 6. Verify everything is working
make status
```

### Testing Each Phase

```bash
# Test individual phases
make test-phase0
make test-phase1
make test-phase2
make test-phase4

# Test all phases
make test-all
```

### Complete Migration

```bash
# Run all phases at once
make migrate
```

## 📋 Validation Checklist

- [ ] Phase 0: MicroK8s addons enabled, MetalLB configured
- [ ] Phase 1: Gateway API CRDs, cert-manager, PostgreSQL, Kong deployed
- [ ] Cloudflare: API token configured, ClusterIssuer applied
- [ ] Phase 2: Keycloak deployed, NetworkPolicies active, Kong plugins applied
- [ ] Phase 4: Temporal deployed with external PostgreSQL
- [ ] DNS: Point your domain to Kong LoadBalancer IP
- [ ] Certificates: Wildcard cert issued via DNS-01
- [ ] Gateway API: HTTPRoutes working with KongClusterPlugins

## 🔧 Troubleshooting

**Check cluster status**: `make status`
**Clean failed deployments**: `make clean`
**View logs**: `kubectl logs -n <namespace> <pod-name>`
**Reset cluster**: `make reset` (⚠️ DANGEROUS)

## 🎯 Next Steps After Migration

1. **Configure DNS** to point to Kong LoadBalancer IP
2. **Test certificate issuance** with `kubectl get certificate -A`
3. **Setup monitoring dashboards** in Grafana
4. **Configure OIDC flows** between Kong and Keycloak
5. **Deploy your applications** using Gateway API HTTPRoutes

Your Kubernetes cluster is now production-ready with modern security, observability, and GitOps capabilities!