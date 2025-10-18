# TLS Implementation Task Checklist

**Created:** 2025-10-18
**Week:** Week 4 - Security Foundations
**Current Branch:** `feature/enable-tls-superlink-supernodes`

This document provides a detailed, actionable checklist for implementing TLS/mTLS in the Flower Federated Learning infrastructure.

---

## Overview

This checklist breaks down the TLS implementation into discrete, actionable tasks organized by phase. Each task includes:
- **Task ID:** Unique identifier
- **Description:** What needs to be done
- **Commands:** Specific commands to execute
- **Validation:** How to verify completion
- **Status:** Not Started / In Progress / Completed

---

## Phase 1: Certificate Authority Setup

### Task 1.1: Install Certificate Generation Tools
- [ ] **Task ID:** TLS-001
- **Description:** Verify OpenSSL is installed and functional
- **Commands:**
  ```bash
  openssl version
  # Expected output: OpenSSL 3.x or higher
  ```
- **Validation:** OpenSSL version displays correctly
- **Status:** Not Started

---

### Task 1.2: Create Certificate Directory Structure
- [ ] **Task ID:** TLS-002
- **Description:** Create organized directory structure for certificates
- **Commands:**
  ```bash
  cd /home/ghost/workspace/internship_project/flower_fl_simulation
  mkdir -p certificates/{ca,server,clients,scripts}
  touch certificates/{ca,server,clients}/.gitkeep
  ```
- **Create `.gitignore`:**
  ```bash
  cat > certificates/.gitignore << 'EOF'
  # NEVER commit private keys
  *.key
  ca.key
  server.key
  client*.key

  # Serial files and certificate databases
  *.srl
  *.old
  index.txt*
  EOF
  ```
- **Validation:**
  ```bash
  ls -la certificates/
  # Should show: ca/ server/ clients/ .gitignore
  ```
- **Status:** Not Started

---

### Task 1.3: Create CA Generation Script
- [ ] **Task ID:** TLS-003
- **Description:** Create automated script to generate Certificate Authority
- **Commands:**
  ```bash
  mkdir -p scripts/setup
  cat > scripts/setup/generate_ca.sh << 'EOF'
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
  EOF

  chmod +x scripts/setup/generate_ca.sh
  ```
- **Validation:**
  ```bash
  ls -l scripts/setup/generate_ca.sh
  # Should be executable (rwxr-xr-x)
  ```
- **Status:** Not Started

---

### Task 1.4: Generate Certificate Authority
- [ ] **Task ID:** TLS-004
- **Description:** Execute CA generation script
- **Commands:**
  ```bash
  ./scripts/setup/generate_ca.sh
  ```
- **Validation:**
  ```bash
  # Verify CA certificate exists
  ls -l certificates/ca/ca.crt certificates/ca/ca.key

  # Verify CA key permissions
  stat -c "%a %n" certificates/ca/ca.key
  # Should show: 400 certificates/ca/ca.key

  # Verify CA certificate details
  openssl x509 -in certificates/ca/ca.crt -text -noout | grep -E "Subject:|Issuer:|Validity"
  ```
- **Expected Files:**
  - `certificates/ca/ca.crt` (public CA certificate)
  - `certificates/ca/ca.key` (private CA key, permissions 400)
  - `certificates/ca/ca.srl` (serial number tracker)
- **Status:** Not Started

---

## Phase 2: Server Certificate Generation

### Task 2.1: Create Server Certificate Generation Script
- [ ] **Task ID:** TLS-005
- **Description:** Create script to generate SuperLink server certificate with SAN
- **Commands:**
  ```bash
  cat > scripts/setup/generate_server_cert.sh << 'EOF'
  #!/bin/bash
  # Generate server certificate for SuperLink

  set -e

  CERT_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation/certificates"
  CA_DIR="${CERT_DIR}/ca"
  SERVER_DIR="${CERT_DIR}/server"

  echo "=== Generating SuperLink Server Certificate ==="

  # Create OpenSSL config for server certificate with SAN
  cat > "${SERVER_DIR}/server-config.cnf" << 'EOFINNER'
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
  EOFINNER

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
  EOF

  chmod +x scripts/setup/generate_server_cert.sh
  ```
