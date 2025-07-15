.PHONY: setup env reset docker install help
.DEFAULT_GOAL := help

.ONESHELL:
SHELL := bash

ifneq (,$(wildcard .env))
	include .env
	export
endif

setup:
	@if [ ! -f .env ]; then
		if [ -f .enc ]; then
			echo -n "PASSWORD: "; stty -echo; read PASSWORD; stty echo; echo
			TMP_ENV="$$(mktemp)"
			if openssl enc -d -aes-256-cbc -pbkdf2 -in .enc -out "$$TMP_ENV" -k "$$PASSWORD"; then
				mv "$$TMP_ENV" .env
			else
				echo "WRONG PASSWORD!"
				rm -f "$$TMP_ENV"
				exit 1
			fi
		else
			NAME="$$(basename "$$PWD")"

			#PASSWORD="$$(openssl rand -hex 16)"
			#POSTGRES_PASSWORD="$$(openssl rand -hex 16)"
			#MINIO_ROOT_PASSWORD="$$(openssl rand -hex 16)"
			#PGADMIN_DEFAULT_PASSWORD="$$(openssl rand -hex 16)"
			#KC_BOOTSTRAP_ADMIN_PASSWORD="$$(openssl rand -hex 16)"
			#KC_DB_PASSWORD="$$(openssl rand -hex 16)"
			#KONG_PG_PASSWORD="$$(openssl rand -hex 16)"
			#KC_SECRET="$$(openssl rand -hex 32)"
			#echo "NAME=$$NAME" >> .env
			#echo "DOMAIN=localhost" >> .env

			PASSWORD="password"
			POSTGRES_PASSWORD="password"
			MINIO_ROOT_PASSWORD="password"
			PGADMIN_DEFAULT_PASSWORD="password"
			KC_BOOTSTRAP_ADMIN_PASSWORD="password"
			KC_DB_PASSWORD="password"
			KONG_PG_PASSWORD="password"
			KC_SECRET="password"
			echo "NAME=$$NAME" >> .env
			echo "DOMAIN=aldous.info" >> .env

			echo "PASSWORD=$$PASSWORD" >> .env
			echo "" >> .env
			echo "POSTGRES_PASSWORD=$$POSTGRES_PASSWORD" >> .env
			echo "MINIO_ROOT_PASSWORD=$$MINIO_ROOT_PASSWORD" >> .env
			echo "PGADMIN_DEFAULT_PASSWORD=$$PGADMIN_DEFAULT_PASSWORD" >> .env
			echo "KC_BOOTSTRAP_ADMIN_PASSWORD=$$KC_BOOTSTRAP_ADMIN_PASSWORD" >> .env
			echo "KC_DB_PASSWORD=$$KC_DB_PASSWORD" >> .env
			echo "KONG_PG_PASSWORD=$${KONG_PG_PASSWORD}" >> .env
			echo "" >> .env
			echo 'REGISTRY_CACHE=localhost:5001/$${NAME}-cache' >> .env
			echo "NODE_VERSION=24" >> .env
			echo "COMPOSE_DOCKER_CLI_BUILD=1" >> .env
			echo "COMPOSE_BAKE=1" >> .env
			echo "BUILDKIT_INLINE_CACHE=1" >> .env
			echo "BUILDKIT_PROGRESS=plain" >> .env
			echo "DOCKER_BUILDKIT=1" >> .env
			echo "" >> .env
			echo "POSTGRES_HOST=postgres" >> .env
			echo 'POSTGRES_USER=$${NAME}' >> .env
			echo 'POSTGRES_DB=$${NAME}' >> .env
			echo "" >> .env
			echo 'MINIO_ROOT_USER=$${NAME}' >> .env
			echo "" >> .env
			echo 'PGADMIN_DEFAULT_EMAIL=root@$${DOMAIN}' >> .env
			echo 'LETSENCRYPT_EMAIL=root@$${DOMAIN}' >> .env
			echo "" >> .env
			echo "KC_HTTP_ENABLED=true" >> .env
			echo "KC_HTTPS_PORT=0" >> .env
			echo "KC_PROXY=edge" >> .env
			echo "KC_PROXY_HEADERS=xforwarded" >> .env
			echo "KC_BOOTSTRAP_ADMIN_USERNAME=admin" >> .env
			echo "KC_DB=postgres" >> .env
			echo "KC_DB_URL=jdbc:postgresql://pgbouncer:5433/keycloak" >> .env
			echo "KC_DB_USERNAME=keycloak" >> .env
			echo 'KC_HOSTNAME=keycloak.$${DOMAIN}' >> .env
			echo "KC_HOSTNAME_STRICT=true" >> .env
			echo "KC_SECRET=$${KC_SECRET}" >> .env
			echo "" >> .env
			echo "KONG_ADMIN_ACCESS_LOG=/dev/stdout" >> .env
			echo "KONG_ADMIN_ERROR_LOG=/dev/stderr" >> .env
			echo "KONG_ADMIN_LISTEN=0.0.0.0:8001" >> .env
			echo "KONG_DATABASE=postgres" >> .env
			echo "KONG_PG_DATABASE=kong" >> .env
			echo "KONG_PG_HOST=pgbouncer" >> .env
			echo "KONG_PG_PORT=5433" >> .env
			echo "KONG_PG_USER=kong" >> .env
			echo "KONG_PLUGINSERVER_NAMES=oidcify" >> .env
			echo 'KONG_PLUGINSERVER_OIDCIFY_QUERY_CMD="/usr/local/bin/oidcify -dump"' >> .env
			echo "KONG_PLUGINSERVER_OIDCIFY_START_CMD=/usr/local/bin/oidcify" >> .env
			echo "KONG_PLUGINS=bundled,rate-limiting,key-auth,oauth2,oidcify" >> .env
			echo "KONG_PROXY_ACCESS_LOG=/dev/stdout" >> .env
			echo "KONG_PROXY_ERROR_LOG=/dev/stderr" >> .env
			openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"
		fi
	fi
	set -a ;. .env ;set +a
	export PATH="$$HOME/.volta/bin:$$PATH"
	export PGBOUNCER_POSTGRES_PASSWORD=md5$$(printf '%s' "$$POSTGRES_PASSWORD$$NAME" | md5sum | cut -d' ' -f1)
	export PGBOUNCER_KC_PASSWORD=md5$$(printf '%s' "$$KC_DB_PASSWORD"keycloak | md5sum | cut -d' ' -f1)
	export PGBOUNCER_KONG_PASSWORD=md5$$(printf '%s' "$$KONG_PG_PASSWORD"kong | md5sum | cut -d' ' -f1)
	echo "[databases]" > services/pgbouncer/databases.ini
	echo -e "" > services/pgbouncer/userlist.txt
	echo "$$NAME = host=postgres port=5432 dbname=$$NAME user=$$NAME password=$$POSTGRES_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"$$NAME\" \"$$PGBOUNCER_POSTGRES_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "keycloak = host=postgres port=5432 dbname=keycloak user=keycloak password=$$KC_DB_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"keycloak\" \"$$PGBOUNCER_KC_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "kong = host=postgres port=5432 dbname=kong user=kong password=$$KONG_PG_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"kong\" \"$$PGBOUNCER_KONG_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo -e "" > services/postgres/init/01.sql
	echo "CREATE ROLE keycloak WITH LOGIN PASSWORD '$$KC_DB_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE keycloak OWNER keycloak;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE keycloak TO keycloak;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE kong WITH LOGIN PASSWORD '$$KONG_PG_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE kong OWNER kong;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE kong TO kong;" >> services/postgres/init/01.sql
	if ! command -v volta >/dev/null; then curl https://get.volta.sh | bash; fi
	if ! command -v volta >/dev/null; then curl https://get.volta.sh | bash; fi
	if ! command -v node >/dev/null; then volta install node@"$$NODE_VERSION"; fi
	if ! command -v pnpm >/dev/null; then volta install pnpm@latest; fi
	if ! command -v turbo >/dev/null; then volta install turbo@latest; fi
	if ! jq -e '
		.features.buildkit == true
		and .features["containerd-snapshotter"] == true
		and ( .["registry-mirrors"] | index("http://localhost:5000") )
		and ( .["insecure-registries"] | index("localhost:5001") )
	' /etc/docker/daemon.json > /dev/null 2>&1; then
		echo '{ "insecure-registries": ["localhost:5001"], "features": { "buildkit": true, "containerd-snapshotter": true }, "registry-mirrors": [ "http://localhost:5000" ] }' | jq .
		exit 1
	fi
	if ! docker container inspect registry-proxy >/dev/null 2>&1; then
		docker run -d --name registry-proxy --restart=always -p 5000:5000 -v registry_proxy_data:/var/lib/registry -v ./services/registry/config.yml:/etc/docker/registry/config.yml:ro registry:2
	fi
	if ! docker container inspect registry-write >/dev/null 2>&1; then
		docker run -d --name registry-write --restart=always -p 5001:5000 -v registry_write_data:/var/lib/registry registry:2
	fi

