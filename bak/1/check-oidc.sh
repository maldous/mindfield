#!/bin/bash
set -euo pipefail

# OIDC Authentication Validation Script
# ====================================
# This script validates that all services are properly protected with OIDC authentication
# through Kong Gateway and Keycloak.
#
# KEYCLOAK CONFIGURATION REQUIREMENTS:
# ------------------------------------
# 1. Keycloak Realm: 'mindfield' must exist
# 2. OIDC Client: 'mindfield' must be configured with:
#    - Client ID: mindfield
#    - Client Secret: (from OIDC_CLIENT_SECRET in .env)
#    - Valid Redirect URIs:
#      * https://api.aldous.info/callback
#      * https://aldous.info/callback
#      * https://grafana.aldous.info/callback
#      * https://minio-console.aldous.info/callback
#      * https://pgadmin.aldous.info/callback
#      * https://prometheus.aldous.info/callback
#    - Web Origins: All service domains (https://*.aldous.info)
#    - Access Type: confidential
#    - Standard Flow Enabled: ON
#    - Direct Access Grants: OFF (recommended)
#
# 3. Admin User: Created via KC_BOOTSTRAP_ADMIN_USERNAME/PASSWORD
#
# BOOTSTRAP AUTOMATION:
# --------------------
# The setup.sh script creates .env with bootstrap credentials:
# - KC_BOOTSTRAP_ADMIN_USERNAME=admin
# - KC_BOOTSTRAP_ADMIN_PASSWORD=ChangeMe!
# - OIDC_CLIENT_SECRET=(auto-generated)
#
# To access Keycloak admin console for configuration:
# 1. SSH tunnel: ssh -L 3019:localhost:3019 user@server
# 2. Access: http://localhost:3019
# 3. Login with admin/ChangeMe!
#
# CURRENT PROTECTION STATUS:
# -------------------------
# - Keycloak: Direct access (needed for OIDC provider)
# - Kong Admin: Direct access (for configuration)
# - All other services: Protected via Kong OIDC plugin

DOMAIN=${DOMAIN:-"aldous.info"}
SERVICES=(
    "$DOMAIN"
    "api.$DOMAIN"
    "grafana.$DOMAIN"
    "minio-console.$DOMAIN"
    "pgadmin.$DOMAIN"
    "prometheus.$DOMAIN"
)

echo "🔐 Checking OIDC Authentication for all services..."
echo "Domain: $DOMAIN"
echo

# Function to check if a service redirects to Keycloak for authentication
check_service() {
    local service_url="https://$1"
    local service_name="$1"
    
    echo -n "Checking $service_name... "
    
    # Follow redirects and check if we end up at Keycloak
    response=$(curl -s -L -w "%{url_effective}|%{http_code}" "$service_url" || echo "ERROR|000")
    
    final_url=$(echo "$response" | cut -d'|' -f1)
    http_code=$(echo "$response" | cut -d'|' -f2)
    
    if [[ "$final_url" == *"keycloak.$DOMAIN"* ]] && [[ "$final_url" == *"/auth"* ]]; then
        echo "✅ PROTECTED (redirects to Keycloak)"
        return 0
    elif [[ "$http_code" == "401" ]] || [[ "$http_code" == "403" ]]; then
        echo "✅ PROTECTED (returns $http_code)"
        return 0
    elif [[ "$http_code" == "200" ]]; then
        echo "❌ NOT PROTECTED (direct access allowed)"
        return 1
    else
        echo "⚠️  UNKNOWN (HTTP $http_code)"
        return 1
    fi
}

# Check Keycloak is accessible
echo "Checking Keycloak accessibility..."
keycloak_response=$(curl -s -w "%{http_code}" "https://keycloak.$DOMAIN" -o /dev/null || echo "000")
if [[ "$keycloak_response" == "200" ]] || [[ "$keycloak_response" == "302" ]]; then
    echo "✅ Keycloak is accessible at https://keycloak.$DOMAIN (HTTP $keycloak_response)"
else
    echo "❌ Keycloak is not accessible (HTTP $keycloak_response)"
    exit 1
fi

echo

# Check Kong admin is accessible
echo "Checking Kong admin accessibility..."
kong_response=$(curl -s -w "%{http_code}" "https://kong.$DOMAIN" -o /dev/null || echo "000")
if [[ "$kong_response" == "200" ]]; then
    echo "✅ Kong admin is accessible at https://kong.$DOMAIN"
else
    echo "❌ Kong admin is not accessible (HTTP $kong_response)"
fi

echo

# Check each service
failed_services=()
for service in "${SERVICES[@]}"; do
    if ! check_service "$service"; then
        failed_services+=("$service")
    fi
done

echo
echo "📊 Summary:"
echo "Total services checked: ${#SERVICES[@]}"
echo "Protected services: $((${#SERVICES[@]} - ${#failed_services[@]}))"
echo "Unprotected services: ${#failed_services[@]}"

if [[ ${#failed_services[@]} -eq 0 ]]; then
    echo
    echo "🎉 SUCCESS: All services are properly protected with OIDC authentication!"
    exit 0
else
    echo
    echo "❌ FAILED: The following services are NOT protected:"
    for service in "${failed_services[@]}"; do
        echo "  - $service"
    done
    echo
    echo "Please check Kong configuration and ensure all routes are properly configured."
    exit 1
fi
