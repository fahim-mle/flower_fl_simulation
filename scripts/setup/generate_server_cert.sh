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
    -sha256 \
    -extfile "${SERVER_DIR}/server-config.cnf" \
    -extensions req_ext

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
