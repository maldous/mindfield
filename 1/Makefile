.PHONY: *
.DEFAULT_GOAL := help

.ONESHELL:
SHELL := bash

ifneq (,$(wildcard .env))
	include .env
	export
endif

enc:
	@set -a; . .env; set +a; openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"

check-gcloud:
	@command -v gcloud >/dev/null 2>&1 || exit 0
	@if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then \
	  echo "Run 'gcloud auth login' to enable backup/restore."; exit 0; \
	fi

check-bucket: check-gcloud
	@set -a; . .env; set +a; \
	if ! gsutil ls -b gs://${NAME} >/dev/null 2>&1; then \
	  gsutil mb -p $$(gcloud config get-value project) gs://${NAME}/; \
	fi

backup: check-bucket clean
	@rm -f /tmp/${NAME}-backup.tar.gz /tmp/${NAME}-services.tar.gz
	@if sudo test -d /var/lib/docker/persist; then \
	  set -a; . .env; set +a; \
	  sudo tar -czf /tmp/${NAME}-backup.tar.gz -C /var/lib/docker persist; \
	  tar -czf /tmp/${NAME}-services.tar.gz services; \
	  gsutil cp /tmp/${NAME}-backup.tar.gz gs://$$NAME/backup.tar.gz; \
	  gsutil cp /tmp/${NAME}-services.tar.gz gs://$$NAME/services.tar.gz; \
	  gsutil cp .enc gs://$$NAME/enc; \
	  sudo rm -f /tmp/${NAME}-backup.tar.gz; \
	  rm -f /tmp/${NAME}-services.tar.gz; \
	fi

restore: setup check-bucket clean
	@rm -f /tmp/${NAME}-backup.tar.gz /tmp/${NAME}-services.tar.gz
	@set -a; . .env; set +a; \
	if gsutil ls gs://${NAME}/backup.tar.gz >/dev/null 2>&1; then \
	  gsutil cp gs://${NAME}/enc .enc; \
	  gsutil cp gs://${NAME}/backup.tar.gz /tmp/${NAME}-backup.tar.gz; \
	  gsutil cp gs://${NAME}/services.tar.gz /tmp/${NAME}-services.tar.gz; \
	  sudo tar -xzf /tmp/${NAME}-backup.tar.gz -C /var/lib/docker; \
	  tar -xzf /tmp/${NAME}-services.tar.gz; \
	  rm -f /tmp/${NAME}-backup.tar.gz; \
	  rm -f /tmp/${NAME}-services.tar.gz; \
	fi

