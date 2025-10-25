# Phase 1 Implementation Plan: Project Foundation & Certificate Authority

## Overview

This plan implements Phase 1 of the Federated Learning Infrastructure, focusing on establishing the foundational project structure, Certificate Authority (CA), and service certificates for secure mTLS communication across all FL components.

**Objective**: Replicate OPS manual PKI in project directory with Docker adaptations

**Key Modifications from OPS Manual**:

- CA location: `./ca/` (project-based) instead of `/usr/share/easy-rsa` (system-wide)
- Deployment model: Docker containers with volume mounts instead of systemd services
- Network model: Docker networks with localhost access instead of physical/VPN segmentation

---

## Network Configuration Reference

### IP Ranges (from instruction.md)

- **FL Services Network**: `172.20.0.0/16` - Main services (SuperLink, Keycloak, PostgreSQL, Nginx)
- **FL Clients Network**: `172.21.0.0/16` - SuperNode clients
- **FL Monitoring Network**: `172.22.0.0/16` - Monitoring stack (Prometheus, Grafana)

### Port Allocation (from FL_FLWR_OPS Section 3.3.1)

| Service | Port(s) | Protocol | Purpose |
|---------|---------|----------|---------|
| SSH | 22 | TCP | System administration |
| Nginx (HTTPS) | 443 | TCP | Reverse proxy SSL termination |
| JupyterHub | 443 (external), 8000 (internal) | TCP | User interface |
| Keycloak | 8443 | TCP | Identity & Access Management |
| PostgreSQL | 5432 | TCP | Database backend |
| SuperLink | 9091, 9092, 9093 | TCP | FL coordination service |
| SuperNode | 9094-9099 | TCP | FL client nodes |
| OpenVPN | 1194 (UDP), 443 (TCP) | UDP/TCP | Secure networking |
| Prometheus | 9090, 9091, 9093, 9900 | TCP | Metrics collection |
| Grafana | 3000 | TCP | Monitoring dashboards |

---

## Section 1.1: Project Structure Setup

**Agent Assignment**: `devops` (infrastructure setup), `docker-expert` (volume configuration)

### Tasks

#### 1.1.1 Create Root Project Directory Structure

```bash
mkdir -p flower_secure_simulation/{ca,config,volumes,docker,scripts,logs}
```

#### 1.1.2 Create Certificate Authority Directory

```bash
mkdir -p ca/{pki,issued,private,reqs}
```

**Purpose**: Local CA for generating all service and client certificates (OPS 4.1.2.2)

#### 1.1.3 Create Docker Volume Directories

```bash
mkdir -p volumes/{postgres,keycloak,jupyterhub,nginx,prometheus,grafana}
mkdir -p volumes/certificates/{superlink,supernode-{1..5},keycloak,jupyterhub,nginx,postgres}
```

**Purpose**: Persistent storage and certificate distribution to containers

#### 1.1.4 Create Configuration Directories

```bash
mkdir -p config/{nginx,keycloak,jupyterhub,prometheus,grafana,superlink,supernode}
mkdir -p config/nginx/{sites-available,sites-enabled,ssl}
```

**Purpose**: Service-specific configuration files (OPS 4.1.1)

#### 1.1.5 Create Docker Network Definitions

Create `docker/networks.yml`:

```yaml
networks:
  fl-services-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
          gateway: 172.20.0.1

  fl-clients-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16
          gateway: 172.21.0.1

  fl-monitoring-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.22.0.0/16
          gateway: 172.22.0.1
```

#### 1.1.6 Create Directory Structure Documentation

Document the directory layout in `PROJECT_STRUCTURE.md` following OPS 4.1.1 conventions.

---

## Section 1.2: Certificate Authority Setup (OPS 4.1.2.2 Adapted)

**Agent Assignment**: `security` (PKI implementation), `docker-expert` (volume mounting strategy)

### Prerequisites

- Ubuntu 24.04 LTS or compatible Linux distribution
- OpenSSL installed
- easy-rsa 3.x package

### Tasks

#### 1.2.1 Install easy-rsa Locally

```bash
sudo apt-get update
sudo apt-get install -y easy-rsa openssl
```

**Note**: Install on host system, NOT in containers (OPS 4.1.2.2)

#### 1.2.2 Initialize PKI in Project Directory

```bash
cd ./ca
cp -r /usr/share/easy-rsa/* .
./easyrsa init-pki
```

**Output**: Creates `pki/` directory structure for certificate management

#### 1.2.3 Configure CA Variables

Create `./ca/pki/vars` with organization details:

