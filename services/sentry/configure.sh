#!/bin/bash
set -e
  [ -f /etc/sentry/sentry.conf.py ] || sentry init /etc/sentry
  sentry upgrade --noinput
  sentry createuser \
  --email root@${DOMAIN} \
  --password ${SENTRY_SECRET_KEY} \
  --superuser \
  --noinput || true
