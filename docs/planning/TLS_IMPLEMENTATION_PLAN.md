# TLS/mTLS Implementation Plan for Flower Federated Learning

**Date Created:** 2025-10-18
**Current Branch:** `feature/enable-tls-superlink-supernodes`
**Week:** Week 4 - Security Foundations
**Status:** Planning Phase

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Background and Context](#background-and-context)
3. [TLS/mTLS Architecture Overview](#tlsmtls-architecture-overview)
4. [Certificate Infrastructure Design](#certificate-infrastructure-design)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Detailed Task Breakdown](#detailed-task-breakdown)
7. [Testing Strategy](#testing-strategy)
8. [Security Considerations](#security-considerations)
9. [References and Resources](#references-and-resources)

---

## Executive Summary

This document provides a comprehensive implementation plan for enabling TLS (Transport Layer Security) and mTLS (mutual TLS) authentication in the Flower Federated Learning infrastructure. The implementation follows industry best practices and Flower framework recommendations to ensure secure communication between all FL components.

### Goals
- Enable encrypted communication between SuperLink (server) and SuperNodes (clients)
- Implement mutual authentication to prevent impersonation attacks
- Establish a robust Certificate Authority (CA) infrastructure
- Document all certificate generation and management processes
- Test and validate secure connectivity

### Current Status
- **Completed:** Weeks 1-3 (Local Flower deployment with insecure connections)
- **In Progress:** Week 4 - Security Foundations
- **Current Branch:** `feature/enable-tls-superlink-supernodes`
- **Blocker:** Need to complete CA setup and certificate generation before implementing TLS

---

## Background and Context

### Project Overview

The Flower Federated Learning Infrastructure Evaluation project is deploying a secure FL environment for medical data analysis. The system architecture includes:

- **SuperLink:** Central coordinator for federated training (runs on Nectar cloud)
- **SuperNodes:** On-premise execution nodes at client locations (2+ nodes)
- **SuperExec:** Execution engine for running FL applications
- **Datasets:** Distributed sensitive medical data at participating organizations

### Current Infrastructure

**Existing Setup (from Week 3):**
- SuperLink container running on port 9093 (insecure)
- 2x SuperNode containers (partition-id=0 and partition-id=1)
- SuperExec containers for application execution
- Docker network: `flwr-network`
- Two applications: `fl-simulation-app` and `quickstart-docker`
- Current configuration: `insecure = true` in pyproject.toml

**Security Gap:**
All communication is currently unencrypted and unauthenticated, which is unacceptable for production deployment with sensitive medical data.

### Why TLS/mTLS is Critical

1. **Data Confidentiality:** Encrypt model updates and gradients in transit
2. **Authentication:** Verify the identity of SuperLink and all SuperNodes
3. **Integrity:** Prevent tampering with model parameters
4. **Compliance:** Meet healthcare data security requirements (HIPAA, GDPR)
5. **Attack Prevention:** Protect against man-in-the-middle (MITM) attacks

---

## TLS/mTLS Architecture Overview

### Certificate Hierarchy

```
Root CA (Certificate Authority)
├── Server Certificate (SuperLink)
│   ├── Common Name: superlink.fl.local
│   ├── SAN: DNS:superlink.fl.local, IP:127.0.0.1
│   └── Purpose: Server authentication + encryption
│
└── Client Certificates (SuperNodes)
    ├── client1.crt (SuperNode partition-id=0)
    ├── client2.crt (SuperNode partition-id=1)
    ├── client3.crt (future expansion)
    └── clientN.crt (scalable to N nodes)
```

### Communication Flow with mTLS

```
┌──────────────┐                    ┌──────────────┐
│  SuperNode   │                    │  SuperLink   │
│  (Client)    │                    │  (Server)    │
└──────┬───────┘                    └──────┬───────┘
       │                                   │
       │  1. TCP Connection Request        │
       │──────────────────────────────────>│
       │                                   │
       │  2. Server Hello + Server Cert    │
       │<──────────────────────────────────│
       │                                   │
       │  3. Verify Server Cert with CA    │
       │     (Check: signature, expiry,    │
       │      hostname, revocation)        │
       │                                   │
       │  4. Client Hello + Client Cert    │
       │──────────────────────────────────>│
       │                                   │
       │     5. Verify Client Cert with CA │
       │        (Check: signature, expiry, │
       │         authorization)            │
       │                                   │
       │  6. Encrypted Session Established │
       │<═════════════════════════════════>│
       │                                   │
       │  7. Federated Learning Traffic    │
       │<═════════════════════════════════>│
       └───────────────────────────────────┘
```

### Component Authentication Matrix

| Component | Authenticates As | Validates Against | Certificate Type |
|-----------|------------------|-------------------|------------------|
| SuperLink | Server | CA certificate | Server certificate (with SAN) |
| SuperNode 1 | Client | CA certificate | Client certificate |
| SuperNode 2 | Client | CA certificate | Client certificate |
| SuperNode N | Client | CA certificate | Client certificate |

---

## Certificate Infrastructure Design

### Directory Structure

```
certificates/
├── .gitignore              # Prevent private key commits
├── .gitkeep               # Track empty directories
├── README.md              # Certificate management guide
│
├── ca/                    # Certificate Authority
│   ├── ca.crt             # CA public certificate (SAFE TO COMMIT)
│   ├── ca.key             # CA private key (NEVER COMMIT - ADD TO .gitignore)
│   ├── ca.srl             # Serial number tracker
│   └── index.txt          # Certificate database
│
├── server/                # SuperLink server certificates
│   ├── server.crt         # Server certificate (SAFE TO COMMIT)
│   ├── server.csr         # Certificate signing request
│   ├── server.key         # Server private key (NEVER COMMIT)
│   └── server-config.cnf  # OpenSSL config for server cert
│
├── clients/               # SuperNode client certificates
│   ├── client1.crt        # Client 1 certificate (SAFE TO COMMIT)
│   ├── client1.csr        # Client 1 CSR
│   ├── client1.key        # Client 1 private key (NEVER COMMIT)
│   ├── client2.crt        # Client 2 certificate
│   ├── client2.csr        # Client 2 CSR
│   ├── client2.key        # Client 2 private key (NEVER COMMIT)
│   └── ...                # Additional clients as needed
│
└── scripts/               # Certificate generation scripts
    ├── generate_ca.sh      # Create CA
    ├── generate_server.sh  # Generate server cert
    ├── generate_client.sh  # Generate client cert
    └── verify_certs.sh     # Validation script
```

### Certificate Specifications

#### CA Certificate
- **Key Type:** RSA 4096-bit (high security)
- **Validity:** 3650 days (10 years)
- **Usage:** Certificate signing only
- **Basic Constraints:** CA:TRUE

#### Server Certificate (SuperLink)
- **Key Type:** RSA 2048-bit
- **Validity:** 365 days (1 year, rotate annually)
- **Common Name (CN):** superlink.fl.local
- **Subject Alternative Names (SAN):**
  - DNS:superlink.fl.local
  - DNS:localhost
  - IP:127.0.0.1
  - IP:0.0.0.0 (for Docker binding)
- **Key Usage:** Digital Signature, Key Encipherment
- **Extended Key Usage:** Server Authentication
- **Signed by:** CA certificate

#### Client Certificates (SuperNodes)
- **Key Type:** RSA 2048-bit
- **Validity:** 365 days (1 year)
- **Common Name (CN):** supernode-{partition-id}.fl.local
- **Key Usage:** Digital Signature, Key Encipherment
- **Extended Key Usage:** Client Authentication
- **Signed by:** CA certificate

### Security Best Practices

1. **Private Key Protection:**
   - Never commit `.key` files to Git
   - Set file permissions to `400` (read-only for owner)
   - Store CA key in secure location (consider encryption at rest)
   - Use password-protected keys for production

2. **Certificate Rotation:**
   - Rotate certificates annually (server and client)
   - Monitor expiration dates (set alerts at 30 days)
   - Maintain certificate revocation list (CRL)
   - Plan for zero-downtime rotation

3. **Certificate Distribution:**
   - Distribute client certificates securely (encrypted channels)
   - Never share CA private key
   - Document certificate ownership
   - Implement certificate access control

4. **Validation:**
   - Verify certificate signatures before deployment
   - Check for hostname/IP mismatches
   - Validate certificate chains
   - Test certificate revocation

---

## Implementation Roadmap

### Phase 1: Certificate Authority Setup (Week 4.1)
**Branch:** `feature/setup-certificate-authority`
**Duration:** 1-2 days
**Status:** Not Started

**Objectives:**
- Install certificate generation tools (OpenSSL)
- Initialize PKI directory structure
- Generate CA certificate and private key
- Create CA management scripts

**Deliverables:**
- `certificates/ca/ca.crt` (CA certificate)
- `certificates/ca/ca.key` (CA private key - secured)
- `scripts/setup/generate_ca.sh` (automation script)
- Documentation: `docs/guides/certificate-management.md`

### Phase 2: Server Certificate Generation (Week 4.2)
**Branch:** `feature/generate-server-certificates`
**Duration:** 1 day
**Dependencies:** Phase 1 complete
**Status:** Not Started

**Objectives:**
- Generate SuperLink server private key
- Create certificate signing request (CSR) with SAN
- Sign server certificate with CA
- Validate server certificate

**Deliverables:**
- `certificates/server/server.crt`
- `certificates/server/server.key` (secured)
- `certificates/server/server.csr`
- `scripts/setup/generate_server_certs.sh`
- `scripts/setup/verify_server_cert.sh`

### Phase 3: Client Certificate Generation (Week 4.3)
**Branch:** `feature/generate-client-certificates`
**Duration:** 1 day
**Dependencies:** Phase 1 complete
**Status:** Not Started

**Objectives:**
- Generate client private keys for all SuperNodes
- Create client CSRs
- Sign client certificates with CA
- Validate client certificates

**Deliverables:**
- `certificates/clients/client1.crt` and `client1.key`
- `certificates/clients/client2.crt` and `client2.key`
- `scripts/setup/generate_client_certs.sh` (with parameterization)
- Client certificate naming convention documentation

### Phase 4: SuperLink TLS Configuration (Week 4.4)
**Branch:** `feature/enable-tls-superlink-supernodes` (CURRENT)
**Duration:** 2 days
**Dependencies:** Phase 2 complete
**Status:** In Progress

**Objectives:**
- Update `pyproject.toml` with TLS settings
- Mount certificates into SuperLink Docker container
- Update Docker run commands with certificate paths
- Configure SuperLink to use server certificate
- Test SuperLink startup with TLS enabled

**Deliverables:**
- Updated `fl-simulation-app/pyproject.toml`
- Updated `quickstart-docker/pyproject.toml`
- Updated Docker Compose files (if applicable)
- TLS-enabled SuperLink container
- Server startup validation

### Phase 5: SuperNode TLS Configuration (Week 4.5)
**Branch:** `feature/configure-mtls-supernodes`
**Duration:** 2 days
**Dependencies:** Phase 3 and Phase 4 complete
**Status:** Not Started

**Objectives:**
- Update SuperNode configurations with client certificates
- Mount client certificates into SuperNode containers
- Configure certificate verification
- Test SuperNode connections to SuperLink

**Deliverables:**
- Updated SuperNode Docker configurations
- Certificate mount configurations
- Connection test scripts
- End-to-end mTLS validation

### Phase 6: Documentation and Testing (Week 4.6)
**Branch:** `docs/certificate-management`
**Duration:** 1-2 days
**Dependencies:** Phases 1-5 complete
**Status:** Not Started

**Objectives:**
- Document certificate generation procedures
- Create troubleshooting guide
- Document certificate rotation process
- Create security best practices guide

**Deliverables:**
- `docs/guides/certificate-management.md`
- `docs/TROUBLESHOOTING.md` (certificate section)
- `docs/security/TLS_SECURITY_GUIDE.md`
- Certificate lifecycle documentation

---

## Detailed Task Breakdown

### Task 1: Install Certificate Generation Tools

**Subtasks:**
1. Verify OpenSSL installation
   ```bash
   openssl version
   ```
2. Install OpenSSL if needed (Ubuntu/Debian)
   ```bash
   sudo apt-get update
   sudo apt-get install openssl -y
   ```
3. Verify OpenSSL configuration path
   ```bash
   openssl version -d
   ```

**Expected Output:** OpenSSL 3.x installed and functional

---

### Task 2: Create Certificate Directory Structure

**Script:** `scripts/setup/create_cert_dirs.sh`

```bash
#!/bin/bash
# Create certificate directory structure

set -e

BASE_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation"
CERT_DIR="${BASE_DIR}/certificates"

echo "Creating certificate directory structure..."

# Create main directories
mkdir -p "${CERT_DIR}/ca"
mkdir -p "${CERT_DIR}/server"
mkdir -p "${CERT_DIR}/clients"
mkdir -p "${CERT_DIR}/scripts"

# Create .gitkeep files for empty directories
touch "${CERT_DIR}/ca/.gitkeep"
touch "${CERT_DIR}/server/.gitkeep"
touch "${CERT_DIR}/clients/.gitkeep"

# Create .gitignore to protect private keys
cat > "${CERT_DIR}/.gitignore" << 'EOF'
# NEVER commit private keys
*.key
ca.key
server.key
client*.key

# Also ignore serial files and certificate databases
*.srl
*.old
index.txt*
EOF

echo "Certificate directory structure created successfully!"
ls -la "${CERT_DIR}"
```

**Expected Output:** Directory structure created with proper .gitignore

---

### Task 3: Generate Certificate Authority (CA)

**Script:** `scripts/setup/generate_ca.sh`

```bash
#!/bin/bash
# Generate Certificate Authority for Flower FL

set -e

CERT_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation/certificates"
CA_DIR="${CERT_DIR}/ca"

echo "=== Generating Certificate Authority ==="

# Generate CA private key (4096-bit RSA)
echo "1. Generating CA private key..."
openssl genrsa -out "${CA_DIR}/ca.key" 4096

# Set secure permissions on CA key
chmod 400 "${CA_DIR}/ca.key"
echo "   CA private key generated and secured (permissions: 400)"

# Generate CA certificate (self-signed, valid for 10 years)
echo "2. Generating CA certificate..."
openssl req -new -x509 \
    -days 3650 \
    -key "${CA_DIR}/ca.key" \
    -out "${CA_DIR}/ca.crt" \
    -subj "/C=AU/ST=Queensland/L=Brisbane/O=QCIF/OU=Federated Learning/CN=Flower FL Root CA"

echo "   CA certificate generated"

# Verify CA certificate
echo "3. Verifying CA certificate..."
openssl x509 -in "${CA_DIR}/ca.crt" -text -noout | grep -A 2 "Subject:"

# Create serial number file
echo "1000" > "${CA_DIR}/ca.srl"

echo ""
echo "=== Certificate Authority Created Successfully ==="
echo "CA Certificate: ${CA_DIR}/ca.crt"
echo "CA Private Key: ${CA_DIR}/ca.key (SECURED)"
echo ""
echo "IMPORTANT: NEVER commit ca.key to version control!"
```

**Expected Output:**
- `ca.crt` (public CA certificate)
- `ca.key` (private CA key with permissions 400)
- `ca.srl` (serial number tracker)

---

### Task 4: Generate Server Certificate (SuperLink)

**Script:** `scripts/setup/generate_server_cert.sh`

```bash
#!/bin/bash
# Generate server certificate for SuperLink

set -e

CERT_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation/certificates"
CA_DIR="${CERT_DIR}/ca"
SERVER_DIR="${CERT_DIR}/server"

echo "=== Generating SuperLink Server Certificate ==="

# Create OpenSSL config for server certificate with SAN
cat > "${SERVER_DIR}/server-config.cnf" << 'EOF'
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=AU
ST=Queensland
L=Brisbane
O=QCIF
OU=Federated Learning
CN=superlink.fl.local

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = superlink.fl.local
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF

# Generate server private key
echo "1. Generating server private key..."
openssl genrsa -out "${SERVER_DIR}/server.key" 2048

# Set secure permissions
chmod 400 "${SERVER_DIR}/server.key"
echo "   Server private key generated and secured"

# Generate certificate signing request (CSR)
echo "2. Generating certificate signing request (CSR)..."
openssl req -new \
    -key "${SERVER_DIR}/server.key" \
    -out "${SERVER_DIR}/server.csr" \
    -config "${SERVER_DIR}/server-config.cnf"

echo "   CSR generated"

# Sign server certificate with CA
echo "3. Signing server certificate with CA..."
openssl x509 -req \
    -in "${SERVER_DIR}/server.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAserial "${CA_DIR}/ca.srl" \
    -out "${SERVER_DIR}/server.crt" \
    -days 365 \
    -extensions v3_req \
    -extfile "${SERVER_DIR}/server-config.cnf"

echo "   Server certificate signed"

# Verify server certificate
echo "4. Verifying server certificate..."
openssl verify -CAfile "${CA_DIR}/ca.crt" "${SERVER_DIR}/server.crt"
openssl x509 -in "${SERVER_DIR}/server.crt" -text -noout | grep -A 1 "Subject Alternative Name"

echo ""
echo "=== Server Certificate Generated Successfully ==="
echo "Server Certificate: ${SERVER_DIR}/server.crt"
echo "Server Private Key: ${SERVER_DIR}/server.key (SECURED)"
echo "Server CSR: ${SERVER_DIR}/server.csr"
```

**Expected Output:**
- `server.crt` (signed server certificate with SAN)
- `server.key` (server private key with permissions 400)
- `server.csr` (certificate signing request)
- Verification output showing SAN entries

---

### Task 5: Generate Client Certificates (SuperNodes)

**Script:** `scripts/setup/generate_client_cert.sh`

```bash
#!/bin/bash
# Generate client certificate for SuperNode
# Usage: ./generate_client_cert.sh <client_id>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <client_id>"
    echo "Example: $0 1"
    exit 1
fi

CLIENT_ID=$1
CERT_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation/certificates"
CA_DIR="${CERT_DIR}/ca"
CLIENT_DIR="${CERT_DIR}/clients"

echo "=== Generating Client Certificate for SuperNode ${CLIENT_ID} ==="

# Generate client private key
echo "1. Generating client${CLIENT_ID} private key..."
openssl genrsa -out "${CLIENT_DIR}/client${CLIENT_ID}.key" 2048

# Set secure permissions
chmod 400 "${CLIENT_DIR}/client${CLIENT_ID}.key"
echo "   Client private key generated and secured"

# Generate certificate signing request (CSR)
echo "2. Generating certificate signing request (CSR)..."
openssl req -new \
    -key "${CLIENT_DIR}/client${CLIENT_ID}.key" \
    -out "${CLIENT_DIR}/client${CLIENT_ID}.csr" \
    -subj "/C=AU/ST=Queensland/L=Brisbane/O=QCIF/OU=Federated Learning/CN=supernode-${CLIENT_ID}.fl.local"

echo "   CSR generated"

# Create client extensions file
cat > "${CLIENT_DIR}/client${CLIENT_ID}-ext.cnf" << EOF
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

# Sign client certificate with CA
echo "3. Signing client certificate with CA..."
openssl x509 -req \
    -in "${CLIENT_DIR}/client${CLIENT_ID}.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAserial "${CA_DIR}/ca.srl" \
    -out "${CLIENT_DIR}/client${CLIENT_ID}.crt" \
    -days 365 \
    -extfile "${CLIENT_DIR}/client${CLIENT_ID}-ext.cnf"

echo "   Client certificate signed"

# Verify client certificate
echo "4. Verifying client certificate..."
openssl verify -CAfile "${CA_DIR}/ca.crt" "${CLIENT_DIR}/client${CLIENT_ID}.crt"

# Clean up temporary files
rm "${CLIENT_DIR}/client${CLIENT_ID}-ext.cnf"

echo ""
echo "=== Client Certificate Generated Successfully ==="
echo "Client Certificate: ${CLIENT_DIR}/client${CLIENT_ID}.crt"
echo "Client Private Key: ${CLIENT_DIR}/client${CLIENT_ID}.key (SECURED)"
echo "Client CSR: ${CLIENT_DIR}/client${CLIENT_ID}.csr"
```

**Usage:**
```bash
# Generate certificates for 2 SuperNodes
./generate_client_cert.sh 1
./generate_client_cert.sh 2
```

**Expected Output (per client):**
- `clientN.crt` (signed client certificate)
- `clientN.key` (client private key with permissions 400)
- `clientN.csr` (certificate signing request)

---

### Task 6: Update pyproject.toml for TLS

**File:** `fl-simulation-app/pyproject.toml`

**Changes:**
```toml
# Remote federation example for use with SuperLink
[tool.flwr.federations.remote-federation]
address = "<SUPERLINK-ADDRESS>:<PORT>"
# REMOVED: insecure = true
root-certificates = "certificates/ca/ca.crt"

[tool.flwr.federations.local-deployment]
address = "127.0.0.1:9093"
# REMOVED: insecure = true
root-certificates = "certificates/ca/ca.crt"
```

**File:** `quickstart-docker/pyproject.toml` (same changes)

**Validation:**
```bash
# Verify TOML syntax
python3 -c "import tomllib; tomllib.load(open('pyproject.toml', 'rb'))"
```

---

### Task 7: Configure SuperLink Docker Container with TLS

**Current Docker Run Command (insecure):**
```bash
docker run --rm \
  --network flwr-network \
  --name superlink \
  -p 9093:9093 \
  flwr/superlink:1.22.0 \
  --insecure
```

**Updated Docker Run Command (TLS-enabled):**
```bash
docker run --rm \
  --network flwr-network \
  --name superlink \
  -p 9093:9093 \
  -v $(pwd)/certificates:/certificates:ro \
  flwr/superlink:1.22.0 \
  --ssl-ca-certfile /certificates/ca/ca.crt \
  --ssl-certfile /certificates/server/server.crt \
  --ssl-keyfile /certificates/server/server.key
```

**Key Changes:**
1. **Removed:** `--insecure` flag
2. **Added:** `-v` mount for certificates directory (read-only)
3. **Added:** `--ssl-ca-certfile` pointing to CA certificate
4. **Added:** `--ssl-certfile` pointing to server certificate
5. **Added:** `--ssl-keyfile` pointing to server private key

**Create Docker Compose file (recommended):**

**File:** `docker-compose.tls.yml`

```yaml
version: '3.8'

services:
  superlink:
    image: flwr/superlink:1.22.0
    container_name: superlink
    networks:
      - flwr-network
    ports:
      - "9093:9093"
    volumes:
      - ./certificates:/certificates:ro
    command:
      - --ssl-ca-certfile=/certificates/ca/ca.crt
      - --ssl-certfile=/certificates/server/server.crt
      - --ssl-keyfile=/certificates/server/server.key
    restart: unless-stopped

  supernode-0:
    image: flwr/supernode:1.22.0
    container_name: supernode-0
    networks:
      - flwr-network
    volumes:
      - ./certificates:/certificates:ro
      - ./quickstart-docker:/app
    command:
      - --root-certificates=/certificates/ca/ca.crt
      - --superlink=superlink:9092
      - --clientappio-api-address=0.0.0.0:9094
      - --node-config=partition-id=0 num-partitions=2
    depends_on:
      - superlink
    restart: unless-stopped

  supernode-1:
    image: flwr/supernode:1.22.0
    container_name: supernode-1
    networks:
      - flwr-network
    volumes:
      - ./certificates:/certificates:ro
      - ./quickstart-docker:/app
    command:
      - --root-certificates=/certificates/ca/ca.crt
      - --superlink=superlink:9092
      - --clientappio-api-address=0.0.0.0:9095
      - --node-config=partition-id=1 num-partitions=2
    depends_on:
      - superlink
    restart: unless-stopped

networks:
  flwr-network:
    name: flwr-network
    driver: bridge
```

**Usage:**
```bash
# Start TLS-enabled Flower infrastructure
docker-compose -f docker-compose.tls.yml up -d

# Check logs
docker-compose -f docker-compose.tls.yml logs -f

# Stop infrastructure
docker-compose -f docker-compose.tls.yml down
```

---

### Task 8: Configure SuperNode Docker Containers with TLS

**Current Docker Run Command (insecure):**
```bash
docker run --rm \
  --network flwr-network \
  --name supernode-0 \
  -v $(pwd)/quickstart-docker:/app \
  flwr/supernode:1.22.0 \
  --insecure \
  --superlink=127.0.0.1:9092 \
  --clientappio-api-address=0.0.0.0:9094 \
  --node-config="partition-id=0 num-partitions=2"
```

**Updated Docker Run Command (TLS-enabled):**
```bash
docker run --rm \
  --network flwr-network \
  --name supernode-0 \
  -v $(pwd)/certificates:/certificates:ro \
  -v $(pwd)/quickstart-docker:/app \
  flwr/supernode:1.22.0 \
  --root-certificates=/certificates/ca/ca.crt \
  --superlink=superlink:9092 \
  --clientappio-api-address=0.0.0.0:9094 \
  --node-config="partition-id=0 num-partitions=2"
```

**Key Changes:**
1. **Removed:** `--insecure` flag
2. **Added:** `-v` mount for certificates directory (read-only)
3. **Added:** `--root-certificates` pointing to CA certificate
4. **Changed:** SuperLink address from `127.0.0.1` to `superlink` (Docker network name)

**Note:** For full mTLS with client certificates, additional flags would be:
```bash
--ssl-certfile=/certificates/clients/client1.crt \
--ssl-keyfile=/certificates/clients/client1.key
```

However, Flower's current implementation may only require `--root-certificates` for client-side validation. Verify based on Flower version 1.22.0+ documentation.

---

### Task 9: Test TLS Connectivity

**Test Script:** `scripts/tests/test_tls_connection.sh`

```bash
#!/bin/bash
# Test TLS connectivity between SuperLink and SuperNodes

set -e

echo "=== Testing TLS Connectivity ==="

# Test 1: Verify SuperLink is running with TLS
echo "1. Checking SuperLink container status..."
docker ps | grep superlink
if [ $? -eq 0 ]; then
    echo "   ✓ SuperLink container is running"
else
    echo "   ✗ SuperLink container is not running"
    exit 1
fi

# Test 2: Check SuperLink TLS port
echo "2. Testing SuperLink TLS port 9093..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9093'
if [ $? -eq 0 ]; then
    echo "   ✓ SuperLink port 9093 is accessible"
else
    echo "   ✗ SuperLink port 9093 is not accessible"
    exit 1
fi

# Test 3: Verify certificate files exist
echo "3. Verifying certificate files..."
CERT_DIR="certificates"
for cert_file in ca/ca.crt server/server.crt server/server.key; do
    if [ -f "${CERT_DIR}/${cert_file}" ]; then
        echo "   ✓ ${cert_file} exists"
    else
        echo "   ✗ ${cert_file} missing"
        exit 1
    fi
done

# Test 4: Verify certificates are valid
echo "4. Validating certificates..."
openssl verify -CAfile certificates/ca/ca.crt certificates/server/server.crt
if [ $? -eq 0 ]; then
    echo "   ✓ Server certificate is valid"
else
    echo "   ✗ Server certificate validation failed"
    exit 1
fi

# Test 5: Check SuperNode connectivity
echo "5. Checking SuperNode connections..."
docker logs supernode-0 2>&1 | tail -20
docker logs supernode-1 2>&1 | tail -20

# Look for successful connection messages
docker logs supernode-0 2>&1 | grep -i "connected\|success" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ SuperNode-0 connected successfully"
else
    echo "   ⚠ SuperNode-0 connection status unclear (check logs)"
fi

docker logs supernode-1 2>&1 | grep -i "connected\|success" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ SuperNode-1 connected successfully"
else
    echo "   ⚠ SuperNode-1 connection status unclear (check logs)"
fi

echo ""
echo "=== TLS Connectivity Test Complete ==="
```

**Usage:**
```bash
chmod +x scripts/tests/test_tls_connection.sh
./scripts/tests/test_tls_connection.sh
```

**Expected Output:**
- All containers running
- Port 9093 accessible
- Certificates valid
- SuperNodes successfully connected to SuperLink

---

### Task 10: Run Federated Learning Job with TLS

**Test Command:**
```bash
# From the quickstart-docker directory
cd quickstart-docker
flwr run . local-deployment --stream
```

**Expected Behavior:**
1. SuperExec connects to SuperLink over TLS
2. SuperNodes authenticate with CA certificate
3. Federated training runs for 3 rounds
4. Model updates encrypted in transit
5. Final model saved to disk

**Validation:**
```bash
# Check for TLS handshake in logs
docker logs superlink 2>&1 | grep -i "tls\|ssl\|certificate"

# Verify no insecure warnings
docker logs superlink 2>&1 | grep -i "insecure" && echo "WARNING: Insecure mode detected!" || echo "✓ Secure mode confirmed"

# Check for successful training completion
ls -lh final_model.pt
```

---

## Testing Strategy

### Unit Tests

1. **Certificate Validation Tests:**
   - Verify CA certificate is self-signed
   - Verify server certificate signed by CA
   - Verify client certificates signed by CA
   - Check certificate expiration dates
   - Validate certificate chains

2. **Configuration Tests:**
   - Verify pyproject.toml has `insecure = false`
   - Verify root-certificates path is correct
   - Validate Docker mount paths
   - Check file permissions on private keys

### Integration Tests

1. **SuperLink TLS Tests:**
   - Start SuperLink with TLS enabled
   - Verify TLS port 9093 is listening
   - Check SuperLink logs for TLS initialization
   - Attempt connection without certificate (should fail)

2. **SuperNode mTLS Tests:**
   - Start SuperNodes with CA certificate
   - Verify SuperNode-SuperLink handshake
   - Check for encrypted traffic (tcpdump)
   - Test multiple concurrent SuperNode connections

3. **End-to-End FL Tests:**
   - Run complete federated learning job
   - Verify model convergence
   - Check training round completion
   - Validate final model accuracy

### Security Tests

1. **Attack Simulation Tests:**
   - Test connection without valid certificate (should fail)
   - Test with expired certificate (should fail)
   - Test with wrong CA certificate (should fail)
   - Test with self-signed client cert (should fail)

2. **Traffic Analysis:**
   - Capture network traffic with tcpdump
   - Verify traffic is encrypted (no plaintext model data)
   - Check TLS version (should be TLS 1.2+)
   - Validate cipher suites

### Performance Tests

1. **Overhead Measurement:**
   - Benchmark training time with TLS vs insecure
   - Measure latency impact of encryption
   - Test scalability with N SuperNodes
   - Monitor CPU/memory overhead

---

## Security Considerations

### Threat Model

**Threats Mitigated by TLS/mTLS:**
1. **Man-in-the-Middle (MITM) Attacks:** TLS encryption prevents eavesdropping
2. **Impersonation:** mTLS prevents rogue SuperNodes from joining
3. **Data Tampering:** Integrity checks prevent model poisoning in transit
4. **Replay Attacks:** TLS session keys prevent replay attacks

**Residual Risks:**
1. **Compromised Private Keys:** If CA key is stolen, entire PKI is compromised
2. **Certificate Expiration:** Expired certs will break connectivity
3. **Insider Threats:** Authorized SuperNodes could still poison models
4. **Docker Host Security:** Container breakout could expose certificates

### Security Hardening

**Recommendations:**
1. **CA Key Storage:**
   - Store CA private key offline after initial setup
   - Consider HSM (Hardware Security Module) for production
   - Encrypt CA key with strong passphrase

2. **Certificate Monitoring:**
   - Implement certificate expiration alerts
   - Set up automated renewal (e.g., 30 days before expiry)
   - Maintain certificate inventory

3. **Access Control:**
   - Restrict Docker host access (least privilege)
   - Use Docker secrets for production
   - Implement role-based access control (RBAC)

4. **Logging and Auditing:**
   - Enable TLS connection logging
   - Monitor for failed authentication attempts
   - Audit certificate issuance and revocation

5. **Network Segmentation:**
   - Isolate FL network from public internet
   - Use VPN for inter-organizational communication (Week 5)
   - Implement firewall rules (ports 9091-9099 only)

### Compliance Considerations

**For Medical Data (HIPAA, GDPR):**
- TLS 1.2+ required (TLS 1.3 preferred)
- Strong cipher suites (AES-256, no RC4/3DES)
- Certificate key length: minimum RSA 2048-bit
- Regular security audits and penetration testing
- Documented certificate lifecycle management

---

## References and Resources

### Official Flower Documentation
1. **Enable TLS Connections:** https://flower.ai/docs/framework/how-to-enable-tls-connections.html
2. **Enable SSL Connections:** https://flower.ai/docs/framework/how-to-enable-ssl-connections.html
3. **Authenticate SuperNodes:** https://flower.ai/docs/framework/how-to-authenticate-supernodes.html
4. **pyproject.toml Configuration:** https://flower.ai/docs/framework/how-to-configure-pyproject-toml.html
5. **Flower CLI Reference:** https://flower.ai/docs/framework/ref-api-cli.html

### OpenSSL Documentation
1. **OpenSSL Man Pages:** https://www.openssl.org/docs/man3.0/
2. **Certificate Generation Guide:** https://jamielinux.com/docs/openssl-certificate-authority/
3. **X.509 Certificate Standards:** https://www.rfc-editor.org/rfc/rfc5280

### Security Best Practices
1. **TLS Best Practices:** https://wiki.mozilla.org/Security/Server_Side_TLS
2. **Certificate Management:** https://www.ssl.com/article/ssl-certificate-best-practices/
3. **Docker Security:** https://docs.docker.com/engine/security/

### Project-Specific Documentation
1. **Project Plan:** `docs/planning/plan_and_how_to_accomplish_project.md`
2. **Tasks and Branches:** `docs/project-status/TASKS_AND_BRANCHES.md`
3. **Docker Setup:** `docs/setup/DOCKER_SETUP_COMPLETE.md`
4. **Certificate README:** `docs/setup/certificates-README.md`

---

## Appendix: Quick Reference Commands

### Certificate Generation
```bash
# Generate CA
./scripts/setup/generate_ca.sh

# Generate server certificate
./scripts/setup/generate_server_cert.sh

# Generate client certificates
./scripts/setup/generate_client_cert.sh 1
./scripts/setup/generate_client_cert.sh 2
```

### Certificate Verification
```bash
# Verify CA certificate
openssl x509 -in certificates/ca/ca.crt -text -noout

# Verify server certificate
openssl verify -CAfile certificates/ca/ca.crt certificates/server/server.crt

# Check certificate expiration
openssl x509 -in certificates/server/server.crt -noout -enddate
```

### Docker Operations
```bash
# Start TLS-enabled infrastructure
docker-compose -f docker-compose.tls.yml up -d

# Check logs
docker logs superlink
docker logs supernode-0
docker logs supernode-1

# Stop infrastructure
docker-compose -f docker-compose.tls.yml down
```

### Testing
```bash
# Run TLS connectivity test
./scripts/tests/test_tls_connection.sh

# Run federated learning job
cd quickstart-docker
flwr run . local-deployment --stream
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-18
**Next Review:** After Phase 1 completion (CA setup)