```bash
cat > ./ca/pki/vars << 'EOF'
set_var EASYRSA_REQ_COUNTRY    "AU"
set_var EASYRSA_REQ_PROVINCE   "Queensland"
set_var EASYRSA_REQ_CITY       "Brisbane"
set_var EASYRSA_REQ_ORG        "Federated Learning Lab"
set_var EASYRSA_REQ_EMAIL      "admin@fl-lab.local"
set_var EASYRSA_REQ_OU         "FL Infrastructure"
set_var EASYRSA_KEY_SIZE       4096
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    825
set_var EASYRSA_DIGEST         "sha512"
EOF
```

**Security Note**: 4096-bit keys and SHA-512 for production-grade security (OPS 4.1.2.2)

#### 1.2.4 Build Certificate Authority

```bash
cd ./ca
./easyrsa build-ca nopass
```

**Interactive Prompts**:

- Common Name: `Federated Learning Root CA`

**Output Files**:

- `pki/ca.crt` - CA certificate (distribute to all services)
- `pki/private/ca.key` - CA private key (NEVER distribute, secure this file)

#### 1.2.5 Secure CA Private Key

```bash
chmod 600 ./ca/pki/private/ca.key
chmod 644 ./ca/pki/ca.crt
```

#### 1.2.6 Distribute CA Certificate to Volume Mounts

```bash
for dir in volumes/certificates/*/; do
    cp ./ca/pki/ca.crt "$dir/ca.crt"
done
```

**Purpose**: All containers need CA cert to verify mTLS connections

---

## Section 1.3: Service Certificate Generation

**Agent Assignment**: `security` (certificate generation), `fl-expert` (Flower-specific certs), `docker-expert` (DNS/SAN configuration)

### Certificate Strategy

- **Subject Alternative Names (SANs)**: Docker service names + localhost + IP addresses
- **Certificate Types**:
  - Server certificates for services (SuperLink, Keycloak, PostgreSQL, Nginx, JupyterHub)
  - Client certificates for SuperNodes (organization-specific)
- **Naming Convention**: `{service-name}.fl-lab.local` for Docker DNS resolution

### Tasks

#### 1.3.1 Create Certificate Generation Script

Create `./scripts/generate_service_cert.sh`:

```bash
#!/bin/bash
# Usage: ./generate_service_cert.sh <service-name> <san-entries>

SERVICE_NAME=$1
SAN_ENTRIES=$2

cd ./ca

# Generate certificate request and key
./easyrsa --subject-alt-name="$SAN_ENTRIES" build-server-full "$SERVICE_NAME" nopass

# Copy to service volume
cp pki/issued/${SERVICE_NAME}.crt ../volumes/certificates/${SERVICE_NAME}/
cp pki/private/${SERVICE_NAME}.key ../volumes/certificates/${SERVICE_NAME}/
cp pki/ca.crt ../volumes/certificates/${SERVICE_NAME}/

# Set permissions
chmod 644 ../volumes/certificates/${SERVICE_NAME}/${SERVICE_NAME}.crt
chmod 600 ../volumes/certificates/${SERVICE_NAME}/${SERVICE_NAME}.key
chmod 644 ../volumes/certificates/${SERVICE_NAME}/ca.crt

echo "Certificate generated for $SERVICE_NAME"
```

Make executable:

```bash
chmod +x ./scripts/generate_service_cert.sh
```

#### 1.3.2 Generate SuperLink Certificate (OPS 4.1.2.16)

```bash
./scripts/generate_service_cert.sh superlink \
    "DNS:superlink,DNS:superlink.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.10"
```

**Purpose**: FL coordination service on ports 9091-9093

#### 1.3.3 Generate PostgreSQL Certificate (OPS 4.1.2.8)

```bash
./scripts/generate_service_cert.sh postgres \
    "DNS:postgres,DNS:postgres.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.5"
```

**Purpose**: Database backend with SSL connections

#### 1.3.4 Generate Keycloak Certificate (OPS 4.1.2.9)

```bash
./scripts/generate_service_cert.sh keycloak \
    "DNS:keycloak,DNS:keycloak.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.6"
```

**Purpose**: Identity and Access Management on port 8443

#### 1.3.5 Generate JupyterHub Certificate (OPS 4.1.2.13)

```bash
./scripts/generate_service_cert.sh jupyterhub \
    "DNS:jupyterhub,DNS:jupyterhub.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.7"
```

**Purpose**: User interface on port 8000 (internal)

