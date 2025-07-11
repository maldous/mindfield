#!/bin/bash

# Kong Admin URL
KONG_ADMIN_URL=${KONG_ADMIN_URL:-http://kong:8001}

# Wait for Kong to be ready
echo "Waiting for Kong to be ready..."
until curl -s ${KONG_ADMIN_URL}/status > /dev/null; do
  sleep 2
done

echo "Kong is ready. Configuring services and routes..."

# Configure Keycloak plugin for authentication
# Check if OIDC plugin already exists
if ! curl -s ${KONG_ADMIN_URL}/plugins | grep -q '"name":"oidc"'; then
  curl -X POST ${KONG_ADMIN_URL}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "oidc",
    "config": {
      "issuer": "https://keycloak.aldous.info/realms/mindfield",
      "client_id": "kong",
      "client_secret": "kong_secret",
      "redirect_uri": "https://api.aldous.info/callback",
      "scope": "openid profile email"
    }
  }'

fi

# Configure rate limiting plugin globally
# Check if rate-limiting plugin already exists
if ! curl -s ${KONG_ADMIN_URL}/plugins | grep -q '"name":"rate-limiting"'; then
  curl -X POST ${KONG_ADMIN_URL}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 100,
      "hour": 10000,
      "policy": "local"
    }
  }'

fi

# Configure CORS plugin globally
# Check if CORS plugin already exists
if ! curl -s ${KONG_ADMIN_URL}/plugins | grep -q '"name":"cors"'; then
  curl -X POST ${KONG_ADMIN_URL}/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cors",
    "config": {
      "origins": ["https://aldous.info", "http://localhost:3000"],
      "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      "headers": ["Accept", "Authorization", "Content-Type"],
      "exposed_headers": ["X-Auth-Token"],
      "credentials": true,
      "max_age": 3600
    }
  }'

fi

# API Service
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"api-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "api-service",
    "url": "http://api:3000"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/api-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "api-route",
    "paths": ["/api"],
    "strip_path": true
  }'

fi

# Submission Service
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"submission-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "submission-service",
    "url": "http://submission:3000"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/submission-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "submission-route",
    "paths": ["/services/submission"],
    "strip_path": true
  }'

fi

# Transform Service
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"transform-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "transform-service",
    "url": "http://transform:3000"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/transform-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "transform-route",
    "paths": ["/services/transform"],
    "strip_path": true
  }'

fi

# Render Service
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"render-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "render-service",
    "url": "http://render:3000"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/render-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "render-route",
    "paths": ["/services/render"],
    "strip_path": true
  }'

fi

# Presidio Services
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"presidio-analyzer-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-analyzer-service",
    "url": "http://presidio-analyzer:5001"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/presidio-analyzer-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-analyzer-route",
    "paths": ["/services/presidio/analyzer"],
    "strip_path": true
  }'

fi

if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"presidio-anonymizer-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-anonymizer-service",
    "url": "http://presidio-anonymizer:5001"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/presidio-anonymizer-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-anonymizer-route",
    "paths": ["/services/presidio/anonymizer"],
    "strip_path": true
  }'

fi

if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"presidio-image-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-image-service",
    "url": "http://presidio-image-redactor:5001"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/presidio-image-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "presidio-image-route",
    "paths": ["/services/presidio/image"],
    "strip_path": true
  }'

fi

# GrapesJS Service
if ! curl -s ${KONG_ADMIN_URL}/services | grep -q '"name":"grapesjs-service"'; then
  curl -X POST ${KONG_ADMIN_URL}/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "grapesjs-service",
    "url": "http://grapesjs:3000"
  }'

  curl -X POST ${KONG_ADMIN_URL}/services/grapesjs-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "grapesjs-route",
    "paths": ["/services/grapesjs"],
    "strip_path": true
  }'

fi

echo "Kong configuration complete!"