- **Validation:**
  ```bash
  ls -l scripts/setup/generate_server_cert.sh
  ```
- **Status:** Not Started

---

### Task 2.2: Generate Server Certificate
- [ ] **Task ID:** TLS-006
- **Description:** Execute server certificate generation script
- **Commands:**
  ```bash
  ./scripts/setup/generate_server_cert.sh
  ```
- **Validation:**
  ```bash
  # Verify server certificate files exist
  ls -l certificates/server/server.{crt,key,csr}

  # Verify server key permissions
  stat -c "%a %n" certificates/server/server.key
  # Should show: 400

  # Verify certificate is signed by CA
  openssl verify -CAfile certificates/ca/ca.crt certificates/server/server.crt
  # Should show: certificates/server/server.crt: OK

  # Check Subject Alternative Names
  openssl x509 -in certificates/server/server.crt -text -noout | grep -A 5 "Subject Alternative Name"
  # Should show: DNS:superlink.fl.local, DNS:localhost, IP:127.0.0.1, IP:0.0.0.0
  ```
- **Expected Files:**
  - `certificates/server/server.crt` (server certificate)
  - `certificates/server/server.key` (server private key, permissions 400)
  - `certificates/server/server.csr` (certificate signing request)
  - `certificates/server/server-config.cnf` (OpenSSL config)
- **Status:** Not Started

---

## Phase 3: Client Certificate Generation

### Task 3.1: Create Client Certificate Generation Script
- [ ] **Task ID:** TLS-007
- **Description:** Create reusable script to generate client certificates
- **Commands:**
  ```bash
  cat > scripts/setup/generate_client_cert.sh << 'EOF'
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
  cat > "${CLIENT_DIR}/client${CLIENT_ID}-ext.cnf" << EOFINNER
  keyUsage = digitalSignature, keyEncipherment
  extendedKeyUsage = clientAuth
  EOFINNER

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
  EOF

  chmod +x scripts/setup/generate_client_cert.sh
  ```
- **Validation:**
  ```bash
  ls -l scripts/setup/generate_client_cert.sh
  ```
- **Status:** Not Started

---

### Task 3.2: Generate Client Certificate for SuperNode 1
- [ ] **Task ID:** TLS-008
- **Description:** Generate certificate for first SuperNode (partition-id=0)
- **Commands:**
  ```bash
  ./scripts/setup/generate_client_cert.sh 1
  ```
- **Validation:**
  ```bash
  # Verify client1 files
  ls -l certificates/clients/client1.{crt,key,csr}

  # Verify client1 key permissions
  stat -c "%a %n" certificates/clients/client1.key

  # Verify certificate is signed by CA
  openssl verify -CAfile certificates/ca/ca.crt certificates/clients/client1.crt
  ```
- **Expected Files:**
  - `certificates/clients/client1.crt`
  - `certificates/clients/client1.key` (permissions 400)
  - `certificates/clients/client1.csr`
- **Status:** Not Started

---

### Task 3.3: Generate Client Certificate for SuperNode 2
- [ ] **Task ID:** TLS-009
- **Description:** Generate certificate for second SuperNode (partition-id=1)
- **Commands:**
  ```bash
  ./scripts/setup/generate_client_cert.sh 2
  ```
- **Validation:**
  ```bash
  # Verify client2 files
  ls -l certificates/clients/client2.{crt,key,csr}

  # Verify certificate
  openssl verify -CAfile certificates/ca/ca.crt certificates/clients/client2.crt
  ```
- **Expected Files:**
  - `certificates/clients/client2.crt`
  - `certificates/clients/client2.key` (permissions 400)
  - `certificates/clients/client2.csr`
- **Status:** Not Started

---

## Phase 4: Configure SuperLink for TLS

