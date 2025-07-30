#!/bin/bash
set -euo pipefail

echo "Building custom Kong image with oidcify plugin..."

# Build the custom Kong image
docker build -t mindfield/kong-oidc:latest -f infra/docker/Dockerfile.kong .

echo "Kong oidcify image built successfully!"
echo "To deploy:"
echo "1. Run: make keycloak"
echo "2. Run: make kong"
echo "3. Test authentication at https://postgraphile.aldous.info"

echo ""
echo "Note: You may need to push the image to a registry if using a remote cluster:"
echo "docker tag mindfield/kong-oidc:latest your-registry/mindfield/kong-oidc:latest"
echo "docker push your-registry/mindfield/kong-oidc:latest"