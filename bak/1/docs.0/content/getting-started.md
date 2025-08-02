# Getting Started

## Prerequisites

Before setting up MindField, ensure you have:

- **Docker** and **Docker Compose** installed
- **Domain** with DNS management capabilities
- **Ports 80 and 443** available on your server
- **Git** for cloning the repository

## Quick Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd mindfield
```

### 2. Initial Setup

```bash
./setup.sh
```

This creates a `.env` file with production-ready defaults.

### 3. Configure Environment

Edit `.env` with your specific settings:

```bash
# Required: Your domain
DOMAIN=yourdomain.com
LETSENCRYPT_EMAIL=your-email@domain.com

# Database credentials (change defaults)
MINDFIELD_POSTGRES_PASSWORD=your-secure-password
KEYCLOAK_ADMIN_PASSWORD=your-admin-password
```

### 4. Start Services

**Production Mode (Recommended)**

```bash
make start
```

All services accessible via HTTPS through Caddy reverse proxy.

**Development Mode**

```bash
make dev
```

Services exposed on individual ports for development.

### 5. Verify Installation

```bash
# Check service status
docker compose ps

# View logs
make logs

# Access main application
open https://yourdomain.com
```

## First-Time Configuration

### 1. Keycloak Setup

1. Access: `https://keycloak.yourdomain.com`
2. Login with admin credentials from `.env`
3. Create realm: `mindfield`
4. Configure clients for each service

### 2. DNS Configuration

Ensure A records point to your server for all subdomains:

```
yourdomain.com
api.yourdomain.com
keycloak.yourdomain.com
grafana.yourdomain.com
# ... (see full list in main documentation)
```

### 3. SSL Certificates

Caddy automatically obtains Let's Encrypt certificates for all configured domains.

## Development Setup

For local development with exposed ports:

```bash
# Start in development mode
make dev

# View available ports
make ports

# Access services directly
open http://localhost:3000  # Web app
open http://localhost:3007  # Grafana
open http://localhost:3017  # Keycloak
```

## Next Steps

- [Architecture Overview](architecture.md) - Understand the system design
- [Development Guide](development.md) - Learn development workflows
- [Operations Guide](operations.md) - Production management
- [API Reference](api.md) - Service APIs and endpoints