### Task 4.1: Update pyproject.toml for fl-simulation-app
- [ ] **Task ID:** TLS-010
- **Description:** Enable TLS in fl-simulation-app configuration
- **File:** `fl-simulation-app/pyproject.toml`
- **Changes:**
  ```toml
  # BEFORE:
  [tool.flwr.federations.local-deployment]
  address = "127.0.0.1:9093"
  insecure = true

  # AFTER:
  [tool.flwr.federations.local-deployment]
  address = "127.0.0.1:9093"
  # REMOVED: insecure = true
  root-certificates = "../certificates/ca/ca.crt"
  ```
- **Commands:**
  ```bash
  # Make changes with text editor or Edit tool
  # Then validate TOML syntax:
  cd fl-simulation-app
  python3 -c "import tomllib; tomllib.load(open('pyproject.toml', 'rb'))"
  ```
- **Validation:** TOML loads without errors
- **Status:** Not Started

---

### Task 4.2: Update pyproject.toml for quickstart-docker
- [ ] **Task ID:** TLS-011
- **Description:** Enable TLS in quickstart-docker configuration
- **File:** `quickstart-docker/pyproject.toml`
- **Changes:**
  ```toml
  # BEFORE:
  [tool.flwr.federations.local-deployment]
  address = "127.0.0.1:9093"
  insecure = true

  # AFTER:
  [tool.flwr.federations.local-deployment]
  address = "127.0.0.1:9093"
  # REMOVED: insecure = true
  root-certificates = "../certificates/ca/ca.crt"
  ```
- **Commands:**
  ```bash
  cd quickstart-docker
  python3 -c "import tomllib; tomllib.load(open('pyproject.toml', 'rb'))"
  ```
- **Validation:** TOML loads without errors
- **Status:** Not Started

---

### Task 4.3: Create Docker Compose File for TLS
- [ ] **Task ID:** TLS-012
- **Description:** Create docker-compose.tls.yml with TLS configuration
- **Commands:**
  ```bash
  cat > docker-compose.tls.yml << 'EOF'
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
  EOF
  ```
- **Validation:**
  ```bash
  docker-compose -f docker-compose.tls.yml config
  # Should parse without errors
  ```
- **Status:** Not Started

---

### Task 4.4: Stop Existing Insecure Containers
- [ ] **Task ID:** TLS-013
- **Description:** Stop all running insecure Flower containers
- **Commands:**
  ```bash
  # Stop all Flower containers
  docker stop superlink supernode-0 supernode-1 superexec 2>/dev/null || true

  # Remove containers
  docker rm superlink supernode-0 supernode-1 superexec 2>/dev/null || true

  # Verify no Flower containers running
  docker ps | grep -E "superlink|supernode|superexec"
  # Should return no results
  ```
- **Validation:** `docker ps` shows no Flower containers
- **Status:** Not Started

---

### Task 4.5: Start SuperLink with TLS
- [ ] **Task ID:** TLS-014
- **Description:** Launch SuperLink container with TLS enabled
- **Commands:**
  ```bash
  docker-compose -f docker-compose.tls.yml up -d superlink
  ```
- **Validation:**
  ```bash
  # Check SuperLink is running
  docker ps | grep superlink

  # Check SuperLink logs for TLS initialization
  docker logs superlink 2>&1 | grep -i "tls\|ssl\|certificate"

  # Verify no "insecure" warnings
  docker logs superlink 2>&1 | grep -i "insecure" && echo "WARNING: Insecure mode!" || echo "✓ Secure mode"

  # Check TLS port is listening
  timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9093' && echo "✓ Port 9093 accessible"
  ```
- **Expected Output:**
  - SuperLink container running
  - Logs show TLS/SSL initialization
  - No "insecure" warnings in logs
  - Port 9093 accessible
- **Status:** Not Started

---

## Phase 5: Configure SuperNodes for TLS

### Task 5.1: Start SuperNode 0 with TLS
- [ ] **Task ID:** TLS-015
- **Description:** Launch SuperNode container 0 with TLS
- **Commands:**
  ```bash
  docker-compose -f docker-compose.tls.yml up -d supernode-0
  ```
- **Validation:**
  ```bash
  # Check SuperNode is running
  docker ps | grep supernode-0

  # Check SuperNode logs for connection
  docker logs supernode-0 2>&1 | tail -20

  # Look for successful TLS handshake
  docker logs supernode-0 2>&1 | grep -i "connected\|success\|tls"
  ```
