FROM kong:3.8.0
USER root

ARG OIDCIFY_VER=1.3.0
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates tar; \
    curl -L "https://github.com/hanlaur/oidcify/releases/download/v${OIDCIFY_VER}/oidcify_${OIDCIFY_VER}_linux_amd64.tar.gz" \
         -o /tmp/oidcify.tgz; \
    # the binary is under oidcify_<ver>_linux_amd64/oidcify
    tar -xz --strip-components=1 -C /usr/local/bin \
        -f /tmp/oidcify.tgz "oidcify_${OIDCIFY_VER}_linux_amd64/oidcify"; \
    rm /tmp/oidcify.tgz; \
    apt-get purge -y --auto-remove curl; \
    rm -rf /var/lib/apt/lists/*

USER kong

ENV KONG_PLUGINS="bundled,oidcify" \
    KONG_PLUGINSERVER_NAMES="oidcify" \
    KONG_PLUGINSERVER_OIDCIFY_QUERY_CMD="/usr/local/bin/oidcify -dump" \
    KONG_PLUGINSERVER_OIDCIFY_START_CMD="/usr/local/bin/oidcify"