#### 1.3.6 Generate Nginx Certificate (OPS 4.1.2.5)

```bash
./scripts/generate_service_cert.sh nginx \
    "DNS:nginx,DNS:nginx.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.4"
```

**Purpose**: Reverse proxy SSL termination on port 443

#### 1.3.7 Generate SuperNode Client Certificates (OPS 4.1.3, Appendix 5.7)

```bash
# Organization 1
mkdir -p volumes/certificates/supernode-1
./scripts/generate_service_cert.sh supernode-1 \
    "DNS:supernode-1,DNS:supernode-1.fl-lab.local,IP:172.21.0.10"

# Organization 2
mkdir -p volumes/certificates/supernode-2
./scripts/generate_service_cert.sh supernode-2 \
    "DNS:supernode-2,DNS:supernode-2.fl-lab.local,IP:172.21.0.11"

# Organization 3
mkdir -p volumes/certificates/supernode-3
./scripts/generate_service_cert.sh supernode-3 \
    "DNS:supernode-3,DNS:supernode-3.fl-lab.local,IP:172.21.0.12"

# Organization 4
mkdir -p volumes/certificates/supernode-4
./scripts/generate_service_cert.sh supernode-4 \
    "DNS:supernode-4,DNS:supernode-4.fl-lab.local,IP:172.21.0.13"

# Organization 5
mkdir -p volumes/certificates/supernode-5
./scripts/generate_service_cert.sh supernode-5 \
    "DNS:supernode-5,DNS:supernode-5.fl-lab.local,IP:172.21.0.14"
```

**Purpose**: Client authentication for FL training nodes (5 organizations)

#### 1.3.8 Verify Certificate Generation

Create verification script `./scripts/verify_certificates.sh`:

```bash
#!/bin/bash
# Verify all certificates are properly generated

SERVICES=("superlink" "postgres" "keycloak" "jupyterhub" "nginx" "supernode-1" "supernode-2" "supernode-3" "supernode-4" "supernode-5")

echo "=== Certificate Verification Report ==="
for service in "${SERVICES[@]}"; do
    CERT_PATH="./volumes/certificates/${service}/${service}.crt"
    KEY_PATH="./volumes/certificates/${service}/${service}.key"
    CA_PATH="./volumes/certificates/${service}/ca.crt"

    echo ""
    echo "Service: $service"

    if [ -f "$CERT_PATH" ]; then
        echo "  ✓ Certificate exists"
        # Check expiry
        EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
        echo "  Expires: $EXPIRY"
        # Check SANs
        echo "  Subject Alternative Names:"
        openssl x509 -text -noout -in "$CERT_PATH" | grep -A1 "Subject Alternative Name"
    else
        echo "  ✗ Certificate missing"
    fi

    if [ -f "$KEY_PATH" ]; then
        echo "  ✓ Private key exists"
    else
        echo "  ✗ Private key missing"
    fi

    if [ -f "$CA_PATH" ]; then
        echo "  ✓ CA certificate exists"
    else
        echo "  ✗ CA certificate missing"
    fi
done

echo ""
echo "=== CA Certificate Info ==="
openssl x509 -text -noout -in ./ca/pki/ca.crt | grep -E "(Subject:|Issuer:|Not Before|Not After)"
```

Make executable and run:

```bash
chmod +x ./scripts/verify_certificates.sh
./scripts/verify_certificates.sh
```

---

## Phase 1 Validation Checklist

### 1.1 Project Structure ✓

- [ ] Root directory structure created
- [ ] `./ca/` directory initialized
- [ ] Docker volume directories created for all services
- [ ] Configuration directories established
- [ ] Docker network definitions created
- [ ] Directory structure documented

### 1.2 Certificate Authority ✓

- [ ] easy-rsa installed locally
- [ ] PKI initialized in `./ca/`
- [ ] CA variables configured with organization details
- [ ] Root CA certificate generated (`ca.crt`)
- [ ] CA private key secured with proper permissions
- [ ] CA certificate distributed to all service volumes

### 1.3 Service Certificates ✓

- [ ] Certificate generation script created and tested
- [ ] SuperLink certificate generated with correct SANs
- [ ] PostgreSQL certificate generated
- [ ] Keycloak certificate generated
- [ ] JupyterHub certificate generated
- [ ] Nginx certificate generated
- [ ] SuperNode certificates generated (5 organizations)
- [ ] All certificates verified using verification script
- [ ] Certificate permissions properly set (644 for certs, 600 for keys)

---

## Expected Outputs After Phase 1

### Directory Structure

