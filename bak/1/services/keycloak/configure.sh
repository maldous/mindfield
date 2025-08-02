#!/bin/bash
set -euo pipefail

# Keycloak Bootstrap Script
# =========================
# This script configures the Keycloak 'mindfield' client with proper OIDC settings
# for use with Kong Gateway authentication.

DOMAIN=${DOMAIN:-"aldous.info"}
KEYCLOAK_URL=${KEYCLOAK_URL:-"https://keycloak.$DOMAIN"}
ADMIN_USER=${KC_BOOTSTRAP_ADMIN_USERNAME:-"admin"}
ADMIN_PASS=${KC_BOOTSTRAP_ADMIN_PASSWORD:-"ChangeMe!"}
CLIENT_ID=${OIDC_CLIENT_ID:-"mindfield"}
CLIENT_SECRET=${OIDC_CLIENT_SECRET:-""}

if [[ -z "$CLIENT_SECRET" ]]; then
    echo "❌ OIDC_CLIENT_SECRET not set in environment"
    exit 1
fi

echo "🔐 Bootstrapping Keycloak OIDC client configuration..."
echo "Domain: $DOMAIN"
echo "Keycloak URL: $KEYCLOAK_URL"
echo "Client ID: $CLIENT_ID"
echo

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
until curl -s "$KEYCLOAK_URL/realms/master" >/dev/null 2>&1; do
    echo "   Waiting for Keycloak..."
    sleep 5
done
echo "✅ Keycloak is ready"

# Get admin access token
echo "🔑 Getting admin access token..."
ADMIN_TOKEN=$(curl -s -d "client_id=admin-cli" \
    -d "username=$ADMIN_USER" \
    -d "password=$ADMIN_PASS" \
    -d "grant_type=password" \
    "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | \
    jq -r '.access_token')

if [[ "$ADMIN_TOKEN" == "null" || -z "$ADMIN_TOKEN" ]]; then
    echo "❌ Failed to get admin token. Check credentials."
    exit 1
fi
echo "✅ Admin token obtained"

# Check if mindfield realm exists, create if not
echo "🏰 Checking mindfield realm..."
REALM_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/mindfield" | jq -r '.realm // empty')

if [[ -z "$REALM_EXISTS" ]]; then
    echo "   Creating mindfield realm..."
    curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$KEYCLOAK_URL/admin/realms" \
        -d '{
            "realm": "mindfield",
            "enabled": true,
            "displayName": "MindField",
            "registrationAllowed": false,
            "loginWithEmailAllowed": true,
            "duplicateEmailsAllowed": false,
            "resetPasswordAllowed": true,
            "editUsernameAllowed": false,
            "bruteForceProtected": true
        }'
    echo "✅ Mindfield realm created"
else
    echo "✅ Mindfield realm already exists"
fi

# Check if mindfield client exists
echo "🔧 Checking mindfield client..."
CLIENT_EXISTS=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$KEYCLOAK_URL/admin/realms/mindfield/clients" | \
    jq -r ".[] | select(.clientId==\"$CLIENT_ID\") | .id")

if [[ -z "$CLIENT_EXISTS" ]]; then
    echo "   Creating mindfield client..."
    curl -s -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$KEYCLOAK_URL/admin/realms/mindfield/clients" \
        -d "{
            \"clientId\": \"$CLIENT_ID\",
            \"enabled\": true,
            \"clientAuthenticatorType\": \"client-secret\",
            \"secret\": \"$CLIENT_SECRET\",
            \"redirectUris\": [
                \"https://api.$DOMAIN/callback\",
                \"https://$DOMAIN/callback\",
                \"https://grafana.$DOMAIN/callback\",
                \"https://minio-console.$DOMAIN/callback\",
                \"https://pgadmin.$DOMAIN/callback\",
                \"https://prometheus.$DOMAIN/callback\"
            ],
            \"webOrigins\": [
                \"https://$DOMAIN\",
                \"https://api.$DOMAIN\",
                \"https://grafana.$DOMAIN\",
                \"https://minio-console.$DOMAIN\",
                \"https://pgadmin.$DOMAIN\",
                \"https://prometheus.$DOMAIN\"
            ],
            \"standardFlowEnabled\": true,
            \"implicitFlowEnabled\": false,
            \"directAccessGrantsEnabled\": false,
            \"serviceAccountsEnabled\": false,
            \"publicClient\": false,
            \"protocol\": \"openid-connect\",
            \"fullScopeAllowed\": true
        }"
    echo "✅ Mindfield client created"
else
    echo "   Updating existing mindfield client..."
    curl -s -X PUT -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$KEYCLOAK_URL/admin/realms/mindfield/clients/$CLIENT_EXISTS" \
        -d "{
            \"clientId\": \"$CLIENT_ID\",
            \"enabled\": true,
            \"clientAuthenticatorType\": \"client-secret\",
            \"secret\": \"$CLIENT_SECRET\",
            \"redirectUris\": [
                \"https://api.$DOMAIN/callback\",
                \"https://$DOMAIN/callback\",
                \"https://grafana.$DOMAIN/callback\",
                \"https://minio-console.$DOMAIN/callback\",
                \"https://pgadmin.$DOMAIN/callback\",
                \"https://prometheus.$DOMAIN/callback\"
            ],
            \"webOrigins\": [
                \"https://$DOMAIN\",
                \"https://api.$DOMAIN\",
                \"https://grafana.$DOMAIN\",
                \"https://minio-console.$DOMAIN\",
                \"https://pgadmin.$DOMAIN\",
                \"https://prometheus.$DOMAIN\"
            ],
            \"standardFlowEnabled\": true,
            \"implicitFlowEnabled\": false,
            \"directAccessGrantsEnabled\": false,
            \"serviceAccountsEnabled\": false,
            \"publicClient\": false,
            \"protocol\": \"openid-connect\",
            \"fullScopeAllowed\": true
        }"
    echo "✅ Mindfield client updated"
fi

echo
echo "🎉 Keycloak bootstrap completed successfully!"
echo
echo "📋 Configuration Summary:"
echo "   Realm: mindfield"
echo "   Client ID: $CLIENT_ID"
echo "   Client Secret: $CLIENT_SECRET"
echo "   Redirect URIs: https://api.$DOMAIN/callback (and others)"
echo
echo "🔗 Access Keycloak admin console:"
echo "   SSH tunnel: ssh -L 3019:localhost:3019 user@server"
echo "   URL: http://localhost:3019"
echo "   Login: $ADMIN_USER / $ADMIN_PASS"
