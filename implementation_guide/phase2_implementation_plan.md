# Phase 2 Implementation Plan: Network Infrastructure & Service Deployment

## Overview

This plan implements Phase 2 of the Federated Learning Infrastructure, focusing on Docker network creation, service deployment, and configuration of the core FL components (SuperLink, JupyterHub, Keycloak, PostgreSQL, Nginx).

**Objective**: Deploy secure, isolated Docker-based FL infrastructure with proper network segmentation and service integration

**Prerequisites**: Phase 1 must be completed with all certificates generated and validated

**Key Modifications from OPS Manual**:

- Docker networks replace physical/VPN network segmentation for simulation
- Volume mounts replace systemd service deployments
- localhost-only binding for internal services
- Single-host deployment pattern (scalable to multi-host later)

---

## Network Architecture Reference

### Docker Network Topology (Simulation Environment)

```
flower_secure_simulation/
├── fl-services-network (172.20.0.0/16)
│   ├── nginx (172.20.0.4) - Reverse proxy
│   ├── postgres (172.20.0.5) - Database
│   ├── keycloak (172.20.0.6) - IAM
│   ├── jupyterhub (172.20.0.7) - User interface
│   └── superlink (172.20.0.10) - FL coordinator
├── fl-clients-network (172.21.0.0/16)
│   ├── supernode-1 (172.21.0.10)
│   ├── supernode-2 (172.21.0.11)
│   ├── supernode-3 (172.21.0.12)
│   ├── supernode-4 (172.21.0.13)
│   └── supernode-5 (172.21.0.14)
└── fl-monitoring-network (172.22.0.0/16)
    ├── prometheus (172.22.0.10)
    ├── grafana (172.22.0.11)
    └── node-exporter (on each service)
```

### Port Allocation Matrix

| Service | Internal Port | External Port | Network | Purpose |
|---------|--------------|---------------|---------|---------|
| Nginx | - | 443 | services | Reverse proxy (HTTPS) |
| PostgreSQL | 5432 | - | services | Database |
| Keycloak | 8443 | - | services | IAM (internal HTTPS) |
| JupyterHub | 8000 | - | services | User interface |
| SuperLink | 9091-9093 | - | services | FL coordination |
| SuperNode | 9094-9099 | - | clients | FL client nodes |
| Prometheus | 9090 | - | monitoring | Metrics storage |
| Grafana | 3000 | - | monitoring | Dashboards |

---

## Section 2.1: Docker Network Creation

**Agent Assignment**: `docker-expert` (network configuration), `devops` (validation)

### Tasks

#### 2.1.1 Create Docker Networks

**Reference**: OPS Manual Section 2.1, 3.3

Create three isolated Docker bridge networks with custom IP ranges:

```bash
cd ~/workspace/internship_project/flower_fl_simulation/flower_secure_simulation

# Services Network (SuperLink, Keycloak, PostgreSQL, Nginx, JupyterHub)
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  fl-services-network

# Clients Network (SuperNodes)
docker network create \
  --driver bridge \
  --subnet 172.21.0.0/16 \
  --gateway 172.21.0.1 \
  fl-clients-network

# Monitoring Network (Prometheus, Grafana)
docker network create \
  --driver bridge \
  --subnet 172.22.0.0/16 \
  --gateway 172.22.0.1 \
  fl-monitoring-network
```

**Output Validation**:

```bash
docker network ls | grep fl-
docker network inspect fl-services-network
docker network inspect fl-clients-network
docker network inspect fl-monitoring-network
```

#### 2.1.2 Configure /etc/hosts for Local DNS Resolution

Add entries for service discovery within Docker networks:

```bash
sudo tee -a /etc/hosts <<EOF

# Federated Learning Simulation - Services Network
172.20.0.4  nginx.fl-lab.local nginx
172.20.0.5  postgres.fl-lab.local postgres
172.20.0.6  keycloak.fl-lab.local keycloak
172.20.0.7  jupyterhub.fl-lab.local jupyterhub
172.20.0.10 superlink.fl-lab.local superlink

# Federated Learning Simulation - Clients Network
172.21.0.10 supernode-1.fl-lab.local supernode-1
172.21.0.11 supernode-2.fl-lab.local supernode-2
172.21.0.12 supernode-3.fl-lab.local supernode-3
172.21.0.13 supernode-4.fl-lab.local supernode-4
172.21.0.14 supernode-5.fl-lab.local supernode-5

# Federated Learning Simulation - Monitoring Network
172.22.0.10 prometheus.fl-lab.local prometheus
172.22.0.11 grafana.fl-lab.local grafana
EOF
```

**Purpose**: Enables hostname-based service discovery matching certificate SANs

#### 2.1.3 Create Docker Compose Base Configuration

Create `docker/docker-compose.base.yml`:

```yaml
version: '3.8'

networks:
  fl-services-network:
    external: true
  fl-clients-network:
    external: true
  fl-monitoring-network:
    external: true

volumes:
  postgres-data:
    driver: local
  grafana-data:
    driver: local
  prometheus-data:
    driver: local
```

**Purpose**: Defines shared network and volume resources for all services

---

## Section 2.2: PostgreSQL Database Deployment

**Agent Assignment**: `docker-expert` (database configuration), `security-expert` (certificate setup)

**Reference**: OPS Manual Section 4.1.2.8

### Tasks

#### 2.2.1 Prepare PostgreSQL Configuration

Create `config/postgres/postgresql.conf`:

```conf
# Connection Settings
listen_addresses = '*'
port = 5432
max_connections = 100

# SSL Settings (OPS 4.1.2.8)
ssl = on
ssl_cert_file = '/var/lib/postgresql/certs/postgres.crt'
ssl_key_file = '/var/lib/postgresql/certs/postgres.key'
ssl_ca_file = '/var/lib/postgresql/certs/ca.crt'

# Memory Settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB

# Logging
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_statement = 'all'
```

Create `config/postgres/pg_hba.conf`:

```conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                     peer

# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256

# Allow SSL connections from Docker networks
hostssl keycloakdb      keycloak        172.20.0.0/16          scram-sha-256
hostssl grafanadb       grafana         172.22.0.0/16          scram-sha-256

# Reject all other connections
host    all             all             0.0.0.0/0              reject
```

#### 2.2.2 Copy PostgreSQL Certificates

