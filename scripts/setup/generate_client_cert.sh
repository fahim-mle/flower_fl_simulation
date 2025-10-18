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
