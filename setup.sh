#!/bin/bash
set -e

NODE_VERSION=$(cat .node-version)

if ! command -v volta &> /dev/null; then
  echo "📥 Installing Volta (node/tool manager)…"
  curl https://get.volta.sh | bash
  export VOLTA_HOME="$HOME/.volta"
  export PATH="$VOLTA_HOME/bin:$PATH"
fi

export VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
export PATH="$VOLTA_HOME/bin:$PATH"

volta install "node@$NODE_VERSION"
volta install "pnpm@latest"
volta install "turbo@latest"

if ! command -v docker &> /dev/null; then
  echo "Docker not found; please install Docker manually."
  exit 1
fi
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  echo "Docker Compose not found; please install Docker Compose manually."
  exit 1
fi

mkdir -p .buildx_cache
mkdir -p backups

if [ ! -f .env.local ]; then
    cat > .env.local << EOF
# MindField Local Development Environment
NODE_ENV=development
DATABASE_URL=postgresql://mindfield:mindfield_dev_password@localhost:5432/mindfield
REDIS_URL=redis://localhost:6379
S3_ENDPOINT=http://localhost:9000
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin123
S3_BUCKET=mindfield-uploads
JWT_SECRET=dev-jwt-secret-change-in-production
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=mindfield
KEYCLOAK_CLIENT_ID=mindfield-web
EOF
fi

docker rm -f registry-proxy 2>/dev/null || true
docker run -d \
  --name registry-proxy \
  --restart=always \
  -p 5000:5000 \
  -v registry_proxy_data:/var/lib/registry \
  -v "$PWD/registry.yml":/etc/docker/registry/config.yml:ro \
  registry:2

docker volume create registry_write_data >/dev/null 2>&1 || true

docker rm -f registry-write 2>/dev/null || true
docker run -d \
  --name registry-write \
  --restart=always \
  -p 5001:5000 \
  -v registry_write_data:/var/lib/registry \
  registry:2
