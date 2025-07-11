.PHONY: help setup install build base-image start prod test lint format type-check logs stop clean docker-config reset sonar tmp
.DEFAULT_GOAL := help

export COMPOSE_DOCKER_CLI_BUILD=1
export COMPOSE_BAKE=1
export NODE_MAJOR ?= $(shell cut -d. -f1 .node-version)
export REGISTRY_CACHE ?= localhost:5001/mindfield-cache

help:
	@echo "make setup           - Initial project setup"
	@echo "make install         - pnpm ci for all workspaces"
	@echo "make build           - pnpm run build (monorepo)"
	@echo "make base-image      - Build & push base-deps image"
	@echo "make docker-config   - Verify Docker daemon config"
	@echo "make start           - Build & start full dev stack via Caddy"
	@echo "make dev             - Build & start dev stack with exposed ports"
	@echo "make prod            - Alias for start (production mode)"
	@echo "make test            - Run all tests"
	@echo "make lint            - ESLint across workspace"
	@echo "make format          - Code formatting"
	@echo "make tidy            - Package formatting"
	@echo "make type-check      - TypeScript checks"
	@echo "make logs            - Tail docker logs"
	@echo "make stop            - Stop all services"
	@echo "make stop-dev        - Stop dev stack only"
	@echo "make restart         - Stop and start all services"
	@echo "make restart-dev     - Stop and start dev stack only"
	@echo "make clean           - Tear down & prune images"
	@echo "make reset           - Full reset (prune volumes, clean, etc.)"
	@echo "make sonar           - Run SonarQube analysis"
	@echo "make ports           - Show all exposed development ports"
	@echo "make all             - Reset, setup & start"

setup: ; @./setup.sh
install: ; @if [ -d node_modules ]; then pnpm install --frozen-lockfile; else pnpm install; fi
build: ; @pnpm turbo run build build-storybook
test: ; @pnpm turbo run test -- --passWithNoTests --coverage --all
lint: ; @pnpm turbo run lint
format: ; @pnpm format
tidy: ; @pnpm tidy
type-check: ; @pnpm turbo run type-check
logs: ; @docker compose logs -f
stop: ; @docker compose down
start: install build base-image ; @docker compose build --pull --parallel && docker compose up -d --remove-orphans
dev: install build base-image ; @docker compose -f docker-compose.yml -f docker-compose.dev.yml build --pull --parallel && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --remove-orphans
prod: start
restart: stop start
restart-dev: stop dev
stop-dev: ; @docker compose -f docker-compose.yml -f docker-compose.dev.yml down
all: reset setup start

ports:
	@echo "Development Ports (make dev):"
	@echo "  Web App:           http://localhost:3000"
	@echo "  API:               http://localhost:3001"
	@echo "  Submission:        http://localhost:3002"
	@echo "  Transform:         http://localhost:3003"
	@echo "  Render:            http://localhost:3004"
	@echo "  Redaction:         http://localhost:3005"
	@echo "  GrapesJS:          http://localhost:3006"
	@echo "  Grafana:           http://localhost:3007"
	@echo "  PostgREST:         http://localhost:3008"
	@echo "  Hasura:            http://localhost:3009"
	@echo "  PostGraphile:      http://localhost:3010"
	@echo "  PgAdmin:           http://localhost:3011"
	@echo "  Prisma Studio:     http://localhost:3012"
	@echo "  Swagger UI:        http://localhost:3013"
	@echo "  ReDoc:             http://localhost:3014"
	@echo "  Storybook:         http://localhost:3015"
	@echo "  SonarQube:         http://localhost:3016"
	@echo "  Keycloak:          http://localhost:3017"
	@echo "  Uptime Kuma:       http://localhost:3018"
	@echo "  MailHog Web:       http://localhost:8025"
	@echo "  MailHog SMTP:      localhost:2025"
	@echo "  MinIO API:         http://localhost:9000"
	@echo "  MinIO Console:     http://localhost:9001"
	@echo "  Prometheus:        http://localhost:9090"
	@echo "  Node Exporter:     http://localhost:9100"
	@echo "  Loki:              http://localhost:3100"
	@echo "  OpenSearch:        http://localhost:9200"
	@echo "  OpenSearch Dash:   http://localhost:5601"
	@echo "  RabbitMQ Mgmt:     http://localhost:15672"
	@echo "  Kong Proxy:        http://localhost:8002"
	@echo "  Kong Admin:        http://localhost:8003"
	@echo "  Jaeger:            http://localhost:16686"
	@echo "  Alertmanager:      http://localhost:9093"
	@echo "  Blackbox Export:   http://localhost:9115"
	@echo "  Trivy:             http://localhost:8004"
	@echo "  Step CA:           https://localhost:9443"
	@echo "  OTEL Collector:    http://localhost:8888"
	@echo "  MkDocs:            http://localhost:8001"
	@echo ""
	@echo "Production (make start/prod): All via Caddy on ports 80/443"

sonar:
	@if [ ! -f .env ]; then touch .env; fi; \
	if ! grep -q "SONAR_TOKEN" .env; then \
        token=$$(curl -s -u admin:admin -X POST 'http://localhost:3016/api/user_tokens/generate' -d name=admin | jq -r '.token'); \
        echo "SONAR_TOKEN=$$token" >> .env; \
	fi; \
        rm -f sonar.json; \
	bash -c 'source .env && sonar -Dsonar.host.url=http://localhost:3016 -Dsonar.login=$${SONAR_TOKEN} -Dsonar.projectKey=mindfield -Dsonar.exclusions=caddy/**'; \
	bash -c 'source .env && for ((p=1;;p++)); do \
        r=$$(curl -s -u $${SONAR_TOKEN}: "http://localhost:3016/api/issues/search?branch=main&ps=500&p=$$p"); \
        if [ $$(jq -e ".issues|length" <<<"$${r}") -eq 0 ]; then break; fi; \
        printf "%s\n" "$$r"; \
	done | jq -s "map(.issues) | add // []" > sonar.json; \
	echo ""; \
	jq -r ".[] | select(.issueStatus != \"FIXED\") | \"\( (.component | split(\":\")[1])):\(.line) \(.message)\"" sonar.json'

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

clean: setup stop
	@pnpm turbo run clean || true
	@docker image prune -af || true
	@docker buildx prune -af || true
	@rm -rf .buildx_cache || true
	@mkdir -p .buildx_cache || true

reset: clean
	@docker system prune -a --volumes -f || true
	@docker volume ls -q | grep '^mindfield' | xargs -r docker volume rm || true
	@git clean -xfd || true
