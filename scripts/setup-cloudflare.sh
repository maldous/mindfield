#!/bin/bash
set -euo pipefail

# Setup Cloudflare API token for External Secrets Operator
# This creates the source secret that ESO will read from

echo "🔐 Setting up Cloudflare API token for cert-manager DNS-01"

# Check if CLOUDFLARE_API_TOKEN is set
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
    echo "❌ CLOUDFLARE_API_TOKEN environment variable is required"
    echo "Please set it to your Cloudflare API token with Zone:Read, DNS:Edit permissions"
    exit 1
fi

# Create namespace if it doesn't exist
kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -

# Create the source secret for ESO
kubectl create secret generic cloudflare-api-token-source \
    --namespace external-secrets-system \
    --from-literal=token="${CLOUDFLARE_API_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Cloudflare API token source secret created"
echo "ESO will now be able to create the cert-manager secret from this source"

# Apply the ExternalSecret to create the cert-manager secret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: k8s-secrets-store
    kind: ClusterSecretStore
  target:
    name: cloudflare-api-token
    creationPolicy: Owner
  data:
  - secretKey: token
    remoteRef:
      key: cloudflare-api-token-source
      property: token
EOF

echo "✅ ExternalSecret created - cert-manager will now have access to Cloudflare API token"