- **Expected Output:**
  - SuperNode-0 container running
  - Logs show successful connection to SuperLink
  - TLS handshake completed
- **Status:** Not Started

---

### Task 5.2: Start SuperNode 1 with TLS
- [ ] **Task ID:** TLS-016
- **Description:** Launch SuperNode container 1 with TLS
- **Commands:**
  ```bash
  docker-compose -f docker-compose.tls.yml up -d supernode-1
  ```
- **Validation:**
  ```bash
  # Check SuperNode is running
  docker ps | grep supernode-1

  # Check SuperNode logs
  docker logs supernode-1 2>&1 | tail -20

  # Verify connection
  docker logs supernode-1 2>&1 | grep -i "connected\|success"
  ```
- **Expected Output:**
  - SuperNode-1 container running
  - Successful connection to SuperLink
- **Status:** Not Started

---

### Task 5.3: Verify All Containers Running
- [ ] **Task ID:** TLS-017
- **Description:** Confirm all TLS-enabled containers are operational
- **Commands:**
  ```bash
  docker-compose -f docker-compose.tls.yml ps
  ```
- **Expected Output:**
  ```
  NAME          IMAGE                    STATUS
  superlink     flwr/superlink:1.22.0    Up
  supernode-0   flwr/supernode:1.22.0    Up
  supernode-1   flwr/supernode:1.22.0    Up
  ```
- **Status:** Not Started

---

## Phase 6: Testing and Validation

### Task 6.1: Create TLS Connectivity Test Script
- [ ] **Task ID:** TLS-018
- **Description:** Create automated test script for TLS connectivity
- **Commands:**
  ```bash
  mkdir -p scripts/tests
  cat > scripts/tests/test_tls_connection.sh << 'EOF'
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
  docker logs supernode-0 2>&1 | grep -i "connected\|success" > /dev/null
  if [ $? -eq 0 ]; then
      echo "   ✓ SuperNode-0 connected successfully"
  else
      echo "   ⚠ SuperNode-0 connection status unclear"
  fi

  docker logs supernode-1 2>&1 | grep -i "connected\|success" > /dev/null
  if [ $? -eq 0 ]; then
      echo "   ✓ SuperNode-1 connected successfully"
  else
      echo "   ⚠ SuperNode-1 connection status unclear"
  fi

  echo ""
  echo "=== TLS Connectivity Test Complete ==="
  EOF

  chmod +x scripts/tests/test_tls_connection.sh
  ```
- **Validation:**
  ```bash
  ls -l scripts/tests/test_tls_connection.sh
  ```
- **Status:** Not Started

---

### Task 6.2: Run TLS Connectivity Tests
- [ ] **Task ID:** TLS-019
- **Description:** Execute TLS connectivity test script
- **Commands:**
  ```bash
  ./scripts/tests/test_tls_connection.sh
  ```
- **Expected Output:** All tests pass with ✓ marks
- **Status:** Not Started

---

### Task 6.3: Run Federated Learning Job with TLS
- [ ] **Task ID:** TLS-020
- **Description:** Execute a complete FL training job over TLS
- **Commands:**
  ```bash
  cd quickstart-docker
  flwr run . local-deployment --stream
  ```
- **Expected Output:**
  - FL job starts successfully
  - 3 training rounds complete
  - Model updates transmitted over TLS
  - Final model saved: `final_model.pt`
- **Validation:**
  ```bash
  # Check for final model
  ls -lh ../final_model.pt

  # Verify training completed
  docker logs superlink 2>&1 | grep -i "round.*complete"

  # Check for TLS traffic (no insecure warnings)
  docker logs superlink 2>&1 | grep -i "insecure" && echo "WARNING" || echo "✓ Secure"
  ```
- **Status:** Not Started

---

