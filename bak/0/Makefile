.PHONY: help setup install build base-image start prod test lint format type-check logs stop clean docker-config reset sonar tmp
.DEFAULT_GOAL := help

export COMPOSE_DOCKER_CLI_BUILD=1
export COMPOSE_BAKE=1
export NODE_MAJOR ?= $(shell cut -d. -f1 .node-version)
export REGISTRY_CACHE ?= localhost:5001/mindfield-cache
export DOCKER_COMPOSE = --project-directory . -f docker/docker-compose.api.yml -f docker/docker-compose.auth.yml -f docker/docker-compose.base.yml -f docker/docker-compose.core.yml -f docker/docker-compose.dev.yml -f docker/docker-compose.infra.yml -f docker/docker-compose.monitor.yml -f docker/docker-compose.process.yml -f docker/docker-compose.search.yml -f docker/docker-compose.storage.yml

help:
	@echo "make setup           - Initial project setup"
	@echo "make install         - pnpm ci for all workspaces"
	@echo "make build           - pnpm run build (monorepo)"
	@echo "make base-image      - Build & push base-deps image"
	@echo "make docker-config   - Verify Docker daemon config"
	@echo "make start           - Build & start full dev stack via Caddy"
	@echo "make start-dev       - Build & start dev stack with exposed ports"
	@echo "make prod            - Alias for start (production mode)"
	@echo "make test            - Run all tests"
	@echo "make lint            - ESLint across workspace"
	@echo "make format          - Code formatting"
	@echo "make tidy            - Package formatting"
	@echo "make type-check      - TypeScript checks"
	@echo "make logs            - Tail docker logs"
	@echo "make stop            - Stop all services"
	@echo "make stop-dev        - Stop dev stack only"
	@echo "make clean           - Tear down & prune images"
	@echo "make reset           - Full reset (prune volumes, clean, etc.)"
	@echo "make sonar           - Run SonarQube analysis"
	@echo "make all             - Reset, setup & start"

setup: ; ./setup.sh
install: ; if [ -d node_modules ]; then pnpm install --frozen-lockfile; else pnpm install; fi
build: ; pnpm turbo run build build-storybook
test: ; pnpm turbo run test -- --passWithNoTests --coverage --all
lint: ; pnpm turbo run lint
format: ; pnpm format
tidy: ; pnpm tidy
type-check: ; pnpm turbo run type-check
logs: ; docker compose ${DOCKER_COMPOSE} logs -f

start: base-image build ; docker compose ${DOCKER_COMPOSE} build --no-cache --pull --parallel && docker compose ${DOCKER_COMPOSE} up -d --remove-orphans
stop: ; touch .env && docker compose ${DOCKER_COMPOSE} down

start-dev: base-image build ; docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml build --no-cache --pull --parallel && docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml up -d --remove-orphans
stop-dev: ; docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml down

all: reset setup install start

sonar:
	if [ ! -f .env ]; then touch .env; fi; \
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

docker-test: ; docker compose ${DOCKER_COMPOSE} config
docker-config:
	if [ ! jq -e '.features.buildkit == true and .features["containerd-snapshotter"] == true and (.["registry-mirrors"] | index("http://localhost:5000"))' /etc/docker/daemon.json > /dev/null 2>&1 ]; then \
	echo 'Docker: enable buildkit, containerd-snapshotter & registry-mirrors (caching)'; \
	exit 1; \
	fi

base-image: docker-config
	docker buildx build \
	--push \
	--compress \
	--progress=plain \
	--cache-from=type=registry,ref=$(REGISTRY_CACHE) \
	--cache-to=type=registry,ref=$(REGISTRY_CACHE),mode=max,oci-mediatypes=true \
	--build-arg NODE_MAJOR=$(NODE_MAJOR) \
	-f docker/Dockerfile.base \
	-t $(REGISTRY_CACHE)/base-deps:$(NODE_MAJOR) .

clean: stop
	pnpm turbo run clean || true
	docker image prune -af || true
	docker buildx prune -af || true
	rm -rf .buildx_cache || true
	mkdir -p .buildx_cache || true

reset: clean
	docker system prune -a --volumes -f || true
	docker volume ls -q | grep '^mindfield' | xargs -r docker volume rm || true
	git clean -xfd || true
