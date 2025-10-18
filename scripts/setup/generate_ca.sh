#!/bin/bash
# Generate Certificate Authority for Flower FL
# This script creates the root CA certificate and private key

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