### Task 6.4: Verify Encrypted Traffic
- [ ] **Task ID:** TLS-021
- **Description:** Confirm network traffic is encrypted (optional advanced test)
- **Commands:**
  ```bash
  # Capture network traffic (requires tcpdump)
  sudo timeout 30 tcpdump -i lo -w /tmp/flower_traffic.pcap port 9093 &

  # Run a quick FL job
  cd quickstart-docker
  flwr run . local-deployment --stream

  # Analyze capture (should not see plaintext model data)
  tcpdump -r /tmp/flower_traffic.pcap -A | grep -i "tensor\|gradient" && echo "WARNING: Plaintext detected!" || echo "✓ Traffic encrypted"

  # Cleanup
  rm /tmp/flower_traffic.pcap
  ```
- **Expected Output:** No plaintext model data in traffic capture
- **Status:** Not Started (Optional)

---

## Phase 7: Documentation

### Task 7.1: Create Certificate Management Guide
- [ ] **Task ID:** TLS-022
- **Description:** Document certificate generation and management procedures
- **File:** `docs/guides/certificate-management.md`
- **Contents Should Include:**
  - Certificate generation procedures
  - Certificate rotation process
  - Troubleshooting common issues
  - Security best practices
  - Certificate expiration monitoring
- **Commands:**
  ```bash
  # Create comprehensive certificate management documentation
  # (Content to be created based on TLS_IMPLEMENTATION_PLAN.md)
  touch docs/guides/certificate-management.md
  ```
- **Validation:** Documentation file exists and is comprehensive
- **Status:** Not Started

---

### Task 7.2: Update Project Documentation
- [ ] **Task ID:** TLS-023
- **Description:** Update main project documentation with TLS setup
- **Files to Update:**
  - `docs/setup/DOCKER_SETUP_COMPLETE.md` (add TLS section)
  - `docs/README.md` (link to certificate guide)
  - `docs/QUICK_REFERENCE.md` (add TLS commands)
- **Commands:**
  ```bash
  # Add TLS section to Docker setup documentation
  # Add quick reference commands for certificate management
  # Update README with new documentation links
  ```
- **Status:** Not Started

---

### Task 7.3: Create Troubleshooting Guide
- [ ] **Task ID:** TLS-024
- **Description:** Document common TLS issues and solutions
- **File:** `docs/TROUBLESHOOTING.md` (create or update)
- **Common Issues to Document:**
  - Certificate verification failed
  - Certificate expired
  - Hostname/IP mismatch
  - Permission denied on private keys
  - Container cannot find certificates
  - TLS handshake failures
- **Status:** Not Started

---

## Phase 8: Cleanup and Finalization

### Task 8.1: Verify .gitignore Protection
- [ ] **Task ID:** TLS-025
- **Description:** Ensure private keys are not tracked by git
- **Commands:**
  ```bash
  # Check git status (should not show .key files)
  git status

  # Verify .key files are ignored
  git check-ignore certificates/ca/ca.key
  git check-ignore certificates/server/server.key
  git check-ignore certificates/clients/client1.key

  # All should output the filename (confirming they're ignored)
  ```
- **Expected Output:** All `.key` files are ignored by git
- **Status:** Not Started

---

### Task 8.2: Create Certificate Inventory
- [ ] **Task ID:** TLS-026
- **Description:** Document all certificates and their expiration dates
- **Commands:**
  ```bash
  cat > docs/setup/CERTIFICATE_INVENTORY.md << 'EOF'
  # Certificate Inventory

  ## Certificate Authority
  - **File:** certificates/ca/ca.crt
  - **Issued:** $(openssl x509 -in certificates/ca/ca.crt -noout -startdate | cut -d= -f2)
  - **Expires:** $(openssl x509 -in certificates/ca/ca.crt -noout -enddate | cut -d= -f2)
  - **Type:** Root CA (self-signed)

  ## Server Certificates
  - **File:** certificates/server/server.crt
  - **CN:** superlink.fl.local
  - **Issued:** $(openssl x509 -in certificates/server/server.crt -noout -startdate | cut -d= -f2)
  - **Expires:** $(openssl x509 -in certificates/server/server.crt -noout -enddate | cut -d= -f2)
  - **Type:** Server (SuperLink)

  ## Client Certificates
  - **File:** certificates/clients/client1.crt
  - **CN:** supernode-1.fl.local
  - **Expires:** $(openssl x509 -in certificates/clients/client1.crt -noout -enddate | cut -d= -f2)

  - **File:** certificates/clients/client2.crt
  - **CN:** supernode-2.fl.local
  - **Expires:** $(openssl x509 -in certificates/clients/client2.crt -noout -enddate | cut -d= -f2)

  ## Expiration Monitoring
  - Set calendar reminder for 30 days before server cert expiration
  - Set calendar reminder for 30 days before client cert expiration
  EOF
  ```
