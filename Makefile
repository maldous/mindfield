.PHONY: *
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

	    KONG_COOKIE_HASH_ROOT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_PGADMIN="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_MAILHOG="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_REDISINSIGHT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_MINIO="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_ALERTMANAGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_BLACKBOX="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_GRAFANA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_JAEGER="$$(openssl rand -hex 32)"

	    KONG_COOKIE_BLOCK_ROOT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_PGADMIN="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_MAILHOG="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_REDISINSIGHT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_MINIO="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_ALERTMANAGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_BLACKBOX="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_GRAFANA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_JAEGER="$$(openssl rand -hex 32)"

	    CLIENT_SECRET_ROOT="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_PGADMIN="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_MAILHOG="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_REDISINSIGHT="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_MINIO="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_ALERTMANAGER="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_BLACKBOX="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_GRAFANA="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_JAEGER="$$(openssl rand -hex 32)"

	    #PASSWORD="$$(openssl rand -hex 16)"
	    #POSTGRES_PASSWORD="$$(openssl rand -hex 16)"
	    #MINIO_ROOT_PASSWORD="$$(openssl rand -hex 16)"
	    #PGADMIN_DEFAULT_PASSWORD="$$(openssl rand -hex 16)"
	    #GRAFANA_DEFAULT_PASSWORD="$$(openssl rand -hex 16)"
	    #KC_BOOTSTRAP_ADMIN_PASSWORD="$$(openssl rand -hex 16)"
	    #KC_DB_PASSWORD="$$(openssl rand -hex 16)"
	    #KC_SECRET="$$(openssl rand -hex 32)"
	    #KONG_PG_PASSWORD="$$(openssl rand -hex 16)"

	    PASSWORD="password"
	    POSTGRES_PASSWORD="password"
	    MINIO_ROOT_PASSWORD="password"
	    PGADMIN_DEFAULT_PASSWORD="password"
	    GRAFANA_DEFAULT_PASSWORD="password"
	    KC_BOOTSTRAP_ADMIN_PASSWORD="password"
	    KC_DB_PASSWORD="password"
	    KC_SECRET="password"
	    KONG_PG_PASSWORD="password"

	    echo "NAME=$$NAME" >> .env
	    echo "DOMAIN=aldous.info" >> .env
	    echo "PASSWORD=$$PASSWORD" >> .env
	    echo "" >> .env
	    echo "POSTGRES_PASSWORD=$$POSTGRES_PASSWORD" >> .env
	    echo "MINIO_ROOT_PASSWORD=$$MINIO_ROOT_PASSWORD" >> .env
	    echo "PGADMIN_DEFAULT_PASSWORD=$$PGADMIN_DEFAULT_PASSWORD" >> .env
	    echo "GRAFANA_DEFAULT_PASSWORD=$$GRAFANA_DEFAULT_PASSWORD" >> .env
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
	    echo 'MINIO_ROOT_USER=admin' >> .env
	    echo 'AWS_ACCESS_KEY_ID=$${MINIO_ROOT_USER}' >> .env
	    echo 'AWS_SECRET_ACCESS_KEY=$${MINIO_ROOT_PASSWORD}' >> .env
	    echo 'AWS_REGION=ap-southeast-4' >> .env
	    echo "" >> .env
	    echo "RI_ACCEPT_TERMS_AND_CONDITIONS=true" >> .env
	    echo "RI_REDIS_HOST=redis" >> .env
	    echo "RI_REDIS_PORT=6379" >> .env
	    echo "RI_REDIS_ALIAS=redis" >> .env
	    echo "" >> .env
	    echo "GF_DATABASE_TYPE=postgres" >> .env
	    echo "GF_DATABASE_HOST=postgres:5432" >> .env
	    echo "GF_DATABASE_NAME=grafana" >> .env
	    echo "GF_DATABASE_USER=grafana" >> .env
	    echo 'GF_DATABASE_PASSWORD=$${POSTGRES_PASSWORD}' >> .env
	    echo "GF_DATABASE_SSL_MODE=disable" >> .env
	    echo "GF_SMTP_ENABLED=true" >> .env
	    echo "GF_SMTP_HOST=mailhog:1025" >> .env
	    echo 'GF_SMTP_FROM_ADDRESS=grafana@$${DOMAIN}' >> .env
	    echo "GF_CACHE_TYPE=redis" >> .env
	    echo "GF_CACHE_REDIS_ADDR=redis:6379" >> .env
	    echo "GF_CACHE_REDIS_DB_INDEX=0" >> .env
	    echo "GF_RENDERING_S3_REGION=us-east-1" >> .env
	    echo "GF_RENDERING_S3_ENDPOINT=minio:9001" >> .env
	    echo "GF_RENDERING_S3_BUCKET=grafana-render" >> .env
	    echo 'GF_RENDERING_S3_ACCESS_KEY_ID=$${MINIO_ROOT_USER}' >> .env
	    echo 'GF_RENDERING_S3_SECRET_ACCESS_KEY=$${MINIO_ROOT_PASSWORD}' >> .env
	    echo "GF_RENDERING_S3_INSECURE_SKIP_VERIFY=true" >> .env
	    echo "" >> .env
	    echo 'PGADMIN_DEFAULT_EMAIL=root@$${DOMAIN}' >> .env
	    echo "PGADMIN_CONFIG_SERVER_MODE=True" >> .env
	    echo "PGADMIN_CONFIG_CONFIG_DATABASE_URI=\"'postgresql+psycopg://pgadmin:$${PGADMIN_DEFAULT_PASSWORD}@pgbouncer:5433/pgadmin'\"" >> .env
	    echo "" >> .env
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
	    echo "KONG_NGINX_WORKER_PROCESSES=2" >> .env
	    echo 'KONG_DB_CACHE_WARMUP_ENTITIES=""' >> .env
	    echo "KONG_LICENSING_ENABLED=false" >> .env

	    echo "" >> .env
	    echo "KONG_COOKIE_HASH_ROOT=$$KONG_COOKIE_HASH_ROOT" >> .env
	    echo "KONG_COOKIE_HASH_PGADMIN=$$KONG_COOKIE_HASH_PGADMIN" >> .env
	    echo "KONG_COOKIE_HASH_MAILHOG=$$KONG_COOKIE_HASH_MAILHOG" >> .env
	    echo "KONG_COOKIE_HASH_REDISINSIGHT=$$KONG_COOKIE_HASH_REDISINSIGHT" >> .env
	    echo "KONG_COOKIE_HASH_MINIO=$$KONG_COOKIE_HASH_MINIO" >> .env
	    echo "KONG_COOKIE_HASH_ALERTMANAGER=$$KONG_COOKIE_HASH_ALERTMANAGER" >> .env
	    echo "KONG_COOKIE_HASH_BLACKBOX=$$KONG_COOKIE_HASH_BLACKBOX" >> .env
	    echo "KONG_COOKIE_HASH_GRAFANA=$$KONG_COOKIE_HASH_GRAFANA" >> .env
	    echo "KONG_COOKIE_HASH_JAEGER=$$KONG_COOKIE_HASH_JAEGER" >> .env

	    echo "" >> .env
	    echo "KONG_COOKIE_BLOCK_ROOT=$$KONG_COOKIE_BLOCK_ROOT" >> .env
	    echo "KONG_COOKIE_BLOCK_PGADMIN=$$KONG_COOKIE_BLOCK_PGADMIN" >> .env
	    echo "KONG_COOKIE_BLOCK_MAILHOG=$$KONG_COOKIE_BLOCK_MAILHOG" >> .env
	    echo "KONG_COOKIE_BLOCK_REDISINSIGHT=$$KONG_COOKIE_BLOCK_REDISINSIGHT" >> .env
	    echo "KONG_COOKIE_BLOCK_MINIO=$$KONG_COOKIE_BLOCK_MINIO" >> .env
	    echo "KONG_COOKIE_BLOCK_ALERTMANAGER=$$KONG_COOKIE_BLOCK_ALERTMANAGER" >> .env
	    echo "KONG_COOKIE_BLOCK_BLACKBOX=$$KONG_COOKIE_BLOCK_BLACKBOX" >> .env
	    echo "KONG_COOKIE_BLOCK_GRAFANA=$$KONG_COOKIE_BLOCK_GRAFANA" >> .env
	    echo "KONG_COOKIE_BLOCK_JAEGER=$$KONG_COOKIE_BLOCK_JAEGER" >> .env

	    echo "" >> .env
	    echo "CLIENT_ID_ROOT=root" >> .env
	    echo "CLIENT_ID_PGADMIN=pgadmin" >> .env
	    echo "CLIENT_ID_MAILHOG=mailhog" >> .env
	    echo "CLIENT_ID_REDISINSIGHT=redisinsight" >> .env
	    echo "CLIENT_ID_MINIO=minio" >> .env
	    echo "CLIENT_ID_ALERTMANAGER=alertmanager" >> .env
	    echo "CLIENT_ID_BLACKBOX=blackbox" >> .env
	    echo "CLIENT_ID_GRAFANA=grafana" >> .env
	    echo "CLIENT_ID_JAEGER=jaeger" >> .env

	    echo "" >> .env
	    echo "CLIENT_SECRET_ROOT=$$CLIENT_SECRET_ROOT" >> .env
	    echo "CLIENT_SECRET_PGADMIN=$$CLIENT_SECRET_PGADMIN" >> .env
	    echo "CLIENT_SECRET_MAILHOG=$$CLIENT_SECRET_MAILHOG" >> .env
	    echo "CLIENT_SECRET_REDISINSIGHT=$$CLIENT_SECRET_REDISINSIGHT" >> .env
	    echo "CLIENT_SECRET_MINIO=$$CLIENT_SECRET_MINIO" >> .env
	    echo "CLIENT_SECRET_ALERTMANAGER=$$CLIENT_SECRET_ALERTMANAGER" >> .env
	    echo "CLIENT_SECRET_BLACKBOX=$$CLIENT_SECRET_BLACKBOX" >> .env
	    echo "CLIENT_SECRET_GRAFANA=$$CLIENT_SECRET_GRAFANA" >> .env
	    echo "CLIENT_SECRET_JAEGER=$$CLIENT_SECRET_JAEGER" >> .env

	    openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"
	  fi
	fi
	set -a ;. .env ;set +a
	export PATH="$$HOME/.volta/bin:$$PATH"
	export PGBOUNCER_POSTGRES_PASSWORD=md5$$(printf '%s' "$$POSTGRES_PASSWORD$$NAME" | md5sum | cut -d' ' -f1)
	export PGBOUNCER_KC_PASSWORD=md5$$(printf '%s' "$$KC_DB_PASSWORD"keycloak | md5sum | cut -d' ' -f1)
	export PGBOUNCER_KONG_PASSWORD=md5$$(printf '%s' "$$KONG_PG_PASSWORD"kong | md5sum | cut -d' ' -f1)
	export PGBOUNCER_PGADMIN_PASSWORD=md5$$(printf '%s' "$$PGADMIN_DEFAULT_PASSWORD"pgadmin | md5sum | cut -d' ' -f1)
	export PGBOUNCER_GRAFANA_PASSWORD=md5$$(printf '%s' "$$GRAFANA_DEFAULT_PASSWORD"grafana | md5sum | cut -d' ' -f1)
	echo "[databases]" > services/pgbouncer/databases.ini
	echo "" > services/pgbouncer/userlist.txt
	echo "$$NAME = host=postgres port=5432 dbname=$$NAME user=$$NAME password=$$POSTGRES_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"$$NAME\" \"$$PGBOUNCER_POSTGRES_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "keycloak = host=postgres port=5432 dbname=keycloak user=keycloak password=$$KC_DB_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"keycloak\" \"$$PGBOUNCER_KC_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "kong = host=postgres port=5432 dbname=kong user=kong password=$$KONG_PG_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"kong\" \"$$PGBOUNCER_KONG_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "pgadmin = host=postgres port=5432 dbname=pgadmin user=pgadmin password=$$PGADMIN_DEFAULT_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"pgadmin\" \"$$PGBOUNCER_PGADMIN_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "grafana = host=postgres port=5432 dbname=grafana user=grafana password=$$GRAFANA_DEFAULT_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"grafana\" \"$$PGBOUNCER_GRAFANA_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "" > services/postgres/init/01.sql
	echo "CREATE ROLE keycloak WITH LOGIN PASSWORD '$$KC_DB_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE keycloak OWNER keycloak;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE keycloak TO keycloak;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE kong WITH LOGIN PASSWORD '$$KONG_PG_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE kong OWNER kong;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE kong TO kong;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE pgadmin WITH LOGIN PASSWORD '$$PGADMIN_DEFAULT_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE pgadmin OWNER pgadmin;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE pgadmin TO pgadmin;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE grafana WITH LOGIN PASSWORD '$$GRAFANA_DEFAULT_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE grafana OWNER grafana;" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE grafana TO grafana;" >> services/postgres/init/01.sql
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
	@docker rm -f registry-proxy registry-write || exit 1
	@docker volume rm -f registry_proxy_data registry_write_data || exit 1

install: setup
	@docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) build --pull --parallel || exit 1
	@docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) up -d --remove-orphans || exit 1

clean: env
	@docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) down -v --remove-orphans

help:
	@echo "make setup   - Initial project setup"
	@echo "make env     - Update environment file"
	@echo "make install - Install docker environment"
	@echo "make clean   - Clean docker environment"
	@echo "make reset   - Reset entire setup"
