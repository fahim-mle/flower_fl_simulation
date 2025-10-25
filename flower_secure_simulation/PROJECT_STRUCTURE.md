# Federated Learning Infrastructure - Project Structure

## Overview

This directory contains the secure federated learning infrastructure with PKI-based authentication, isolated from the main simulation directory. All components use Docker containers with mTLS for secure communication.

## Directory Layout

```
flower_secure_simulation/
├── ca/                                 # Certificate Authority (local PKI)
│   ├── easyrsa                        # Easy-RSA executable
│   └── pki/                           # PKI directory structure
│       ├── ca.crt                     # Root CA certificate (public)
│       ├── private/                   # NEVER commit to git
│       │   └── ca.key                 # CA private key (600 permissions)
│       ├── issued/                    # Service certificates
│       │   ├── superlink.crt
│       │   ├── postgres.crt
│       │   ├── keycloak.crt
│       │   ├── jupyterhub.crt
│       │   ├── nginx.crt
│       │   └── supernode-{1..5}.crt
│       ├── private/                   # Service private keys (600)
│       │   ├── superlink.key
│       │   ├── postgres.key
│       │   ├── keycloak.key
│       │   ├── jupyterhub.key
│       │   ├── nginx.key
│       │   └── supernode-{1..5}.key
│       └── reqs/                      # Certificate requests
│
├── config/                            # Service configurations
│   ├── nginx/
│   │   ├── sites-available/          # Available site configs
│   │   ├── sites-enabled/            # Enabled site configs (symlinks)
│   │   └── ssl/                      # SSL/TLS configuration files
│   ├── keycloak/                     # Keycloak realm and client configs
│   ├── jupyterhub/                   # JupyterHub configuration
│   ├── prometheus/                   # Prometheus monitoring config
│   ├── grafana/                      # Grafana dashboards
│   ├── superlink/                    # Flower SuperLink config
│   └── supernode/                    # Flower SuperNode config
│
├── volumes/                           # Docker persistent storage
│   ├── postgres/                     # PostgreSQL data
│   ├── keycloak/                     # Keycloak data
│   ├── jupyterhub/                   # JupyterHub user data
│   ├── nginx/                        # Nginx logs and cache
│   ├── prometheus/                   # Prometheus time-series data
│   ├── grafana/                      # Grafana dashboards
│   └── certificates/                 # Certificate distribution
│       ├── superlink/                # {ca.crt, superlink.crt, superlink.key}
│       ├── postgres/                 # {ca.crt, postgres.crt, postgres.key}
│       ├── keycloak/                 # {ca.crt, keycloak.crt, keycloak.key}
│       ├── jupyterhub/               # {ca.crt, jupyterhub.crt, jupyterhub.key}
│       ├── nginx/                    # {ca.crt, nginx.crt, nginx.key}
│       └── supernode-{1..5}/         # {ca.crt, supernode-X.crt, supernode-X.key}
│
├── docker/                            # Docker configurations
│   ├── networks.yml                  # Network definitions
│   ├── docker-compose.yml            # Main service orchestration (to be created)
│   └── Dockerfile.*                  # Custom Dockerfiles (if needed)
│
├── scripts/                           # Automation scripts
│   ├── generate_service_cert.sh      # Certificate generation helper
│   ├── verify_certificates.sh        # Certificate validation
│   └── rotate_certificates.sh        # Certificate rotation (future)
│
└── logs/                              # Application logs
    ├── superlink/
    ├── supernodes/
    ├── nginx/
    └── keycloak/
```

## Network Architecture

### Docker Networks (defined in docker/networks.yml)

| Network | Subnet | Gateway | Purpose |
|---------|--------|---------|---------|
| fl-services-network | 172.20.0.0/16 | 172.20.0.1 | Main services (SuperLink, Keycloak, PostgreSQL, Nginx, JupyterHub) |
| fl-clients-network | 172.21.0.0/16 | 172.21.0.1 | SuperNode clients (5 organizations) |
| fl-monitoring-network | 172.22.0.0/16 | 172.22.0.1 | Monitoring stack (Prometheus, Grafana) |

### IP Allocation Plan

#### FL Services Network (172.20.0.0/16)

- 172.20.0.1: Gateway
- 172.20.0.4: Nginx (reverse proxy)
- 172.20.0.5: PostgreSQL (database)
- 172.20.0.6: Keycloak (identity)
- 172.20.0.7: JupyterHub (user interface)
- 172.20.0.10: SuperLink (FL coordinator)

#### FL Clients Network (172.21.0.0/16)

- 172.21.0.1: Gateway
- 172.21.0.10: SuperNode-1 (Organization 1)
- 172.21.0.11: SuperNode-2 (Organization 2)
- 172.21.0.12: SuperNode-3 (Organization 3)
- 172.21.0.13: SuperNode-4 (Organization 4)
- 172.21.0.14: SuperNode-5 (Organization 5)

#### FL Monitoring Network (172.22.0.0/16)

- 172.22.0.1: Gateway
- 172.22.0.10: Prometheus (metrics)
- 172.22.0.11: Grafana (dashboards)