setup:
	@if [ ! -f .env ]; then
	  if [ -f .enc ]; then
	    echo -n "Restore .env from .enc? [y/N]: "; read ANSWER
	    if echo "$$ANSWER" | grep -qi '^y'; then
	      echo -n "Decryption password: "; stty -echo; read PASSWORD; stty echo; echo
	      TMP_ENV="$$(mktemp)"
	      if openssl enc -d -aes-256-cbc -pbkdf2 -in .enc -out "$$TMP_ENV" -k "$$PASSWORD"; then
	        mv "$$TMP_ENV" .env
	      else
	        echo "WRONG PASSWORD!" && rm -f "$$TMP_ENV" && exit 1
	      fi
	    fi
	  fi
	  if [ ! -f .env ]; then
	    NAME="$$(basename "$$PWD")"
	    DATE="$$(date +%s)"
	    #PASSWORD="$$(openssl rand -hex 16)"
	    PASSWORD="password"

	    KONG_COOKIE_HASH_ROOT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_PGADMIN="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_MAILHOG="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_REDISINSIGHT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_MINIO="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_ALERTMANAGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_BLACKBOX="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_GRAFANA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_JAEGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_KUMA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_PROMTAIL="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_SEARCH="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_SONARQUBE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_DOCS="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_POSTGRAPHILE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_GITLAB="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_CADENCE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_SENTRY="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_NUI="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_AKHQ="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_NETDATA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_HASH_KONG="$$(openssl rand -hex 32)"

	    KONG_COOKIE_BLOCK_ROOT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_PGADMIN="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_MAILHOG="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_REDISINSIGHT="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_MINIO="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_ALERTMANAGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_BLACKBOX="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_GRAFANA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_JAEGER="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_KUMA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_PROMTAIL="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_SEARCH="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_SONARQUBE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_DOCS="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_POSTGRAPHILE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_GITLAB="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_CADENCE="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_SENTRY="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_NUI="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_AKHQ="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_NETDATA="$$(openssl rand -hex 32)"
	    KONG_COOKIE_BLOCK_KONG="$$(openssl rand -hex 32)"

	    CLIENT_SECRET_ROOT="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_PGADMIN="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_MAILHOG="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_REDISINSIGHT="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_MINIO="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_ALERTMANAGER="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_BLACKBOX="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_GRAFANA="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_JAEGER="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_KUMA="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_PROMTAIL="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_SEARCH="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_SONARQUBE="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_DOCS="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_POSTGRAPHILE="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_GITLAB="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_CADENCE="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_SENTRY="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_NUI="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_AKHQ="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_NETDATA="$$(openssl rand -hex 32)"
	    CLIENT_SECRET_KONG="$$(openssl rand -hex 32)"

	    POSTGRES_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    MINIO_ROOT_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    PGADMIN_DEFAULT_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    GRAFANA_DEFAULT_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    KC_BOOTSTRAP_ADMIN_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    KC_DB_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    KC_SECRET="$$(pwgen -s -c -n 16 1)"
	    KONG_PG_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    SONAR_JDBC_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    POSTGRAPHILE_DB_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    OPENSEARCH_INITIAL_ADMIN_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    SONAR_ADMIN_PASSWORD="$$(pwgen -s -c -n 16 1)!"
	    GITLAB_ROOT_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    CADENCE_PASSWORD="$$(pwgen -s -c -n 16 1)"
	    SENTRY_SECRET_KEY="$$(pwgen -s -c -n 32 1)"

	    echo "# $$DATE" >> .env
	    echo "" >> .env
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
	    echo "SONAR_JDBC_PASSWORD=$${SONAR_JDBC_PASSWORD}" >> .env
	    echo "POSTGRAPHILE_DB_PASSWORD=$${POSTGRAPHILE_DB_PASSWORD}" >> .env
	    echo "OPENSEARCH_INITIAL_ADMIN_PASSWORD=$${OPENSEARCH_INITIAL_ADMIN_PASSWORD}" >> .env
	    echo "SONAR_ADMIN_PASSWORD=$${SONAR_ADMIN_PASSWORD}" >> .env
	    echo "GITLAB_ROOT_PASSWORD=$${GITLAB_ROOT_PASSWORD}" >> .env
	    echo "CADENCE_PASSWORD=$${CADENCE_PASSWORD}" >> .env
	    echo "SENTRY_SECRET_KEY=$${SENTRY_SECRET_KEY}" >> .env

	    echo "" >> .env
	    echo 'REGISTRY_CACHE=localhost:5001/$${NAME}-cache' >> .env
	    echo "NODE_VERSION=24" >> .env
	    echo "COMPOSE_DOCKER_CLI_BUILD=1" >> .env
	    echo "COMPOSE_BAKE=1" >> .env
	    echo "BUILDKIT_INLINE_CACHE=1" >> .env
	    echo "BUILDKIT_PROGRESS=plain" >> .env
	    echo "DOCKER_BUILDKIT=1" >> .env

	    echo "" >> .env
	    echo "DB=postgres" >> .env
	    echo "DB_HOST=pgbouncer" >> .env
	    echo "DB_PORT=5433" >> .env
	    echo "PGBOUNCER_HOST=pgbouncer" >> .env
	    echo "PGBOUNCER_PORT=5433" >> .env
	    echo "POSTGRES_HOST=postgres" >> .env
	    echo "POSTGRES_PORT=5432" >> .env
	    echo 'POSTGRES_USER=$${NAME}' >> .env
	    echo 'POSTGRES_SEEDS=pgbouncer' >> .env
	    echo 'POSTGRES_DB=$${NAME}' >> .env

	    echo "" >> .env
	    echo 'SENTRY_DB_ENGINE=django.db.backends.postgresql' >> .env
	    echo 'SENTRY_DB_HOST=pgbouncer' >> .env
	    echo 'SENTRY_DB_NAME=sentry' >> .env
	    echo 'SENTRY_DB_USER=sentry' >> .env
	    echo 'SENTRY_DB_PORT=5433' >> .env
	    echo 'SENTRY_DB_PASSWORD=$${SENTRY_SECRET_KEY}' >> .env
	    echo 'SENTRY_REDIS_HOST=redis' >> .env
	    echo 'SENTRY_REDIS_PORT=6379' >> .env
	    echo 'SENTRY_CONF=/etc/sentry' >> .env
	    echo 'BROKER_URL=redis://$${SENTRY_REDIS_HOST}:$${SENTRY_REDIS_PORT}/0' >> .env
	    echo 'SENTRY_REDIS=redis://$${SENTRY_REDIS_HOST}:$${SENTRY_REDIS_PORT}/1' >> .env

	    echo "" >> .env
	    echo "CADENCE_ADDRESS=0.0.0.0:7933" >> .env
	    echo "CADENCE_GRPC_PEERS=cadence-server:7833" >> .env
	    echo "DYNAMIC_CONFIG_FILE_PATH=/etc/cadence/config/dynamicconfig/development.yaml" >> .env
	    echo "VISIBILITY_POSTGRES_DB=cadence_visibility" >> .env
	    echo 'VISIBILITY_POSTGRES_PWD=$${CADENCE_PASSWORD}' >> .env
	    echo "VISIBILITY_POSTGRES_SEEDS=postgres" >> .env
	    echo "VISIBILITY_POSTGRES_USER=cadence" >> .env
	    echo "VISIBILITY_STORE=postgres" >> .env

	    echo "" >> .env
	    echo 'REDIS_HOST=redis' >> .env
	    echo 'REDIS_PORT=6379' >> .env

	    echo "" >> .env
	    echo 'NATS_URL=nats://nats:4222' >> .env
	    echo 'NATS_JS_STORE_DIR=/data/jetstream' >> .env
	    echo 'NATS_JS_MAX_MEM=512MB' >> .env
	    echo 'NATS_JS_MAX_FILE=2GB' >> .env

	    echo "" >> .env
	    echo 'MINIO_ROOT_USER=admin' >> .env
	    echo 'MINIO_HOST=minio' >> .env
	    echo 'MINIO_PORT=9000' >> .env
	    echo 'AWS_ACCESS_KEY_ID=$${MINIO_ROOT_USER}' >> .env
	    echo 'AWS_SECRET_ACCESS_KEY=$${MINIO_ROOT_PASSWORD}' >> .env
	    echo 'AWS_REGION=us-east-1' >> .env

	    echo "" >> .env
	    echo "RI_ACCEPT_TERMS_AND_CONDITIONS=true" >> .env
	    echo "RI_REDIS_HOST=redis" >> .env
	    echo "RI_REDIS_PORT=6379" >> .env
	    echo "RI_REDIS_ALIAS=redis" >> .env

	    echo "" >> .env
	    echo "PRESIDIO_ANALYZER_DEFAULT_SCORE_THRESHOLD=0.35" >> .env
	    echo "PRESIDIO_ANALYZER_ENTITIES_CACHE_TTL=3600" >> .env
	    echo "PRESIDIO_ANALYZER_HOST=analyzer" >> .env
	    echo "PRESIDIO_ANALYZER_PORT=3000" >> .env

	    echo "" >> .env
	    echo "GF_DATABASE_TYPE=postgres" >> .env
	    echo "GF_DATABASE_HOST=postgres:5432" >> .env
	    echo "GF_DATABASE_NAME=grafana" >> .env
	    echo "GF_DATABASE_USER=grafana" >> .env
	    echo 'GF_DATABASE_PASSWORD=$${GRAFANA_DEFAULT_PASSWORD}' >> .env
	    echo "GF_DATABASE_SSL_MODE=disable" >> .env
	    echo "GF_SMTP_ENABLED=true" >> .env
	    echo "GF_SMTP_HOST=mailhog:1025" >> .env
	    echo 'GF_SMTP_FROM_ADDRESS=grafana@$${DOMAIN}' >> .env
	    echo "GF_CACHE_TYPE=redis" >> .env
	    echo "GF_CACHE_REDIS_ADDR=redis:6379" >> .env
	    echo "GF_CACHE_REDIS_DB_INDEX=0" >> .env

	    echo "" >> .env
	    echo 'PGADMIN_DEFAULT_EMAIL=root@$${DOMAIN}' >> .env
	    echo "PGADMIN_CONFIG_SERVER_MODE=True" >> .env
	    echo "PGADMIN_CONFIG_CONFIG_DATABASE_URI=\"'postgresql+psycopg://pgadmin:$${PGADMIN_DEFAULT_PASSWORD}@pgbouncer:5433/pgadmin'\"" >> .env

	    echo "" >> .env
	    echo 'LETSENCRYPT_EMAIL=root@$${DOMAIN}' >> .env
	    echo "KUMA_USER=admin" >> .env
	    echo "OPENSEARCH_HOSTS='[\"http://opensearch:9200\"]'" >> .env
	    echo 'OPENSEARCH_JAVA_OPTS="-Xms512m -Xmx512m"' >> .env
	    echo 'DISABLE_SECURITY_DASHBOARDS_PLUGIN=true' >> .env
	    echo "SONAR_JDBC_URL=jdbc:postgresql://pgbouncer:5433/sonarqube" >> .env
	    echo "SONAR_JDBC_USERNAME=sonarqube" >> .env

	    echo "" >> .env
	    echo 'EXTERNAL_URL=https://gitlab.@$${DOMAIN}' >> .env
	    echo 'GITLAB_ROOT_EMAIL=root@$${DOMAIN}' >> .env

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
	    echo 'KAFKA_CFG_PROCESS_ROLES=broker,controller' >> .env
	    echo 'KAFKA_CFG_NODE_ID=1' >> .env
	    echo 'KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka:9093' >> .env
	    echo 'KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093' >> .env
	    echo 'KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092' >> .env
	    echo 'KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT' >> .env
	    echo 'KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER' >> .env
	    echo 'KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1' >> .env
	    echo 'KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1' >> .env
	    echo 'KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1' >> .env
	    echo 'SCHEMA_REGISTRY_HOST_NAME=schema-registry' >> .env
	    echo 'SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081' >> .env
	    echo 'SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://kafka:9092' >> .env
	    echo 'CONNECT_BOOTSTRAP_SERVERS=kafka:9092' >> .env
	    echo 'CONNECT_REST_PORT=8083' >> .env
	    echo 'CONNECT_GROUP_ID=connect-cluster' >> .env
	    echo 'CONNECT_PLUGIN_PATH=/usr/share/java' >> .env
	    echo 'CONNECT_CONFIG_STORAGE_TOPIC=connect-configs' >> .env
	    echo 'CONNECT_OFFSET_STORAGE_TOPIC=connect-offsets' >> .env
	    echo 'CONNECT_STATUS_STORAGE_TOPIC=connect-status' >> .env
	    echo 'CONNECT_KEY_CONVERTER=org.apache.kafka.connect.json.JsonConverter' >> .env
	    echo 'CONNECT_VALUE_CONVERTER=org.apache.kafka.connect.json.JsonConverter' >> .env
	    echo 'CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR=1' >> .env
	    echo 'CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR=1' >> .env
	    echo 'CONNECT_STATUS_STORAGE_REPLICATION_FACTOR=1' >> .env
	    echo 'CONNECT_REST_ADVERTISED_HOST_NAME=kafka-connect' >> .env
	    echo 'CONNECT_OFFSET_FLUSH_INTERVAL_MS=60000' >> .env
	    echo 'CONNECT_METRICS_SAMPLE_WINDOW_MS=60000' >> .env
	    echo 'CONNECT_METRICS_NUM_SAMPLES=2' >> .env

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
	    echo "KONG_COOKIE_HASH_KUMA=$$KONG_COOKIE_HASH_KUMA" >> .env
	    echo "KONG_COOKIE_HASH_PROMTAIL=$$KONG_COOKIE_HASH_PROMTAIL" >> .env
	    echo "KONG_COOKIE_HASH_SEARCH=$$KONG_COOKIE_HASH_SEARCH" >> .env
	    echo "KONG_COOKIE_HASH_SONARQUBE=$$KONG_COOKIE_HASH_SONARQUBE" >> .env
	    echo "KONG_COOKIE_HASH_DOCS=$$KONG_COOKIE_HASH_DOCS" >> .env
	    echo "KONG_COOKIE_HASH_POSTGRAPHILE=$$KONG_COOKIE_HASH_POSTGRAPHILE" >> .env
	    echo "KONG_COOKIE_HASH_GITLAB=$$KONG_COOKIE_HASH_GITLAB" >> .env
	    echo "KONG_COOKIE_HASH_CADENCE=$$KONG_COOKIE_HASH_CADENCE" >> .env
	    echo "KONG_COOKIE_HASH_SENTRY=$$KONG_COOKIE_HASH_SENTRY" >> .env
	    echo "KONG_COOKIE_HASH_NUI=$$KONG_COOKIE_HASH_NUI" >> .env
	    echo "KONG_COOKIE_HASH_AKHQ=$$KONG_COOKIE_HASH_AKHQ" >> .env
	    echo "KONG_COOKIE_HASH_NETDATA=$$KONG_COOKIE_HASH_NETDATA" >> .env
	    echo "KONG_COOKIE_HASH_KONG=$$KONG_COOKIE_HASH_KONG" >> .env

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
	    echo "KONG_COOKIE_BLOCK_KUMA=$$KONG_COOKIE_BLOCK_KUMA" >> .env
	    echo "KONG_COOKIE_BLOCK_PROMTAIL=$$KONG_COOKIE_BLOCK_PROMTAIL" >> .env
	    echo "KONG_COOKIE_BLOCK_SEARCH=$$KONG_COOKIE_BLOCK_SEARCH" >> .env
	    echo "KONG_COOKIE_BLOCK_SONARQUBE=$$KONG_COOKIE_BLOCK_SONARQUBE" >> .env
	    echo "KONG_COOKIE_BLOCK_DOCS=$$KONG_COOKIE_BLOCK_DOCS" >> .env
	    echo "KONG_COOKIE_BLOCK_POSTGRAPHILE=$$KONG_COOKIE_BLOCK_POSTGRAPHILE" >> .env
	    echo "KONG_COOKIE_BLOCK_GITLAB=$$KONG_COOKIE_BLOCK_GITLAB" >> .env
	    echo "KONG_COOKIE_BLOCK_CADENCE=$$KONG_COOKIE_BLOCK_CADENCE" >> .env
	    echo "KONG_COOKIE_BLOCK_SENTRY=$$KONG_COOKIE_BLOCK_SENTRY" >> .env
	    echo "KONG_COOKIE_BLOCK_NUI=$$KONG_COOKIE_BLOCK_NUI" >> .env
	    echo "KONG_COOKIE_BLOCK_AKHQ=$$KONG_COOKIE_BLOCK_AKHQ" >> .env
	    echo "KONG_COOKIE_BLOCK_NETDATA=$$KONG_COOKIE_BLOCK_NETDATA" >> .env
	    echo "KONG_COOKIE_BLOCK_KONG=$$KONG_COOKIE_BLOCK_KONG" >> .env

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
	    echo "CLIENT_SECRET_KUMA=$$CLIENT_SECRET_KUMA" >> .env
	    echo "CLIENT_SECRET_PROMTAIL=$$CLIENT_SECRET_PROMTAIL" >> .env
	    echo "CLIENT_SECRET_SEARCH=$$CLIENT_SECRET_SEARCH" >> .env
	    echo "CLIENT_SECRET_SONARQUBE=$$CLIENT_SECRET_SONARQUBE" >> .env
	    echo "CLIENT_SECRET_DOCS=$$CLIENT_SECRET_DOCS" >> .env
	    echo "CLIENT_SECRET_POSTGRAPHILE=$$CLIENT_SECRET_POSTGRAPHILE" >> .env
	    echo "CLIENT_SECRET_GITLAB=$$CLIENT_SECRET_GITLAB" >> .env
	    echo "CLIENT_SECRET_CADENCE=$$CLIENT_SECRET_CADENCE" >> .env
	    echo "CLIENT_SECRET_SENTRY=$$CLIENT_SECRET_SENTRY" >> .env
	    echo "CLIENT_SECRET_NUI=$$CLIENT_SECRET_NUI" >> .env
	    echo "CLIENT_SECRET_AKHQ=$$CLIENT_SECRET_AKHQ" >> .env
	    echo "CLIENT_SECRET_NETDATA=$$CLIENT_SECRET_NETDATA" >> .env
	    echo "CLIENT_SECRET_KONG=$$CLIENT_SECRET_KONG" >> .env

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
	    echo "CLIENT_ID_KUMA=kuma" >> .env
	    echo "CLIENT_ID_PROMTAIL=promtail" >> .env
	    echo "CLIENT_ID_SEARCH=search" >> .env
	    echo "CLIENT_ID_SONARQUBE=sonarqube" >> .env
	    echo "CLIENT_ID_DOCS=docs" >> .env
	    echo "CLIENT_ID_POSTGRAPHILE=postgraphile" >> .env
	    echo "CLIENT_ID_GITLAB=gitlab" >> .env
	    echo "CLIENT_ID_CADENCE=cadence" >> .env
	    echo "CLIENT_ID_SENTRY=sentry" >> .env
	    echo "CLIENT_ID_NUI=nui" >> .env
	    echo "CLIENT_ID_AKHQ=akhq" >> .env
	    echo "CLIENT_ID_NETDATA=netdata" >> .env
	    echo "CLIENT_ID_KONG=kong" >> .env

	    echo "" >> .env
	    openssl enc -aes-256-cbc -pbkdf2 -salt -in .env -out .enc -k "$$PASSWORD"
	  fi
	fi
	set -a ;. .env ;set +a

	export PATH="$$HOME/.volta/bin:$$PATH"
	export PGBOUNCER_KC_PASSWORD=md5$$(printf '%s' "$$KC_DB_PASSWORD"keycloak | md5sum | cut -d' ' -f1)
	export PGBOUNCER_KONG_PASSWORD=md5$$(printf '%s' "$$KONG_PG_PASSWORD"kong | md5sum | cut -d' ' -f1)
	export PGBOUNCER_PGADMIN_PASSWORD=md5$$(printf '%s' "$$PGADMIN_DEFAULT_PASSWORD"pgadmin | md5sum | cut -d' ' -f1)
	export PGBOUNCER_GRAFANA_PASSWORD=md5$$(printf '%s' "$$GRAFANA_DEFAULT_PASSWORD"grafana | md5sum | cut -d' ' -f1)
	export PGBOUNCER_SONARQUBE_PASSWORD=md5$$(printf '%s' "$$SONAR_JDBC_PASSWORD"sonarqube | md5sum | cut -d' ' -f1)
	export PGBOUNCER_POSTGRAPHILE_PASSWORD=md5$$(printf '%s' "$$POSTGRAPHILE_DB_PASSWORD"postgraphile | md5sum | cut -d' ' -f1)
	export PGBOUNCER_GITLAB_PASSWORD=md5$$(printf '%s' "$$GITLAB_ROOT_PASSWORD"gitlab | md5sum | cut -d' ' -f1)
	export PGBOUNCER_CADENCE_PASSWORD=md5$$(printf '%s' "$$CADENCE_PASSWORD"cadence | md5sum | cut -d' ' -f1)
	export PGBOUNCER_SENTRY_SECRET_KEY=md5$$(printf '%s' "$$SENTRY_SECRET_KEY"sentry | md5sum | cut -d' ' -f1)

	echo "" > services/pgbouncer/userlist.txt
	echo "\"keycloak\" \"$$PGBOUNCER_KC_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"kong\" \"$$PGBOUNCER_KONG_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"pgadmin\" \"$$PGBOUNCER_PGADMIN_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"grafana\" \"$$PGBOUNCER_GRAFANA_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"sonarqube\" \"$$PGBOUNCER_SONARQUBE_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"postgraphile\" \"$$PGBOUNCER_POSTGRAPHILE_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"gitlab\" \"$$PGBOUNCER_GITLAB_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"cadence\" \"$$PGBOUNCER_CADENCE_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"cadence_visibility\" \"$$PGBOUNCER_CADENCE_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "\"sentry\" \"$$PGBOUNCER_SENTRY_SECRET_KEY\"" >> services/pgbouncer/userlist.txt

	echo "[databases]" > services/pgbouncer/databases.ini
	echo "postgres = host=postgres port=5432 dbname=postgres" >> services/pgbouncer/databases.ini
	echo "keycloak = host=postgres port=5432 dbname=keycloak user=keycloak password=$$KC_DB_PASSWORD" >> services/pgbouncer/databases.ini
	echo "kong = host=postgres port=5432 dbname=kong user=kong password=$$KONG_PG_PASSWORD" >> services/pgbouncer/databases.ini
	echo "pgadmin = host=postgres port=5432 dbname=pgadmin user=pgadmin password=$$PGADMIN_DEFAULT_PASSWORD" >> services/pgbouncer/databases.ini
	echo "grafana = host=postgres port=5432 dbname=grafana user=grafana password=$$GRAFANA_DEFAULT_PASSWORD" >> services/pgbouncer/databases.ini
	echo "sonarqube = host=postgres port=5432 dbname=sonarqube user=sonarqube password=$$SONAR_JDBC_PASSWORD" >> services/pgbouncer/databases.ini
	echo "postgraphile = host=postgres port=5432 dbname=postgraphile user=postgraphile password=$$POSTGRAPHILE_DB_PASSWORD" >> services/pgbouncer/databases.ini
	echo "gitlab = host=postgres port=5432 dbname=gitlab user=gitlab password=$$GITLAB_ROOT_PASSWORD" >> services/pgbouncer/databases.ini
	echo "cadence = host=postgres port=5432 dbname=cadence user=cadence password=$$CADENCE_PASSWORD" >> services/pgbouncer/databases.ini
	echo "cadence_visibility = host=postgres port=5432 dbname=cadence_visibility user=cadence password=$$CADENCE_PASSWORD" >> services/pgbouncer/databases.ini
	echo "sentry = host=postgres port=5432 dbname=sentry user=sentry password=$$SENTRY_SECRET_KEY" >> services/pgbouncer/databases.ini

	echo "" > services/postgres/init/01.sql
	echo "CREATE ROLE keycloak WITH LOGIN PASSWORD '$$KC_DB_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE keycloak OWNER keycloak;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE kong WITH LOGIN PASSWORD '$$KONG_PG_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE kong OWNER kong;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE kong TO kong;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE pgadmin WITH LOGIN PASSWORD '$$PGADMIN_DEFAULT_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE pgadmin OWNER pgadmin;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE pgadmin TO pgadmin;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE grafana WITH LOGIN PASSWORD '$$GRAFANA_DEFAULT_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE grafana OWNER grafana;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE sonarqube WITH LOGIN PASSWORD '$$SONAR_JDBC_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE sonarqube OWNER sonarqube;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonarqube;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE gitlab WITH LOGIN PASSWORD '$$GITLAB_ROOT_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE gitlab OWNER gitlab;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE gitlab TO gitlab;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE cadence WITH LOGIN PASSWORD '$$CADENCE_PASSWORD';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE cadence OWNER cadence;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE cadence TO cadence;" >> services/postgres/init/01.sql
	echo "CREATE DATABASE cadence_visibility OWNER cadence;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE cadence_visibility TO cadence;" >> services/postgres/init/01.sql
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE sentry WITH LOGIN PASSWORD '$$SENTRY_SECRET_KEY';" >> services/postgres/init/01.sql
	echo "CREATE DATABASE sentry OWNER sentry;" >> services/postgres/init/01.sql
	echo "GRANT ALL PRIVILEGES ON DATABASE sentry TO sentry;" >> services/postgres/init/01.sql

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

	sudo mkdir -p -m 777 $$(grep '/var/lib/docker/persist' docker/* | cut -f3 -d'-' | cut -f1 -d':')

install: setup
	@set -a; . .env; set -a
	export PGBOUNCER_POSTGRES_PASSWORD=md5$$(printf '%s' "$$POSTGRES_PASSWORD$$NAME" | md5sum | cut -d' ' -f1)
	echo "$$NAME = host=postgres port=5432 dbname=$$NAME user=$$NAME password=$$POSTGRES_PASSWORD" >> services/pgbouncer/databases.ini
	echo "\"$$NAME\" \"$$PGBOUNCER_POSTGRES_PASSWORD\"" >> services/pgbouncer/userlist.txt
	echo "" >> services/postgres/init/01.sql
	echo "CREATE ROLE postgraphile WITH LOGIN PASSWORD '$$POSTGRAPHILE_DB_PASSWORD';" >> services/postgres/init/01.sql
	echo "GRANT CONNECT ON DATABASE $${NAME} TO postgraphile;" >> services/postgres/init/01.sql
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) build --pull --parallel
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) up -d --remove-orphans

clean:
	@touch .env; set -a; . .env; set -a
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) down --remove-orphans

purge:
	@touch .env; set -a; . .env; set -a
	docker compose --project-directory . $(foreach f,$(wildcard docker/docker-compose.*.yml),-f $(f)) down -v --remove-orphans
	sudo rm -fr /var/lib/docker/persist
	sudo mkdir /var/lib/docker/persist
	rm -fr .env sonar.json .scannerwork services/pgbouncer/databases.ini services/pgbouncer/userlist.txt services/postgres/init/01.sql

help:
	@echo "make setup"
	@echo "make install"
	@echo "make clean"
	@echo "make purge"
	@echo "make sonar"

sonar:
	if [ ! -f .env ]; then touch .env; fi; \
	if ! grep -q "SONAR_TOKEN" .env; then \
	token=$$( set -a; . .env; set +a; curl -s -u admin:${SONAR_ADMIN_PASSWORD} -X POST 'http://localhost:9003/api/user_tokens/generate' -d name=admin | jq -r '.token' ); \
	if [ -z "$$token" ] || [ "$$token" = "null" ]; then token=$$(curl -s -u admin:admin -X POST 'http://localhost:9003/api/user_tokens/generate' -d name=admin | jq -r '.token'); fi; \
	echo "SONAR_TOKEN=$$token" >> .env; \
	fi; \
	rm -f sonar.json; \
	bash -c 'source .env && sonar -Dsonar.host.url=http://localhost:9003 -Dsonar.login=$${SONAR_TOKEN} -Dsonar.projectKey=${NAME} -Dsonar.exclusions=data/**'; \
	bash -c 'source .env && for ((p=1;;p++)); do \
	r=$$(curl -s -u $${SONAR_TOKEN}: "http://localhost:9003/api/issues/search?branch=main&ps=500&p=$$p"); \
	if [ $$(jq -e ".issues|length" <<<"$${r}") -eq 0 ]; then break; fi; \
	printf "%s\n" "$$r"; \
	done | jq -s "map(.issues) | add // []" > sonar.json; \
	echo ""; \
	jq -r ".[] | select(.issueStatus != \"FIXED\") | \"\( (.component | split(\":\")[1])):\(.line) \(.message)\"" sonar.json'