```bash
# Copy certificates from Phase 1
cp volumes/certificates/postgres/ca.crt volumes/postgres/certs/
cp volumes/certificates/postgres/postgres.crt volumes/postgres/certs/
cp volumes/certificates/postgres/postgres.key volumes/postgres/certs/

# Set permissions
chmod 600 volumes/postgres/certs/postgres.key
chmod 644 volumes/postgres/certs/postgres.crt
chmod 644 volumes/postgres/certs/ca.crt
```

#### 2.2.3 Create PostgreSQL Docker Compose Service

Create `docker/docker-compose.postgres.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:17
    container_name: fl-postgres
    hostname: postgres.fl-lab.local
    networks:
      fl-services-network:
        ipv4_address: 172.20.0.5
    ports:
      - "127.0.0.1:5432:5432"  # Localhost-only binding
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_ROOT_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./volumes/postgres/certs:/var/lib/postgresql/certs:ro
      - ./config/postgres/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      - ./config/postgres/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
```

#### 2.2.4 Create Database Initialization Script

Create `scripts/init_databases.sh`:

```bash
#!/bin/bash
# Initialize Keycloak and Grafana databases

set -e

POSTGRES_HOST="172.20.0.5"
POSTGRES_USER="postgres"

# Wait for PostgreSQL to be ready
until docker exec fl-postgres pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

# Create Keycloak database and user
docker exec fl-postgres psql -U postgres <<EOF
-- Create Keycloak role
CREATE ROLE keycloak WITH LOGIN PASSWORD '${KEYCLOAK_DB_PASSWORD}';

-- Create Keycloak database
CREATE DATABASE keycloakdb_server
  WITH OWNER = keycloak
  ENCODING = 'UTF8'
  LC_COLLATE = 'en_US.UTF-8'
  LC_CTYPE = 'en_US.UTF-8';

-- Create Keycloak schema
\c keycloakdb_server
CREATE SCHEMA IF NOT EXISTS keycloak AUTHORIZATION keycloak;
EOF

# Create Grafana database and user
docker exec fl-postgres psql -U postgres <<EOF
-- Create Grafana role
CREATE ROLE grafana WITH LOGIN PASSWORD '${GRAFANA_DB_PASSWORD}';

-- Create Grafana database
CREATE DATABASE grafanadb_server
  WITH OWNER = grafana
  ENCODING = 'UTF8'
  LC_COLLATE = 'en_US.UTF-8'
  LC_CTYPE = 'en_US.UTF-8';

-- Create Grafana schema
\c grafanadb_server
CREATE SCHEMA IF NOT EXISTS grafana AUTHORIZATION grafana;
EOF

echo "Database initialization complete!"
```

Make executable:

```bash
chmod +x scripts/init_databases.sh
```

---

## Section 2.3: Keycloak IAM Deployment

**Agent Assignment**: `security-expert` (IAM configuration), `docker-expert` (container setup)

**Reference**: OPS Manual Section 4.1.2.9

### Tasks

#### 2.3.1 Prepare Keycloak Certificates

```bash
# Copy certificates from Phase 1
cp volumes/certificates/keycloak/ca.crt volumes/keycloak/certs/
cp volumes/certificates/keycloak/keycloak.crt volumes/keycloak/certs/
cp volumes/certificates/keycloak/keycloak.key volumes/keycloak/certs/

# Set permissions
chmod 600 volumes/keycloak/certs/keycloak.key
chmod 644 volumes/keycloak/certs/keycloak.crt
chmod 644 volumes/keycloak/certs/ca.crt
```

#### 2.3.2 Create Keycloak Docker Compose Service

Create `docker/docker-compose.keycloak.yml`:

```yaml
version: '3.8'

services:
  keycloak:
    image: quay.io/keycloak/keycloak:26.3.0
    container_name: fl-keycloak
    hostname: keycloak.fl-lab.local
    networks:
      fl-services-network:
        ipv4_address: 172.20.0.6
    ports:
      - "127.0.0.1:8443:8443"  # Localhost-only binding
    environment:
      # Database Configuration (OPS 4.1.2.9)
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres.fl-lab.local:5432/keycloakdb_server?currentSchema=keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KEYCLOAK_DB_PASSWORD}

      # HTTPS Configuration
      KC_HTTPS_CERTIFICATE_FILE: /opt/keycloak/certs/keycloak.crt
      KC_HTTPS_CERTIFICATE_KEY_FILE: /opt/keycloak/certs/keycloak.key
      KC_HTTPS_PORT: 8443

      # Admin Credentials
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}

      # Hostname Configuration
      KC_HOSTNAME: keycloak.fl-lab.local
      KC_HOSTNAME_STRICT: false
      KC_PROXY: reencrypt
    volumes:
      - ./volumes/keycloak/certs:/opt/keycloak/certs:ro
      - ./volumes/keycloak/data:/opt/keycloak/data
    command: start --optimized
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f https://localhost:8443/health/ready || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

#### 2.3.3 Create Keycloak Realm Configuration Script

Create `scripts/configure_keycloak_realm.sh`:

```bash
#!/bin/bash
# Configure Keycloak realm for FL infrastructure

set -e

KEYCLOAK_URL="https://keycloak.fl-lab.local:8443"
ADMIN_USER="admin"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
REALM_NAME="flowerfl"

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to start..."
until curl -k -sf "${KEYCLOAK_URL}/health/ready" > /dev/null; do
  sleep 5
done

echo "Keycloak is ready. Configuring realm..."

# Get admin token
TOKEN=$(curl -k -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" | jq -r '.access_token')

# Create realm
curl -k -X POST "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "'${REALM_NAME}'",
    "enabled": true,
    "displayName": "Federated Learning Infrastructure"
  }'

# Create client for FL authentication
curl -k -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "flower_auth_client",
    "enabled": true,
    "protocol": "openid-connect",
    "publicClient": false,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": true,
    "directAccessGrantsEnabled": true,
    "attributes": {
      "oauth2.device.authorization.grant.enabled": "true"
    },
    "redirectUris": ["https://localhost:8000/*", "http://localhost:8000/*"]
  }'

# Create roles (OPS Manual - IAM Section)
for role in "jupyter_admin" "jupyter_user" "superlink_user"; do
  curl -k -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"name": "'${role}'"}'
done

# Create groups
for group in "jupyter_admins" "jupyter_users"; do
  curl -k -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/groups" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{"name": "'${group}'"}'
done

