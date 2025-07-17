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

			KONG_COOKIE_HASH_PGADMIN="$$(openssl rand -hex 32)"
			KONG_COOKIE_BLOCK_PGADMIN="$$(openssl rand -hex 32)"
			CLIENT_SECRET_PGADMIN="$$(openssl rand -hex 32)"

			KONG_COOKIE_HASH_MAILHOG="$$(openssl rand -hex 32)"
			KONG_COOKIE_BLOCK_MAILHOG="$$(openssl rand -hex 32)"
			CLIENT_SECRET_MAILHOG="$$(openssl rand -hex 32)"

			openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"
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
			echo "KONG_PLUGINS=bundled,rate-limiting,oidcify" >> .env
			echo "KONG_PROXY_ACCESS_LOG=/dev/stdout" >> .env
			echo "KONG_PROXY_ERROR_LOG=/dev/stderr" >> .env
			echo "KONG_COOKIE_HASH_PGADMIN=$$KONG_COOKIE_HASH_PGADMIN" >> .env
			echo "KONG_COOKIE_BLOCK_PGADMIN=$$KONG_COOKIE_BLOCK_PGADMIN" >> .env
			echo "KONG_COOKIE_HASH_MAILHOG=$$KONG_COOKIE_HASH_MAILHOG" >> .env
			echo "KONG_COOKIE_BLOCK_MAILHOG=$$KONG_COOKIE_BLOCK_MAILHOG" >> .env
			echo "" >> .env
			echo "CLIENT_ID_PGADMIN=pgadmin" >> .env
			echo "CLIENT_SECRET_PGADMIN=$$CLIENT_SECRET_PGADMIN" >> .env
			echo "CLIENT_ID_MAILHOG=mailhog" >> .env
			echo "CLIENT_SECRET_MAILHOG=$$CLIENT_SECRET_MAILHOG" >> .env
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
