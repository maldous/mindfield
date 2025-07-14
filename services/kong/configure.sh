#!/usr/bin/env bash
set -euo pipefail

KONG_ADMIN_URL=http://kong:8001

until curl -s "$KONG_ADMIN_URL/status" >/dev/null; do sleep 2; done

# Remove global OIDC plugin - apply per service instead
# Global OIDC causes session_secret issues

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
  # Add oidcify protection to api service
  curl -s -X POST "$KONG_ADMIN_URL/services/api-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://api.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"submission-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"submission-service","url":"http://submission:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/submission-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"submission-route","paths":["/services/submission"],"strip_path":true}'
  # Add oidcify protection to submission service
  curl -s -X POST "$KONG_ADMIN_URL/services/submission-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://'"$DOMAIN"'/services/submission/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"transform-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"transform-service","url":"http://transform:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/transform-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"transform-route","paths":["/services/transform"],"strip_path":true}'
  # Add oidcify protection to transform service
  curl -s -X POST "$KONG_ADMIN_URL/services/transform-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://'"$DOMAIN"'/services/transform/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"render-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"render-service","url":"http://render:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/render-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"render-route","paths":["/services/render"],"strip_path":true}'
  # Add oidcify protection to render service
  curl -s -X POST "$KONG_ADMIN_URL/services/render-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://'"$DOMAIN"'/services/render/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
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
  # Add oidcify protection to grapesjs service
  curl -s -X POST "$KONG_ADMIN_URL/services/grapesjs-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://grapesjs.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

# Create Kong consumer for oidcify
if ! curl -s "$KONG_ADMIN_URL/consumers" | grep -q '"username":"oidc-user"'; then
  curl -s -X POST "$KONG_ADMIN_URL/consumers" -H "Content-Type: application/json" \
    -d '{"username":"oidc-user"}'
fi

# Add protected routes for all services
if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"web-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"web-service","url":"http://web:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/web-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"web-route","hosts":["'"$DOMAIN"'"],"strip_path":false}'
  # Add oidcify protection to web service
  curl -s -X POST "$KONG_ADMIN_URL/services/web-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"grafana-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"grafana-service","url":"http://grafana:3000"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/grafana-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"grafana-route","hosts":["grafana.'"$DOMAIN"'"],"strip_path":false}'
  # Add oidcify protection to grafana service
  curl -s -X POST "$KONG_ADMIN_URL/services/grafana-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://grafana.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"minio-console-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"minio-console-service","url":"http://minio:9001"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/minio-console-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"minio-console-route","hosts":["minio-console.'"$DOMAIN"'"],"strip_path":false}'
  # Add oidcify protection to minio-console service
  curl -s -X POST "$KONG_ADMIN_URL/services/minio-console-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://minio-console.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"pgadmin-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"pgadmin-service","url":"http://pgadmin:80"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/pgadmin-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"pgadmin-route","hosts":["pgadmin.'"$DOMAIN"'"],"strip_path":false}'
  # Add oidcify protection to pgadmin service
  curl -s -X POST "$KONG_ADMIN_URL/services/pgadmin-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://pgadmin.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

if ! curl -s "$KONG_ADMIN_URL/services" | grep -q '"name":"prometheus-service"'; then
  curl -s -X POST "$KONG_ADMIN_URL/services" -H "Content-Type: application/json" \
    -d '{"name":"prometheus-service","url":"http://prometheus:9090"}'
  curl -s -X POST "$KONG_ADMIN_URL/services/prometheus-service/routes" -H "Content-Type: application/json" \
    -d '{"name":"prometheus-route","hosts":["prometheus.'"$DOMAIN"'"],"strip_path":false}'
  # Add oidcify protection to prometheus service
  curl -s -X POST "$KONG_ADMIN_URL/services/prometheus-service/plugins" -H "Content-Type: application/json" \
    -d '{
      "name": "oidcify",
      "config": {
        "issuer": "http://keycloak:8080/realms/mindfield",
        "client_id": "'"$OIDC_CLIENT_ID"'",
        "client_secret": "'"$OIDC_CLIENT_SECRET"'",
        "redirect_uri": "https://prometheus.'"$DOMAIN"'/cb",
        "consumer_name": "oidc-user",
        "scopes": ["openid", "profile", "email"],
        "cookie_hash_key_hex": "3f7a1c9d2b4e5f6a7b8c9d0e1f2a3b4c",
        "cookie_block_key_hex": "4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d"
      }
    }'
fi