```
flower_secure_simulation/
├── ca/
│   ├── easyrsa
│   └── pki/
│       ├── ca.crt
│       ├── private/ca.key
│       ├── issued/
│       │   ├── superlink.crt
│       │   ├── postgres.crt
│       │   ├── keycloak.crt
│       │   ├── jupyterhub.crt
│       │   ├── nginx.crt
│       │   └── supernode-{1..5}.crt
│       └── private/
│           ├── superlink.key
│           ├── postgres.key
│           ├── keycloak.key
│           ├── jupyterhub.key
│           ├── nginx.key
│           └── supernode-{1..5}.key
├── volumes/
│   └── certificates/
│       ├── superlink/{ca.crt, superlink.crt, superlink.key}
│       ├── postgres/{ca.crt, postgres.crt, postgres.key}
│       ├── keycloak/{ca.crt, keycloak.crt, keycloak.key}
│       ├── jupyterhub/{ca.crt, jupyterhub.crt, jupyterhub.key}
│       ├── nginx/{ca.crt, nginx.crt, nginx.key}
│       └── supernode-{1..5}/{ca.crt, supernode-X.crt, supernode-X.key}
├── config/
│   ├── nginx/
│   ├── keycloak/
│   ├── jupyterhub/
│   ├── prometheus/
│   ├── grafana/
│   ├── superlink/
│   └── supernode/
├── docker/
│   └── networks.yml
└── scripts/
    ├── generate_service_cert.sh
    └── verify_certificates.sh
```

### Certificate Inventory

- **1 Root CA Certificate**: For signing all service/client certificates
- **6 Service Certificates**: superlink, postgres, keycloak, jupyterhub, nginx, and 5 supernode client certificates
- **All certificates**: Include proper SANs for Docker DNS, localhost, and IP addresses

---

## Agent Execution Plan

### Phase 1.1: Project Structure

1. **devops agent**: Create directory structure and network definitions
2. **docker-expert agent**: Configure volume mount strategy and permissions

### Phase 1.2: Certificate Authority

1. **security agent**: Install easy-rsa, initialize PKI, generate root CA
2. **devops agent**: Distribute CA certificate to volume mounts

### Phase 1.3: Service Certificates

1. **security agent**: Create certificate generation scripts and generate all service certificates
2. **fl-expert agent**: Review Flower-specific certificate requirements (SuperLink, SuperNode)
3. **docker-expert agent**: Verify SAN entries match Docker DNS configuration

---

## Next Steps (Phase 2 Preview)

After Phase 1 completion, Phase 2 will focus on:

- Creating Docker networks with IP segmentation
- Configuring `/etc/hosts` for local domain resolution
- Setting up localhost-only port binding
- Planning NGINX reverse proxy external access

**Prerequisites for Phase 2**: All Phase 1 validation checklist items must be completed and verified.

---

## References

- **OPS Manual Section 4.1.2.2**: Local Certificate Authority setup
- **OPS Manual Section 4.1.1**: Directory Structure conventions
- **OPS Manual Section 3.3.1**: Network Protocols and Ports
- **OPS Manual Section 4.1.2.16**: SuperLink deployment
- **OPS Manual Section 4.1.3**: SuperNode deployment
- **OPS Manual Appendix 5.7**: SuperNode Docker configuration
- **instruction.md**: Modified IP ranges and Docker-specific adaptations

---

## Security Notes

1. **CA Private Key**: NEVER commit `ca/pki/private/ca.key` to version control
2. **Certificate Permissions**: Keys must be 600, certificates 644
3. **Volume Security**: Ensure Docker volumes are not world-readable
4. **Key Length**: 4096-bit RSA keys for production-grade security
5. **Certificate Expiry**: Server certificates expire in 825 days, monitor and rotate
6. **mTLS**: All FL communication requires mutual authentication
7. **Storage**: Add `ca/pki/private/` to `.gitignore`

---

## Troubleshooting

### Issue: easy-rsa not found

**Solution**: Install package `sudo apt-get install easy-rsa`

### Issue: Permission denied on ca.key

**Solution**: Ensure proper ownership and 600 permissions `chmod 600 ca/pki/private/ca.key`

### Issue: Certificate SAN verification fails

**Solution**: Regenerate certificate with correct `--subject-alt-name` parameter

### Issue: Docker containers can't access certificates

**Solution**: Verify volume mount paths in docker-compose.yml match certificate locations

---

**Plan Created**: 2025-10-25
**Target Agents**: devops, security, fl-expert, docker-expert
**Status**: Ready for execution
