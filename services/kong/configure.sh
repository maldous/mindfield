#!/usr/bin/env bash
set -euo pipefail

KONG_ADMIN_URL=http://kong:8001

until curl -s "$KONG_ADMIN_URL/status" >/dev/null; do sleep 2; done

if ! curl -s "$KONG_ADMIN_URL/plugins" | grep -q '"name":"oidc"'; then
  curl -s -X POST "$KONG_ADMIN_URL/plugins" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"oidc\",\"config\":{
        \"client_id\":\"$OIDC_CLIENT_ID\",
        \"client_secret\":\"$OIDC_CLIENT_SECRET\",
        \"discovery\":\"$OIDC_ISSUER_URL\",
        \"redirect_uri\":\"https://api.$DOMAIN/callback\",
        \"scope\":\"openid profile email\",
        \"use_jwks\":\"yes\",
        \"realm\":\"mindfield\",
        \"session_secret\":\"$OIDC_SESSION_SECRET\"
    }}"

fi

if ! curl -s "$KONG_ADMIN_URL/plugins" | grep -q '"name":"rate-limiting"'; then
  curl -s -X POST "$KONG_ADMIN_URL/plugins" -H "Content-Type: application/json" \
    -d '{"name":"rate-limiting","config":{"minute":100,"hour":10000,"policy":"local"}}'
fi

if ! curl -s "$KONG_ADMIN_URL/plugins" | grep -q '"name":"cors"'; then
  curl -s -X POST "$KONG_ADMIN_URL/plugins" -H "Content-Type: application/json" \
    -d "{\"name\":\"cors\",\"config\":{\"origins\":[\"https://$DOMAIN\",\"http://localhost:3000\"],\"methods\":[\"GET\",\"POST\",\"PUT\",\"DELETE\",\"OPTIONS\"],\"headers\":[\"Accept\",\"Authorization\",\"Content-Type\"],\"exposed_headers\":[\"X-Auth-Token\"],\"credentials\":true,\"max_age\":3600}}"
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"api-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"api-service","url":"http://api:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/api-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"api-route","paths":["/api"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"submission-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"submission-service","url":"http://submission:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/submission-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"submission-route","paths":["/services/submission"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"transform-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"transform-service","url":"http://transform:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/transform-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"transform-route","paths":["/services/transform"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"render-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"render-service","url":"http://render:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/render-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"render-route","paths":["/services/render"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"presidio-analyzer-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"presidio-analyzer-service","url":"http://presidio-analyzer:5001"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/presidio-analyzer-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"presidio-analyzer-route","paths":["/services/presidio/analyzer"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"presidio-anonymizer-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"presidio-anonymizer-service","url":"http://presidio-anonymizer:5001"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/presidio-anonymizer-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"presidio-anonymizer-route","paths":["/services/presidio/anonymizer"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"presidio-image-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"presidio-image-service","url":"http://presidio-image-redactor:5001"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/presidio-image-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"presidio-image-route","paths":["/services/presidio/image"],"strip_path":true}'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"grapesjs-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"grapesjs-service","url":"http://grapesjs:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/grapesjs-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"grapesjs-route","paths":["/services/grapesjs"],"strip_path":true}'
fi