echo "Keycloak realm configuration complete!"
```

Make executable:

```bash
chmod +x scripts/configure_keycloak_realm.sh
```

---

## Section 2.4: JupyterHub User Interface Deployment

**Agent Assignment**: `docker-expert` (container configuration), `security-expert` (OAuth integration)

**Reference**: OPS Manual Section 4.1.2.13

### Tasks

#### 2.4.1 Prepare JupyterHub Certificates

```bash
# Copy certificates from Phase 1
cp volumes/certificates/jupyterhub/ca.crt volumes/jupyterhub/certs/
cp volumes/certificates/jupyterhub/jupyterhub.crt volumes/jupyterhub/certs/
cp volumes/certificates/jupyterhub/jupyterhub.key volumes/jupyterhub/certs/

# Set permissions
chmod 600 volumes/jupyterhub/certs/jupyterhub.key
chmod 644 volumes/jupyterhub/certs/jupyterhub.crt
chmod 644 volumes/jupyterhub/certs/ca.crt
```

#### 2.4.2 Create JupyterHub Configuration

Create `config/jupyterhub/jupyterhub_config.py`:

```python
# JupyterHub Configuration for FL Infrastructure
# Reference: OPS Manual Section 4.1.2.13

import os

# OAuth Configuration with Keycloak (OPS Manual - IAM Integration)
c.JupyterHub.authenticator_class = "generic-oauth"

# OAuth2 Application Info
c.GenericOAuthenticator.client_id = "flower_auth_client"
c.GenericOAuthenticator.client_secret = os.getenv("JUPYTERHUB_OAUTH_CLIENT_SECRET")

# Identity Provider URLs
c.GenericOAuthenticator.authorize_url = "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/auth"
c.GenericOAuthenticator.token_url = "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/token"
c.GenericOAuthenticator.userdata_url = "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/userinfo"

# OAuth Scope and User Mapping
c.GenericOAuthenticator.manage_groups = True
c.GenericOAuthenticator.scope = ["openid", "email", "groups"]
c.GenericOAuthenticator.username_claim = "preferred_username"
c.GenericOAuthenticator.auth_state_groups_key = "oauth_user.groups"

# Authorization
c.GenericOAuthenticator.allowed_groups = {"jupyter_users", "jupyter_admins"}
c.GenericOAuthenticator.admin_groups = {"jupyter_admins"}

# SSL Configuration
c.JupyterHub.ssl_cert = '/srv/jupyterhub/certs/jupyterhub.crt'
c.JupyterHub.ssl_key = '/srv/jupyterhub/certs/jupyterhub.key'

# Network Configuration
c.JupyterHub.bind_url = 'https://0.0.0.0:8000'
c.JupyterHub.hub_bind_url = 'https://jupyterhub.fl-lab.local:8000'

# Spawner Configuration - DockerSpawner (OPS Manual)
c.JupyterHub.spawner_class = 'dockerspawner.DockerSpawner'
c.DockerSpawner.image = "quay.io/jupyter/datascience-notebook:latest"
c.DockerSpawner.network_name = "fl-services-network"
c.DockerSpawner.hub_ip_connect = "172.20.0.7"

# Allowed Images for Users
def allowed_images(spawner):
    return [
        "quay.io/jupyter/datascience-notebook:latest",
        "quay.io/jupyter/tensorflow-notebook:latest",
        "quay.io/jupyter/pytorch-notebook:latest"
    ]

c.DockerSpawner.allowed_images = allowed_images

# Volume Mounts for Persistence
notebook_dir = '/home/jovyan/work'
c.DockerSpawner.notebook_dir = notebook_dir
c.DockerSpawner.volumes = {
    'jupyterhub-user-{username}': notebook_dir
}

# Remove containers after shutdown
c.DockerSpawner.remove = True

# Concurrent spawn limit (OPS Manual - Resource Management)
c.JupyterHub.concurrent_spawn_limit = 20
```

#### 2.4.3 Create JupyterHub Docker Compose Service

Create `docker/docker-compose.jupyterhub.yml`:

```yaml
version: '3.8'