env:
	@openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"

reset: clean
	@rm -f .env
	docker rm -f registry-proxy registry-write
	docker volume rm -f registry_proxy_data registry_write_data

install: setup
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) build --pull --parallel
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) up -d --remove-orphans

clean: env
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) down -v --remove-orphans

help:
	@echo "make setup   - Initial project setup"
	@echo "make env     - Update environment file"
	@echo "make install - Install docker environment"
	@echo "make clean   - Clean docker environment"
	@echo "make reset   - Reset entire setup"

#
# .PHONY: help setup install build base-image start prod test lint format type-check logs stop clean docker-config reset sonar tmp
# .DEFAULT_GOAL := help
#
# setup: ; ./setup.sh
#
# install: ; if [ -d node_modules ]; then pnpm install --frozen-lockfile; else pnpm install; fi
# build: ; pnpm turbo run build build-storybook
# test: ; pnpm turbo run test -- --passWithNoTests --coverage --all
# lint: ; pnpm turbo run lint
# format: ; pnpm format
# tidy: ; pnpm tidy
# type-check: ; pnpm turbo run type-check
# logs: ; docker compose ${DOCKER_COMPOSE} logs -f
#
# start: base-image build ; docker compose ${DOCKER_COMPOSE} build --no-cache --pull --parallel && docker compose ${DOCKER_COMPOSE} up -d --remove-orphans
# stop: ; touch .env && docker compose ${DOCKER_COMPOSE} down
#
# start-dev: base-image build ; docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml build --no-cache --pull --parallel && docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml up -d --remove-orphans
# stop-dev: ; docker compose ${DOCKER_COMPOSE} -f docker/docker-compose.net.yml down
#
# all: reset setup install start
#
# sonar:
# 	if [ ! -f .env ]; then touch .env; fi; \
# 	if ! grep -q "SONAR_TOKEN" .env; then \
#         token=$$(curl -s -u admin:admin -X POST 'http://localhost:3016/api/user_tokens/generate' -d name=admin | jq -r '.token'); \
#         echo "SONAR_TOKEN=$$token" >> .env; \
# 	fi; \
#         rm -f sonar.json; \
# 	bash -c 'source .env && sonar -Dsonar.host.url=http://localhost:3016 -Dsonar.login=$${SONAR_TOKEN} -Dsonar.projectKey=mindfield -Dsonar.exclusions=caddy/**'; \
# 	bash -c 'source .env && for ((p=1;;p++)); do \
#         r=$$(curl -s -u $${SONAR_TOKEN}: "http://localhost:3016/api/issues/search?branch=main&ps=500&p=$$p"); \
#         if [ $$(jq -e ".issues|length" <<<"$${r}") -eq 0 ]; then break; fi; \
#         printf "%s\n" "$$r"; \
# 	done | jq -s "map(.issues) | add // []" > sonar.json; \
# 	echo ""; \
# 	jq -r ".[] | select(.issueStatus != \"FIXED\") | \"\( (.component | split(\":\")[1])):\(.line) \(.message)\"" sonar.json'
#
# docker-test: ; docker compose ${DOCKER_COMPOSE} config
# docker-config:
# 	if [ ! jq -e '.features.buildkit == true and .features["containerd-snapshotter"] == true and (.["registry-mirrors"] | index("http://localhost:5000"))' /etc/docker/daemon.json > /dev/null 2>&1 ]; then \
# 	echo 'Docker: enable buildkit, containerd-snapshotter & registry-mirrors (caching)'; \
# 	exit 1; \
# 	fi
#
# base-image: docker-config
# 	docker buildx build \
# 	--push \
# 	--compress \
# 	--progress=plain \
# 	--cache-from=type=registry,ref=$(REGISTRY_CACHE) \
# 	--cache-to=type=registry,ref=$(REGISTRY_CACHE),mode=max,oci-mediatypes=true \
# 	--build-arg NODE_MAJOR=$(NODE_MAJOR) \
# 	-f docker/Dockerfile.base \
# 	-t $(REGISTRY_CACHE)/base-deps:$(NODE_MAJOR) .
#
# clean: stop
# 	pnpm turbo run clean || true
# 	docker image prune -af || true
# 	docker buildx prune -af || true
# 	rm -rf .buildx_cache || true
# 	mkdir -p .buildx_cache || true
#
# reset: clean
# 	docker system prune -a --volumes -f || true
# 	docker volume ls -q | grep '^mindfield' | xargs -r docker volume rm || true
# 	git clean -xfd || true
#
# help:
# 	@echo "make setup           - Initial project setup"
# 	@echo "make install         - pnpm ci for all workspaces"
# 	@echo "make build           - pnpm run build (monorepo)"
# 	@echo "make base-image      - Build & push base-deps image"
# 	@echo "make docker-config   - Verify Docker daemon config"
# 	@echo "make start           - Build & start full dev stack via Caddy"
# 	@echo "make start-dev       - Build & start dev stack with exposed ports"
# 	@echo "make prod            - Alias for start (production mode)"
# 	@echo "make test            - Run all tests"
# 	@echo "make lint            - ESLint across workspace"
# 	@echo "make format          - Code formatting"
# 	@echo "make tidy            - Package formatting"
# 	@echo "make type-check      - TypeScript checks"
# 	@echo "make logs            - Tail docker logs"
# 	@echo "make stop            - Stop all services"
# 	@echo "make stop-dev        - Stop dev stack only"
# 	@echo "make clean           - Tear down & prune images"
# 	@echo "make reset           - Full reset (prune volumes, clean, etc.)"
# 	@echo "make sonar           - Run SonarQube analysis"
# 	@echo "make all             - Reset, setup & start"

