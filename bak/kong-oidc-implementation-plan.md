# Kong OIDC Implementation Plan for MicroK8s

## Overview
Implement Kong OIDC authentication with Keycloak for MicroK8s, requiring all client connections to be fully authenticated.

## 1. Custom Kong Image with OIDC Plugin

### Create Custom Dockerfile
- Build Kong image with `kong-oidc` plugin (more mature than oidcify)
- Install lua-resty-openidc dependency
- Configure plugin loading

### Update Kong Helm Values
- Switch to custom image
- Enable OIDC plugin in plugins list
- Configure environment variables for OIDC

## 2. Keycloak Configuration

### Update Keycloak Deployment
- Ensure Keycloak is accessible via Kong
- Configure realm and clients
- Set up proper redirect URIs

### Create OIDC Clients
- Create Kubernetes Job to configure Keycloak clients
- Generate client secrets and store in Kubernetes secrets
- Configure scopes and roles

## 3. Kong OIDC Configuration

### Create KongPlugin Resources
- Global OIDC plugin for all services
- Service-specific OIDC configurations
- Configure discovery endpoint, client credentials

### Update Kong Services and Routes
- Create HTTPRoutes for services requiring authentication
- Apply OIDC plugin to routes
- Configure callback URLs

## 4. Secrets Management

### Create Kubernetes Secrets
- OIDC client secrets
- Cookie encryption keys
- Session management secrets

### Environment Variables
- Configure Kong with OIDC environment variables
- Set Keycloak endpoints and realm information

## 5. Network Configuration

### Update Network Policies
- Allow Kong to communicate with Keycloak
- Configure ingress for OIDC callbacks
- Ensure proper TLS termination

### DNS and Certificates
- Configure proper hostnames for OIDC redirects
- Ensure SSL certificates are valid for all endpoints

## 6. Service Integration

### Protected Services
- PostGraphile: Configure OIDC protection
- Admin interfaces: PgAdmin, monitoring tools
- API endpoints: Secure all backend services

### Callback Handling
- Configure Kong to handle OIDC callbacks
- Set up session management
- Configure logout flows

## 7. Testing and Validation

### Authentication Flow Testing
- Test login/logout flows
- Verify token validation
- Test session management

### Service Access Testing
- Verify all services require authentication
- Test unauthorized access blocking
- Validate proper redirects

## Implementation Steps

1. Create custom Kong Docker image with kong-oidc plugin
2. Update Kong Helm configuration to use custom image
3. Configure Keycloak realm and clients via Kubernetes Job
4. Create OIDC secrets and configuration
5. Deploy Kong with OIDC plugin enabled
6. Create HTTPRoutes with OIDC protection
7. Test authentication flows
8. Apply OIDC to all services requiring protection