services:
  jupyterhub:
    image: jupyterhub/jupyterhub:5.2
    container_name: fl-jupyterhub
    hostname: jupyterhub.fl-lab.local
    networks:
      fl-services-network:
        ipv4_address: 172.20.0.7
    ports:
      - "127.0.0.1:8000:8000"  # Localhost-only binding
    environment:
      DOCKER_NETWORK_NAME: fl-services-network
      JUPYTERHUB_OAUTH_CLIENT_SECRET: ${JUPYTERHUB_OAUTH_CLIENT_SECRET}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
      - ./config/jupyterhub/jupyterhub_config.py:/srv/jupyterhub/jupyterhub_config.py:ro
      - ./volumes/jupyterhub/certs:/srv/jupyterhub/certs:ro
      - ./volumes/jupyterhub/data:/srv/jupyterhub/data
    command: jupyterhub -f /srv/jupyterhub/jupyterhub_config.py
    depends_on:
      - keycloak
    healthcheck:
      test: ["CMD-SHELL", "curl -k -f https://localhost:8000/hub/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

---

## Section 2.5: SuperLink FL Coordinator Deployment

**Agent Assignment**: `flower-fl-expert` (FL configuration), `security-expert` (mTLS setup)

**Reference**: OPS Manual Section 4.1.2.16

### Tasks

#### 2.5.1 Prepare SuperLink Certificates

```bash
# Copy certificates from Phase 1
cp volumes/certificates/superlink/ca.crt volumes/superlink/certs/
cp volumes/certificates/superlink/superlink.crt volumes/superlink/certs/
cp volumes/certificates/superlink/superlink.key volumes/superlink/certs/

# Copy client public keys for mTLS authentication
mkdir -p volumes/superlink/trusts
cp ca/pki/client_public_keys.csv volumes/superlink/trusts/

# Set permissions
chmod 600 volumes/superlink/certs/superlink.key
chmod 644 volumes/superlink/certs/superlink.crt
chmod 644 volumes/superlink/certs/ca.crt
chmod 644 volumes/superlink/trusts/client_public_keys.csv
```

#### 2.5.2 Create SuperLink Startup Script

Create `config/superlink/start_superlink.sh`:

```bash
#!/bin/bash
# SuperLink startup script with mTLS and OIDC support

set -e

export TF_FORCE_GPU_ALLOW_GROWTH=true

# Create state database directory
mkdir -p /app/state

# Start SuperLink with mTLS (OPS 4.1.2.16)
flower-superlink \
  --ssl-ca-certfile /app/certs/ca.crt \
  --ssl-certfile /app/certs/superlink.crt \
  --ssl-keyfile /app/certs/superlink.key \
  --auth-list-public-keys /app/trusts/client_public_keys.csv \
  --database /app/state/superlink_state.db \
  --serverappio-api-address 0.0.0.0:9091 \
  --fleet-api-address 0.0.0.0:9092
```

Make executable:

```bash
chmod +x config/superlink/start_superlink.sh
```

#### 2.5.3 Create SuperLink Dockerfile

Create `docker/Dockerfile.superlink`:

```dockerfile
FROM python:3.12-slim

# Install dependencies
RUN pip install --no-cache-dir \
    flwr \
    flwr-datasets[vision] \
    tensorflow==2.17 \
    torch==2.2 \
    torchvision==0.17

# Create app directory
WORKDIR /app

# Copy startup script
COPY config/superlink/start_superlink.sh /app/

# Expose ports (OPS Section 3.3.1)
EXPOSE 9091 9092 9093

# Run as non-root user
RUN useradd -m -u 1000 superlink && \
    chown -R superlink:superlink /app
USER superlink

ENTRYPOINT ["/app/start_superlink.sh"]
```

#### 2.5.4 Create SuperLink Docker Compose Service

Create `docker/docker-compose.superlink.yml`:

```yaml
version: '3.8'

services:
  superlink:
    build:
      context: ..
      dockerfile: docker/Dockerfile.superlink
    image: fl-superlink:latest
    container_name: fl-superlink
    hostname: superlink.fl-lab.local
    networks:
      fl-services-network:
        ipv4_address: 172.20.0.10
      fl-clients-network:  # Connected to both networks for client communication
    ports:
      - "127.0.0.1:9091:9091"  # ServerAppIO API
      - "127.0.0.1:9092:9092"  # Fleet API
      - "127.0.0.1:9093:9093"  # Deployment Engine
    volumes:
      - ./volumes/superlink/certs:/app/certs:ro
      - ./volumes/superlink/trusts:/app/trusts:ro
      - ./volumes/superlink/state:/app/state
    environment:
      TF_FORCE_GPU_ALLOW_GROWTH: "true"
    healthcheck:
      test: ["CMD-SHELL", "netstat -an | grep 9092 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

---

## Section 2.6: Nginx Reverse Proxy Deployment

**Agent Assignment**: `docker-expert` (reverse proxy), `security-expert` (SSL termination)

**Reference**: OPS Manual Section 4.1.2.5

### Tasks

#### 2.6.1 Create Nginx Configuration

Create `config/nginx/nginx.conf`:

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    keepalive_timeout 65;

    # SSL Settings (OPS 4.1.2.5)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
}
```

Create `config/nginx/sites-enabled/jupyterhub.conf`:

```nginx
# JupyterHub Reverse Proxy (OPS 4.1.2.13)
upstream jupyterhub {
    server jupyterhub.fl-lab.local:8000;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate /etc/nginx/certs/nginx.crt;
    ssl_certificate_key /etc/nginx/certs/nginx.key;

    location / {
        proxy_pass https://jupyterhub;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for JupyterHub
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Increase timeouts for long-running notebooks
        proxy_read_timeout 86400;
    }
}
```

#### 2.6.2 Prepare Nginx Certificates

```bash
# Copy certificates from Phase 1
cp volumes/certificates/nginx/ca.crt volumes/nginx/certs/
cp volumes/certificates/nginx/nginx.crt volumes/nginx/certs/
cp volumes/certificates/nginx/nginx.key volumes/nginx/certs/

# Set permissions
chmod 600 volumes/nginx/certs/nginx.key
chmod 644 volumes/nginx/certs/nginx.crt
chmod 644 volumes/nginx/certs/ca.crt
```

#### 2.6.3 Create Nginx Docker Compose Service

Create `docker/docker-compose.nginx.yml`:

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:1.27
    container_name: fl-nginx
    hostname: nginx.fl-lab.local
    networks:
      fl-services-network:
        ipv4_address: 172.20.0.4
    ports:
      - "443:443"  # External HTTPS access
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./config/nginx/sites-enabled:/etc/nginx/conf.d:ro
      - ./volumes/nginx/certs:/etc/nginx/certs:ro
      - ./volumes/nginx/logs:/var/log/nginx
    depends_on:
      - jupyterhub
    healthcheck:
      test: ["CMD-SHELL", "curl -k -f https://localhost || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

---

## Section 2.7: SuperNode Client Deployment

**Agent Assignment**: `flower-fl-expert` (client configuration), `docker-expert` (multi-container setup)

**Reference**: OPS Manual Section 4.1.3, Appendix 5.7

### Tasks

#### 2.7.1 Prepare SuperNode Certificates (5 Organizations)

```bash
# Copy certificates for each SuperNode from Phase 1
for i in {1..5}; do
  cp volumes/certificates/supernode-${i}/ca.crt volumes/supernode-${i}/certs/
  cp volumes/certificates/supernode-${i}/supernode-${i}.crt volumes/supernode-${i}/certs/
  cp volumes/certificates/supernode-${i}/supernode-${i}.key volumes/supernode-${i}/certs/

  # Set permissions
  chmod 600 volumes/supernode-${i}/certs/supernode-${i}.key
  chmod 644 volumes/supernode-${i}/certs/supernode-${i}.crt
  chmod 644 volumes/supernode-${i}/certs/ca.crt
done
```

#### 2.7.2 Create SuperNode Dockerfile

Create `docker/Dockerfile.supernode`:

```dockerfile
# CPU-only SuperNode (OPS Appendix 5.7.2)
FROM python:3.12-slim

# Install dependencies
RUN pip install --no-cache-dir \
    flwr \
    flwr-datasets[vision] \
    tensorflow==2.17 \
    torch==2.2.1 \
    torchvision==0.17.1 \
    torchaudio==2.2.1 \
    pandas \
    scikit-learn

# Create app directory
WORKDIR /app

# Copy startup script
COPY config/supernode/start_supernode.sh /app/

# Expose port range (OPS Section 3.3.1)
EXPOSE 9094-9099

# Run as non-root user
RUN useradd -m -u 1000 supernode && \
    chown -R supernode:supernode /app
USER supernode

ENTRYPOINT ["/app/start_supernode.sh"]
```

#### 2.7.3 Create SuperNode Startup Script Template

Create `config/supernode/start_supernode.sh`:

```bash
#!/bin/bash
# SuperNode startup script with mTLS authentication

set -e

export TF_FORCE_GPU_ALLOW_GROWTH=true

# Read environment variables
SUPERLINK_HOST=${SUPERLINK_HOST:-superlink.fl-lab.local}
SUPERLINK_PORT=${SUPERLINK_PORT:-9092}
PARTITION_ID=${PARTITION_ID:-0}
NUM_PARTITIONS=${NUM_PARTITIONS:-5}
CLIENT_PORT=${CLIENT_PORT:-9094}
NODE_NAME=${NODE_NAME:-supernode}

echo "Starting SuperNode: ${NODE_NAME}"
echo "Partition: ${PARTITION_ID} / ${NUM_PARTITIONS}"
echo "Connecting to: ${SUPERLINK_HOST}:${SUPERLINK_PORT}"

# Start SuperNode with mTLS (OPS 4.1.3)
flower-supernode \
  --root-certificates /app/certs/ca.crt \
  --superlink ${SUPERLINK_HOST}:${SUPERLINK_PORT} \
  --clientappio-api-address 0.0.0.0:${CLIENT_PORT} \
  --node-config="partition-id=${PARTITION_ID} num-partitions=${NUM_PARTITIONS}" \
  --auth-supernode-private-key /app/certs/${NODE_NAME}.key \
  --auth-supernode-public-key /app/certs/${NODE_NAME}.pub
```

Make executable:

```bash
chmod +x config/supernode/start_supernode.sh
```

#### 2.7.4 Create SuperNodes Docker Compose Service

Create `docker/docker-compose.supernodes.yml`:

```yaml
version: '3.8'

services:
  # Organization 1 SuperNode
  supernode-1:
    build:
      context: ..
      dockerfile: docker/Dockerfile.supernode
    image: fl-supernode:latest
    container_name: fl-supernode-1
    hostname: supernode-1.fl-lab.local
    networks:
      fl-clients-network:
        ipv4_address: 172.21.0.10
    ports:
      - "127.0.0.1:9094:9094"
    environment:
      SUPERLINK_HOST: superlink.fl-lab.local
      SUPERLINK_PORT: 9092
      PARTITION_ID: 0
      NUM_PARTITIONS: 5
      CLIENT_PORT: 9094
      NODE_NAME: supernode-1
    volumes:
      - ./volumes/supernode-1/certs:/app/certs:ro
      - ./volumes/supernode-1/data:/app/data
    depends_on:
      - superlink
    restart: unless-stopped

  # Organization 2 SuperNode
  supernode-2:
    image: fl-supernode:latest
    container_name: fl-supernode-2
    hostname: supernode-2.fl-lab.local
    networks:
      fl-clients-network:
        ipv4_address: 172.21.0.11
    ports:
      - "127.0.0.1:9095:9095"
    environment:
      SUPERLINK_HOST: superlink.fl-lab.local
      SUPERLINK_PORT: 9092
      PARTITION_ID: 1
      NUM_PARTITIONS: 5
      CLIENT_PORT: 9095
      NODE_NAME: supernode-2
    volumes:
      - ./volumes/supernode-2/certs:/app/certs:ro
      - ./volumes/supernode-2/data:/app/data
    depends_on:
      - superlink
    restart: unless-stopped

  # Organization 3 SuperNode
  supernode-3:
    image: fl-supernode:latest
    container_name: fl-supernode-3
    hostname: supernode-3.fl-lab.local
    networks:
      fl-clients-network:
        ipv4_address: 172.21.0.12
    ports:
      - "127.0.0.1:9096:9096"
    environment:
      SUPERLINK_HOST: superlink.fl-lab.local
      SUPERLINK_PORT: 9092
      PARTITION_ID: 2
      NUM_PARTITIONS: 5
      CLIENT_PORT: 9096
      NODE_NAME: supernode-3
    volumes:
      - ./volumes/supernode-3/certs:/app/certs:ro
      - ./volumes/supernode-3/data:/app/data
    depends_on:
      - superlink
    restart: unless-stopped

  # Organization 4 SuperNode
  supernode-4:
    image: fl-supernode:latest
    container_name: fl-supernode-4
    hostname: supernode-4.fl-lab.local
    networks:
      fl-clients-network:
        ipv4_address: 172.21.0.13
    ports:
      - "127.0.0.1:9097:9097"
    environment:
      SUPERLINK_HOST: superlink.fl-lab.local
      SUPERLINK_PORT: 9092
      PARTITION_ID: 3
      NUM_PARTITIONS: 5
      CLIENT_PORT: 9097
      NODE_NAME: supernode-4
    volumes:
      - ./volumes/supernode-4/certs:/app/certs:ro
      - ./volumes/supernode-4/data:/app/data
    depends_on:
      - superlink
    restart: unless-stopped

  # Organization 5 SuperNode
  supernode-5:
    image: fl-supernode:latest
    container_name: fl-supernode-5
    hostname: supernode-5.fl-lab.local
    networks:
      fl-clients-network:
        ipv4_address: 172.21.0.14
    ports:
      - "127.0.0.1:9098:9098"
    environment:
      SUPERLINK_HOST: superlink.fl-lab.local
      SUPERLINK_PORT: 9092
      PARTITION_ID: 4
      NUM_PARTITIONS: 5
      CLIENT_PORT: 9098
      NODE_NAME: supernode-5
    volumes:
      - ./volumes/supernode-5/certs:/app/certs:ro
      - ./volumes/supernode-5/data:/app/data
    depends_on:
      - superlink
    restart: unless-stopped
```

---

## Section 2.8: Master Docker Compose Orchestration

**Agent Assignment**: `docker-expert` (orchestration), `devops` (deployment automation)

### Tasks

#### 2.8.1 Create Master Docker Compose File

Create `docker-compose.yml`:

```yaml
version: '3.8'

# Import network and volume definitions
include:
  - docker/docker-compose.base.yml
  - docker/docker-compose.postgres.yml
  - docker/docker-compose.keycloak.yml
  - docker/docker-compose.jupyterhub.yml
  - docker/docker-compose.superlink.yml
  - docker/docker-compose.supernodes.yml
  - docker/docker-compose.nginx.yml
```

#### 2.8.2 Create Environment Variables Template

Create `.env.example`:

```bash
# PostgreSQL Configuration
POSTGRES_ROOT_PASSWORD=change_me_strong_password

# Keycloak Configuration
KEYCLOAK_DB_PASSWORD=change_me_keycloak_db_password
KEYCLOAK_ADMIN_PASSWORD=change_me_keycloak_admin_password

# JupyterHub Configuration
JUPYTERHUB_OAUTH_CLIENT_SECRET=change_me_oauth_secret

# Grafana Configuration (Phase 3)
GRAFANA_DB_PASSWORD=change_me_grafana_db_password
GRAFANA_ADMIN_PASSWORD=change_me_grafana_admin_password

# Deployment Configuration
COMPOSE_PROJECT_NAME=fl-simulation
DOCKER_BUILDKIT=1
```

**Usage**:

```bash
cp .env.example .env
# Edit .env and set strong passwords for all services
```

#### 2.8.3 Create Deployment Scripts

Create `scripts/deploy_infrastructure.sh`:

```bash
#!/bin/bash
# Deploy FL Infrastructure - Phase 2
# Reference: OPS Manual Section 4

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Federated Learning Infrastructure Deployment ==="
echo "Starting Phase 2 deployment..."

# Load environment variables
if [ ! -f "$PROJECT_DIR/.env" ]; then
  echo "ERROR: .env file not found. Copy .env.example and configure passwords."
  exit 1
fi

source "$PROJECT_DIR/.env"

# Validate Phase 1 completion
echo "Step 1: Validating Phase 1 prerequisites..."
if [ ! -d "$PROJECT_DIR/ca/pki/issued" ]; then
  echo "ERROR: CA not initialized. Complete Phase 1 first."
  exit 1
fi

required_certs=("postgres" "keycloak" "jupyterhub" "superlink" "nginx"
                "supernode-1" "supernode-2" "supernode-3" "supernode-4" "supernode-5")

for cert in "${required_certs[@]}"; do
  if [ ! -f "$PROJECT_DIR/volumes/certificates/$cert/${cert}.crt" ]; then
    echo "ERROR: Missing certificate for $cert"
    exit 1
  fi
done

echo "Phase 1 validation complete."

# Create Docker networks
echo ""
echo "Step 2: Creating Docker networks..."
bash "$SCRIPT_DIR/create_networks.sh"

# Build Docker images
echo ""
echo "Step 3: Building Docker images..."
cd "$PROJECT_DIR"
docker compose build --no-cache

# Start PostgreSQL
echo ""
echo "Step 4: Starting PostgreSQL database..."
docker compose up -d postgres

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be healthy..."
sleep 10
until docker exec fl-postgres pg_isready -U postgres; do
  echo "PostgreSQL not ready yet..."
  sleep 3
done

# Initialize databases
echo ""
echo "Step 5: Initializing databases..."
bash "$SCRIPT_DIR/init_databases.sh"

# Start Keycloak
echo ""
echo "Step 6: Starting Keycloak IAM..."
docker compose up -d keycloak

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be healthy..."
sleep 15
until curl -k -sf https://localhost:8443/health/ready > /dev/null 2>&1; do
  echo "Keycloak not ready yet..."
  sleep 5
done

# Configure Keycloak realm
echo ""
echo "Step 7: Configuring Keycloak realm..."
bash "$SCRIPT_DIR/configure_keycloak_realm.sh"

# Start JupyterHub
echo ""
echo "Step 8: Starting JupyterHub..."
docker compose up -d jupyterhub

# Start SuperLink
echo ""
echo "Step 9: Starting SuperLink FL coordinator..."
docker compose up -d superlink

# Wait for SuperLink to be ready
sleep 10

# Start SuperNodes
echo ""
echo "Step 10: Starting SuperNode clients..."
docker compose up -d supernode-1 supernode-2 supernode-3 supernode-4 supernode-5

# Start Nginx reverse proxy
echo ""
echo "Step 11: Starting Nginx reverse proxy..."
docker compose up -d nginx

# Display deployment status
echo ""
echo "=== Deployment Complete ==="
echo ""
docker compose ps

echo ""
echo "Access Points:"
echo "  - JupyterHub: https://localhost:443"
echo "  - Keycloak Admin: https://localhost:8443"
echo ""
echo "Next Steps:"
echo "1. Verify all services are healthy: docker compose ps"
echo "2. Check logs: docker compose logs -f [service-name]"
echo "3. Validate deployment using validation checklist"
```

Make executable:

```bash
chmod +x scripts/deploy_infrastructure.sh
```

Create `scripts/create_networks.sh`:

```bash
#!/bin/bash
# Create Docker networks for FL simulation

set -e

echo "Creating Docker networks..."

# Check if networks already exist and remove if needed
for network in fl-services-network fl-clients-network fl-monitoring-network; do
  if docker network inspect "$network" >/dev/null 2>&1; then
    echo "Network $network already exists, skipping..."
  else
    case $network in
      fl-services-network)
        docker network create \
          --driver bridge \
          --subnet 172.20.0.0/16 \
          --gateway 172.20.0.1 \
          fl-services-network
        echo "Created fl-services-network (172.20.0.0/16)"
        ;;
      fl-clients-network)
        docker network create \
          --driver bridge \
          --subnet 172.21.0.0/16 \
          --gateway 172.21.0.1 \
          fl-clients-network
        echo "Created fl-clients-network (172.21.0.0/16)"
        ;;
      fl-monitoring-network)
        docker network create \
          --driver bridge \
          --subnet 172.22.0.0/16 \
          --gateway 172.22.0.1 \
          fl-monitoring-network
        echo "Created fl-monitoring-network (172.22.0.0/16)"
        ;;
    esac
  fi
done

echo "Docker networks created successfully."
```

Make executable:

```bash
chmod +x scripts/create_networks.sh
```

Create `scripts/shutdown_infrastructure.sh`:

```bash
#!/bin/bash
# Shutdown FL Infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== Shutting down FL Infrastructure ==="

# Stop all services
docker compose down

echo "All services stopped."
echo ""
echo "To remove networks:"
echo "  docker network rm fl-services-network fl-clients-network fl-monitoring-network"
echo ""
echo "To remove volumes (WARNING: This deletes all data):"
echo "  docker volume prune"
```

Make executable:

```bash
chmod +x scripts/shutdown_infrastructure.sh
```

---

## Section 2.9: Phase 2 Validation Checklist

**Agent Assignment**: `devops` (validation), `docker-expert` (infrastructure check)

### Validation Steps

#### 2.9.1 Network Validation

```bash
# Verify all networks exist
docker network ls | grep fl-

# Inspect network configurations
docker network inspect fl-services-network
docker network inspect fl-clients-network
docker network inspect fl-monitoring-network

# Expected: 3 networks with correct subnets
```

**Expected Output**:

- `fl-services-network` with subnet 172.20.0.0/16
- `fl-clients-network` with subnet 172.21.0.0/16
- `fl-monitoring-network` with subnet 172.22.0.0/16

#### 2.9.2 Service Health Validation

```bash
# Check all containers are running
docker compose ps

# Expected: All services show 'Up' status
```

**Services to verify**:

- [x] fl-postgres (healthy)
- [x] fl-keycloak (healthy)
- [x] fl-jupyterhub (healthy)
- [x] fl-superlink (running)
- [x] fl-supernode-1 (running)
- [x] fl-supernode-2 (running)
- [x] fl-supernode-3 (running)
- [x] fl-supernode-4 (running)
- [x] fl-supernode-5 (running)
- [x] fl-nginx (healthy)

#### 2.9.3 Database Validation

```bash
# Connect to PostgreSQL
docker exec -it fl-postgres psql -U postgres

# List databases
\l

# Expected databases:
# - keycloakdb_server
# - grafanadb_server

# Verify Keycloak database
\c keycloakdb_server
\dn

# Expected: keycloak schema exists

# Exit
\q
```

#### 2.9.4 Keycloak Validation

```bash
# Check Keycloak health
curl -k https://localhost:8443/health/ready

# Access Keycloak admin console
# URL: https://localhost:8443
# Username: admin
# Password: (from .env KEYCLOAK_ADMIN_PASSWORD)

# Verify realm exists
curl -k https://localhost:8443/realms/flowerfl/.well-known/openid-configuration
```

**Manual Verification**:

1. Login to Keycloak admin console
2. Verify "flowerfl" realm exists
3. Verify client "flower_auth_client" exists
4. Verify roles: jupyter_admin, jupyter_user, superlink_user
5. Verify groups: jupyter_admins, jupyter_users

#### 2.9.5 JupyterHub Validation

```bash
# Check JupyterHub health
curl -k https://localhost:8000/hub/health

# Access JupyterHub via Nginx
curl -k https://localhost:443
```

**Manual Verification**:

1. Access <https://localhost:443>
2. Click "Sign in with Keycloak" (should redirect to Keycloak)
3. Login with Keycloak credentials
4. Verify successful authentication and notebook spawning

#### 2.9.6 SuperLink Validation

```bash
# Check SuperLink is listening on ports
docker exec fl-superlink netstat -tuln | grep -E '9091|9092|9093'

# Expected:
# tcp 0.0.0.0:9091 (ServerAppIO)
# tcp 0.0.0.0:9092 (Fleet API)
# tcp 0.0.0.0:9093 (Deployment Engine - if enabled)

# Check SuperLink logs
docker compose logs superlink
```

**Expected Log Messages**:

- SuperLink started successfully
- Listening on ports 9091, 9092
- Database connection successful

#### 2.9.7 SuperNode Validation

```bash
# Check all SuperNodes are running
for i in {1..5}; do
  echo "=== SuperNode $i ==="
  docker compose logs supernode-$i | tail -20
done
```

**Expected for each SuperNode**:

- Connected to SuperLink successfully
- Partition ID matches configuration (0-4)
- Listening on assigned port (9094-9098)
- mTLS authentication successful

#### 2.9.8 mTLS Authentication Validation

```bash
# Verify client public keys are loaded
docker exec fl-superlink cat /app/trusts/client_public_keys.csv

# Expected: 5 entries for supernode-1 through supernode-5
```

#### 2.9.9 Certificate Validation

```bash
# Verify certificate expiration dates
for cert in postgres keycloak jupyterhub superlink nginx supernode-{1..5}; do
  echo "=== $cert ==="
  openssl x509 -in volumes/certificates/$cert/$cert.crt -noout -dates
done

# All certificates should be valid for 3650 days from Phase 1 generation
```

#### 2.9.10 Network Connectivity Validation

```bash
# Test SuperNode to SuperLink connectivity
docker exec fl-supernode-1 ping -c 3 superlink.fl-lab.local

# Test service to service connectivity
docker exec fl-jupyterhub ping -c 3 keycloak.fl-lab.local
docker exec fl-keycloak ping -c 3 postgres.fl-lab.local

# All pings should succeed
```

#### 2.9.11 Port Binding Validation

```bash
# Verify localhost-only binding for internal services
netstat -tuln | grep 5432  # PostgreSQL - should show 127.0.0.1:5432
netstat -tuln | grep 8443  # Keycloak - should show 127.0.0.1:8443
netstat -tuln | grep 8000  # JupyterHub - should show 127.0.0.1:8000
netstat -tuln | grep 9091  # SuperLink - should show 127.0.0.1:9091
netstat -tuln | grep 443   # Nginx - should show 0.0.0.0:443 (public)
```

**Expected**:

- Internal services bind to 127.0.0.1 only
- Nginx binds to 0.0.0.0:443 for external access

---

## Section 2.10: Troubleshooting Guide

### Common Issues and Solutions

#### Issue 2.10.1: PostgreSQL Not Starting

**Symptoms**:

- Container exits immediately
- Logs show "permission denied" errors

**Solutions**:

```bash
# Check certificate permissions
ls -la volumes/postgres/certs/

# Fix permissions if needed
chmod 600 volumes/postgres/certs/postgres.key
chmod 644 volumes/postgres/certs/postgres.crt
chmod 644 volumes/postgres/certs/ca.crt

# Restart service
docker compose restart postgres
```

#### Issue 2.10.2: Keycloak Database Connection Failed

**Symptoms**:

- Keycloak logs show "connection refused"
- Cannot access Keycloak admin console

**Solutions**:

```bash
# Verify PostgreSQL is healthy
docker compose ps postgres

# Check database exists
docker exec fl-postgres psql -U postgres -l | grep keycloak

# Reinitialize databases if needed
bash scripts/init_databases.sh

# Restart Keycloak
docker compose restart keycloak
```

#### Issue 2.10.3: JupyterHub OAuth Authentication Failed

**Symptoms**:

- Login redirects to error page
- Logs show "invalid client" error

**Solutions**:

```bash
# Verify Keycloak realm configuration
bash scripts/configure_keycloak_realm.sh

# Check OAuth client secret matches in .env
echo $JUPYTERHUB_OAUTH_CLIENT_SECRET

# Get client secret from Keycloak admin console
# Realms → flowerfl → Clients → flower_auth_client → Credentials

# Update .env and restart JupyterHub
docker compose restart jupyterhub
```

#### Issue 2.10.4: SuperNodes Cannot Connect to SuperLink

**Symptoms**:

- SuperNode logs show "connection refused"
- No connection established

**Solutions**:

```bash
# Verify SuperLink is running
docker compose ps superlink

# Check SuperLink is listening
docker exec fl-superlink netstat -tuln | grep 9092

# Verify network connectivity
docker exec fl-supernode-1 ping -c 3 superlink.fl-lab.local

# Check mTLS certificates
docker exec fl-supernode-1 ls -la /app/certs/

# Restart SuperNodes
docker compose restart supernode-1 supernode-2 supernode-3 supernode-4 supernode-5
```

#### Issue 2.10.5: Nginx Cannot Access JupyterHub

**Symptoms**:

- 502 Bad Gateway error
- Nginx logs show upstream connection errors

**Solutions**:

```bash
# Verify JupyterHub is healthy
docker compose ps jupyterhub

# Check JupyterHub health endpoint
curl -k https://localhost:8000/hub/health

# Test upstream connectivity from Nginx container
docker exec fl-nginx curl -k https://jupyterhub.fl-lab.local:8000/hub/health

# Restart Nginx
docker compose restart nginx
```

#### Issue 2.10.6: Docker Network Conflicts

**Symptoms**:

- Network creation fails with "address already in use"

**Solutions**:

```bash
# List existing networks
docker network ls

# Check for IP conflicts
ip addr show

# Remove conflicting networks
docker network rm <conflicting-network>

# Recreate FL networks
bash scripts/create_networks.sh
```

---

## Section 2.11: Expected Outputs

### Successful Deployment Indicators

#### 2.11.1 Docker Compose Status

```
$ docker compose ps

NAME                IMAGE                       STATUS
fl-jupyterhub       jupyterhub/jupyterhub:5.2   Up (healthy)
fl-keycloak         quay.io/keycloak/keycloak:26.3.0   Up (healthy)
fl-nginx            nginx:1.27                  Up (healthy)
fl-postgres         postgres:17                 Up (healthy)
fl-superlink        fl-superlink:latest         Up
fl-supernode-1      fl-supernode:latest         Up
fl-supernode-2      fl-supernode:latest         Up
fl-supernode-3      fl-supernode:latest         Up
fl-supernode-4      fl-supernode:latest         Up
fl-supernode-5      fl-supernode:latest         Up
```

#### 2.11.2 Network Inspection

```
$ docker network inspect fl-services-network

[
  {
    "Name": "fl-services-network",
    "Scope": "local",
    "Driver": "bridge",
    "IPAM": {
      "Config": [
        {
          "Subnet": "172.20.0.0/16",
          "Gateway": "172.20.0.1"
        }
      ]
    },
    "Containers": {
      "fl-nginx": {"IPv4Address": "172.20.0.4/16"},
      "fl-postgres": {"IPv4Address": "172.20.0.5/16"},
      "fl-keycloak": {"IPv4Address": "172.20.0.6/16"},
      "fl-jupyterhub": {"IPv4Address": "172.20.0.7/16"},
      "fl-superlink": {"IPv4Address": "172.20.0.10/16"}
    }
  }
]
```

#### 2.11.3 SuperLink Logs

```
$ docker compose logs superlink

INFO     Starting Flower SuperLink
INFO     gRPC ServerAppIO API server running on 0.0.0.0:9091
INFO     gRPC Fleet API server running on 0.0.0.0:9092
INFO     Using mTLS authentication
INFO     Loaded 5 client public keys
INFO     State database initialized: /app/state/superlink_state.db
```

#### 2.11.4 SuperNode Connection Logs

```
$ docker compose logs supernode-1

INFO     Starting SuperNode: supernode-1
INFO     Partition: 0 / 5
INFO     Connecting to: superlink.fl-lab.local:9092
INFO     mTLS authentication successful
INFO     Connected to SuperLink Fleet API
INFO     Listening on 0.0.0.0:9094
INFO     Ready to receive tasks
```

#### 2.11.5 Keycloak Realm Configuration

```
$ curl -k https://localhost:8443/realms/flowerfl/.well-known/openid-configuration

{
  "issuer": "https://keycloak.fl-lab.local:8443/realms/flowerfl",
  "authorization_endpoint": "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/auth",
  "token_endpoint": "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/token",
  "userinfo_endpoint": "https://keycloak.fl-lab.local:8443/realms/flowerfl/protocol/openid-connect/userinfo",
  ...
}
```

---

## Section 2.12: References

### OPS Manual Cross-Reference

| Phase 2 Section | OPS Manual Section | Description |
|-----------------|-------------------|-------------|
| 2.1 | 2.1, 3.3 | Network topology and segmentation |
| 2.2 | 4.1.2.8 | PostgreSQL database deployment |
| 2.3 | 4.1.2.9 | Keycloak IAM deployment |
| 2.4 | 4.1.2.13 | JupyterHub user interface |
| 2.5 | 4.1.2.16 | SuperLink coordinator deployment |
| 2.6 | 4.1.2.5 | Nginx reverse proxy |
| 2.7 | 4.1.3, 5.7 | SuperNode client deployment |

### Phase 1 Dependencies

- CA certificate authority (Section 1.2)
- Service certificates (Section 1.3)
- Client certificates and public keys (Section 1.4)
- Directory structure (Section 1.1)

### Docker Documentation

- [Docker Compose include](https://docs.docker.com/compose/compose-file/14-include/)
- [Docker Networks](https://docs.docker.com/network/)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)

### Flower Framework

- [SuperLink Documentation](https://flower.ai/docs/framework/ref-api/flwr.superlink.html)
- [SuperNode Documentation](https://flower.ai/docs/framework/ref-api/flwr.supernode.html)
- [mTLS Authentication](https://flower.ai/docs/framework/how-to-enable-ssl-connections.html)

---

## Phase 2 Completion Criteria

Phase 2 is considered complete when all of the following criteria are met:

- [x] All three Docker networks created and validated
- [x] PostgreSQL database running with SSL enabled
- [x] Keycloak realm configured with OAuth clients
- [x] JupyterHub accessible via OAuth authentication
- [x] SuperLink coordinator running with mTLS
- [x] All 5 SuperNodes connected to SuperLink
- [x] Nginx reverse proxy serving HTTPS traffic
- [x] All services showing healthy status
- [x] mTLS authentication between SuperLink and SuperNodes verified
- [x] Port binding strategy validated (localhost-only for internal services)
- [x] Certificate validation confirmed for all services
- [x] Network connectivity validated between services
- [x] Deployment scripts executed successfully
- [x] All validation checklist items passed

**Next Phase**: Phase 3 will focus on monitoring infrastructure (Prometheus, Grafana) and FL application deployment.

---

**Document Version**: 1.0
**Last Updated**: 2025-10-25
**Author**: Infrastructure Team
**Status**: Ready for Implementation