## Port Allocation

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| Nginx (HTTPS) | 443 | TCP | Reverse proxy SSL termination |
| JupyterHub | 443 (external), 8000 (internal) | TCP | User interface |
| Keycloak | 8443 | TCP | Identity & Access Management |
| PostgreSQL | 5432 | TCP | Database backend |
| SuperLink | 9091, 9092, 9093 | TCP | FL coordination service |
| SuperNode | 9094-9099 | TCP | FL client nodes |
| Prometheus | 9090 | TCP | Metrics collection |
| Grafana | 3000 | TCP | Monitoring dashboards |

## Security Architecture

### PKI Certificate Hierarchy

```
Root CA (Federated Learning Root CA)
├── Server Certificates
│   ├── superlink.fl-lab.local (FL coordinator)
│   ├── postgres.fl-lab.local (database)
│   ├── keycloak.fl-lab.local (identity)
│   ├── jupyterhub.fl-lab.local (user interface)
│   └── nginx.fl-lab.local (reverse proxy)
└── Client Certificates
    ├── supernode-1.fl-lab.local (Organization 1)
    ├── supernode-2.fl-lab.local (Organization 2)
    ├── supernode-3.fl-lab.local (Organization 3)
    ├── supernode-4.fl-lab.local (Organization 4)
    └── supernode-5.fl-lab.local (Organization 5)
```

### Certificate Specifications

- **Key Type**: RSA
- **Key Size**: 4096 bits
- **Digest Algorithm**: SHA-512
- **CA Validity**: 3650 days (10 years)
- **Certificate Validity**: 825 days (~27 months)
- **Subject Alternative Names (SANs)**:
  - Docker service name (e.g., `superlink`)
  - FQDN (e.g., `superlink.fl-lab.local`)
  - localhost (for local testing)
  - IP address (from network allocation)

### mTLS Communication Flow

1. **SuperNode → SuperLink**:
   - SuperNode presents client certificate (supernode-X.crt)
   - SuperLink verifies certificate against CA
   - SuperLink presents server certificate (superlink.crt)
   - SuperNode verifies server certificate
   - Encrypted bidirectional communication established

2. **Services → PostgreSQL**:
   - Services connect with SSL enabled
   - PostgreSQL validates client certificates
   - Encrypted database connections

3. **External → Nginx**:
   - Nginx terminates SSL/TLS
   - Proxies to backend services
   - Backend services use mTLS

## Certificate Management

### Certificate Files per Service

Each service volume contains:

- `ca.crt` - Root CA certificate (public, 644 permissions)
- `{service}.crt` - Service certificate (public, 644 permissions)
- `{service}.key` - Private key (secret, 600 permissions)

### Certificate Distribution

Certificates are copied from CA to service volumes:

```bash
ca/pki/ca.crt → volumes/certificates/{service}/ca.crt
ca/pki/issued/{service}.crt → volumes/certificates/{service}/{service}.crt
ca/pki/private/{service}.key → volumes/certificates/{service}/{service}.key
```

### Certificate Rotation

Certificates expire after 825 days. Rotation procedure:

1. Generate new certificate with same Common Name
2. Deploy to service volume
3. Restart service to load new certificate
4. Revoke old certificate (optional)

## Security Best Practices

### File Permissions

- **Private keys**: 600 (read/write owner only)
- **Certificates**: 644 (readable by all, writable by owner)
- **CA private key**: 600 and stored in `ca/pki/private/` (NEVER distribute)

### Git Security

The following are excluded from version control (`.gitignore`):

- `ca/pki/private/` - CA and service private keys
- `*.key` - All private key files
- `volumes/certificates/*/` - Certificate distribution directories
- Sensitive configuration files with credentials

### Docker Volume Security

- Use named volumes for sensitive data
- Restrict container user privileges (non-root when possible)
- Mount certificate volumes read-only where applicable
- Use Docker secrets for sensitive environment variables

## Organization Mapping

| Organization ID | SuperNode | Certificate CN | IP Address |
|----------------|-----------|----------------|------------|
| Organization 1 | supernode-1 | supernode-1.fl-lab.local | 172.21.0.10 |
| Organization 2 | supernode-2 | supernode-2.fl-lab.local | 172.21.0.11 |
| Organization 3 | supernode-3 | supernode-3.fl-lab.local | 172.21.0.12 |
| Organization 4 | supernode-4 | supernode-4.fl-lab.local | 172.21.0.13 |
| Organization 5 | supernode-5 | supernode-5.fl-lab.local | 172.21.0.14 |

## References

- OPS Manual Section 4.1.1: Directory Structure
- OPS Manual Section 4.1.2.2: Certificate Authority Setup
- OPS Manual Section 3.3.1: Network Protocols and Ports
- Phase 1 Implementation Plan: `/home/ghost/workspace/internship_project/flower_fl_simulation/implementation_guide/phase1_implementation_plan.md`

## Changelog

- **2025-10-25**: Phase 1 - Initial directory structure and CA setup
