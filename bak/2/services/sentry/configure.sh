#!/bin/bash
set -e

sentry upgrade --noinput

sentry createuser \
  --email root@${DOMAIN} \
  --password ${SENTRY_SECRET_KEY} \
  --superuser \
  --no-input || true