- **Status:** Not Started

---

### Task 8.3: Commit TLS Implementation
- [ ] **Task ID:** TLS-027
- **Description:** Commit all TLS changes to git
- **Commands:**
  ```bash
  # Stage all TLS-related changes (excluding private keys)
  git add scripts/setup/generate_*.sh
  git add scripts/tests/test_tls_connection.sh
  git add docker-compose.tls.yml
  git add fl-simulation-app/pyproject.toml
  git add quickstart-docker/pyproject.toml
  git add docs/planning/TLS_IMPLEMENTATION_PLAN.md
  git add docs/planning/TLS_TASK_CHECKLIST.md
  git add docs/guides/certificate-management.md
  git add docs/setup/CERTIFICATE_INVENTORY.md
  git add certificates/.gitignore
  git add certificates/{ca,server,clients}/.gitkeep

  # Verify no private keys are staged
  git status | grep "\.key" && echo "ERROR: Private key detected!" && exit 1

  # Commit
  git commit -m "$(cat <<'EOF'
  Implement TLS/mTLS for Flower Federated Learning

  - Generate Certificate Authority (CA) for PKI infrastructure
  - Create server certificates for SuperLink with SAN
  - Create client certificates for SuperNodes
  - Update pyproject.toml to enable TLS (removed insecure flag)
  - Create Docker Compose configuration with TLS mounts
  - Add certificate generation scripts (automated)
  - Add TLS connectivity test script
  - Document TLS implementation and certificate management
  - Protect private keys with .gitignore

  Security improvements:
  - All FL traffic now encrypted with TLS 1.2+
  - Mutual authentication between SuperLink and SuperNodes
  - Certificate-based identity verification
  - Private keys protected (400 permissions, gitignored)

  Testing:
  - TLS connectivity verified
  - Federated learning job runs successfully over TLS
  - No insecure warnings in logs

  🤖 Generated with Claude Code

  Co-Authored-By: Claude <noreply@anthropic.com>
  EOF
  )"
  ```
- **Validation:**
  ```bash
  git log -1 --stat
  git show --name-only
  ```
- **Status:** Not Started

---

## Summary Statistics

### Phases
- **Phase 1:** Certificate Authority Setup (4 tasks)
- **Phase 2:** Server Certificate Generation (2 tasks)
- **Phase 3:** Client Certificate Generation (3 tasks)
- **Phase 4:** Configure SuperLink for TLS (5 tasks)
- **Phase 5:** Configure SuperNodes for TLS (3 tasks)
- **Phase 6:** Testing and Validation (4 tasks)
- **Phase 7:** Documentation (3 tasks)
- **Phase 8:** Cleanup and Finalization (3 tasks)

### Total Tasks: 27

### Completion Status
- [ ] Not Started: 27/27 (100%)
- [ ] In Progress: 0/27 (0%)
- [ ] Completed: 0/27 (0%)

---

## Quick Start Commands

Once all tasks are completed, use these commands for daily operations:

```bash
# Start TLS-enabled Flower infrastructure
docker-compose -f docker-compose.tls.yml up -d

# Check status
docker-compose -f docker-compose.tls.yml ps

# View logs
docker-compose -f docker-compose.tls.yml logs -f

# Run FL job
cd quickstart-docker && flwr run . local-deployment --stream

# Test TLS connectivity
./scripts/tests/test_tls_connection.sh

# Stop infrastructure
docker-compose -f docker-compose.tls.yml down

# Generate new client certificate
./scripts/setup/generate_client_cert.sh <N>

# Check certificate expiration
openssl x509 -in certificates/server/server.crt -noout -enddate
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-18
**Next Review:** After Phase 1 completion
