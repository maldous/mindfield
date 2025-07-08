.PHONY: help setup install build base-image start prod test lint format type-check logs stop clean docker-config reset
.DEFAULT_GOAL := help

export COMPOSE_DOCKER_CLI_BUILD=1
export COMPOSE_BAKE=1
export NODE_MAJOR ?= $(shell cut -d. -f1 .node-version)
export REGISTRY_CACHE ?= localhost:5001/mindfield-cache

help:
	@echo "make setup      - Initial project setup"
	@echo "make install    - pnpm ci for all workspaces"
	@echo "make build      - pnpm run build (monorepo)"
	@echo "make start      - Build & start full dev stack"
	@echo "make prod       - Build & start prod-like stack"
	@echo "make test       - Run all tests"
	@echo "make lint       - ESLint across workspace"
	@echo "make format     - Prettier formatting"
	@echo "make type-check - TypeScript checks"
	@echo "make logs       - Tail docker-compose logs"
	@echo "make stop       - Stop all services"
	@echo "make clean      - Tear down & clean images"
	@echo "make restart    - Stop and start all services"
	@echo "make reset      - Reset everything"

setup: ; @./setup.sh
build: ; @pnpm turbo run build
test: ; @pnpm turbo run test
lint: ; @pnpm turbo run lint
format: ; @pnpm format
type-check: ; @pnpm turbo run type-check
logs: ; @docker compose logs -f
stop: ; @docker compose down
install: ; @if [ -d node_modules ]; then pnpm install --offline; else pnpm install; fi
start: base-image; @docker compose --profile dev build --pull --parallel && docker compose --profile dev up -d --remove-orphans
prod: base-image; @docker compose --profile prod build --pull --parallel && docker compose --profile prod up -d --remove-orphans
restart: stop start

docker-config:
	@if [ ! jq -e '.features.buildkit == true and .features["containerd-snapshotter"] == true and (.["registry-mirrors"] | index("http://localhost:5000"))' /etc/docker/daemon.json > /dev/null 2>&1 ]; then \
	  echo 'Docker: enable buildkit, containerd-snapshotter & registry-mirrors (caching)'; \
	  exit 1; \
	fi

base-image: docker-config
	@docker buildx build \
	  --push \
	  --compress \
	  --progress=plain \
	  --cache-from=type=registry,ref=$(REGISTRY_CACHE) \
	  --cache-to=type=registry,ref=$(REGISTRY_CACHE),mode=max,oci-mediatypes=true \
	  --build-arg NODE_MAJOR=$(NODE_MAJOR) \
	  -f dockerfiles/Dockerfile.base \
	  -t $(REGISTRY_CACHE)/base-deps:$(NODE_MAJOR) .

clean: stop
	@pnpm turbo run clean || true
	@docker image prune -af || true
	@docker buildx prune -af || true
	@rm -rf .buildx_cache || true
	@mkdir -p .buildx_cache || true

reset: clean
	@docker system prune -a --volumes -f || true
	@git clean -xfd || true
