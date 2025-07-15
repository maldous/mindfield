#!/bin/sh
set -euo pipefail
set -x

KONG_URL=http://kong:8001

until curl -s "$KONG_URL/status" >/dev/null; do sleep 2; done

if ! curl -s "$KONG_URL/plugins" | grep -q '"name":"rate-limiting"'; then
  curl -s -X POST "$KONG_URL/plugins" -H "Content-Type: application/json" \
    -d '{"name":"rate-limiting","config":{"minute":60,"policy":"local","limit_by":"ip"}}'
fi
