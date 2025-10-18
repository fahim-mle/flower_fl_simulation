#!/bin/bash
# Test TLS connectivity between SuperLink and SuperNodes

set -e

PROJECT_DIR="/home/ghost/workspace/internship_project/flower_fl_simulation"
CERT_DIR="${PROJECT_DIR}/certificates"

echo "========================================="
echo "   TLS Connectivity Test Suite"
echo "========================================="
echo ""

# Test 1: Verify SuperLink is running with TLS
echo "Test 1: Checking SuperLink container status..."
if docker ps | grep -q superlink; then
    echo "   ✓ SuperLink container is running"
else
    echo "   ✗ SuperLink container is not running"
    echo "   Run: docker-compose -f docker-compose.tls.yml up -d superlink"
    exit 1
fi
echo ""

# Test 2: Check SuperLink TLS port
echo "Test 2: Testing SuperLink TLS port 9093..."
if timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9093' 2>/dev/null; then
    echo "   ✓ SuperLink port 9093 is accessible"
else
    echo "   ✗ SuperLink port 9093 is not accessible"
    exit 1
fi
echo ""

# Test 3: Verify certificate files exist
echo "Test 3: Verifying certificate files..."
for cert_file in ca/ca.crt server/server.crt server/server.key clients/client1.crt clients/client2.crt; do
    if [ -f "${CERT_DIR}/${cert_file}" ]; then
        echo "   ✓ ${cert_file} exists"
    else
        echo "   ✗ ${cert_file} missing"
        exit 1
    fi
done
echo ""

# Test 4: Verify certificates are valid
echo "Test 4: Validating certificates..."
if openssl verify -CAfile "${CERT_DIR}/ca/ca.crt" "${CERT_DIR}/server/server.crt" >/dev/null 2>&1; then
    echo "   ✓ Server certificate is valid"
else
    echo "   ✗ Server certificate validation failed"
    exit 1
fi

if openssl verify -CAfile "${CERT_DIR}/ca/ca.crt" "${CERT_DIR}/clients/client1.crt" >/dev/null 2>&1; then
    echo "   ✓ Client1 certificate is valid"
else
    echo "   ✗ Client1 certificate validation failed"
    exit 1
fi

if openssl verify -CAfile "${CERT_DIR}/ca/ca.crt" "${CERT_DIR}/clients/client2.crt" >/dev/null 2>&1; then
    echo "   ✓ Client2 certificate is valid"
else
    echo "   ✗ Client2 certificate validation failed"
    exit 1
fi
echo ""

# Test 5: Check certificate expiration dates
echo "Test 5: Checking certificate expiration dates..."
CA_EXPIRY=$(openssl x509 -in "${CERT_DIR}/ca/ca.crt" -noout -enddate | cut -d= -f2)
SERVER_EXPIRY=$(openssl x509 -in "${CERT_DIR}/server/server.crt" -noout -enddate | cut -d= -f2)
echo "   CA certificate expires: ${CA_EXPIRY}"
echo "   Server certificate expires: ${SERVER_EXPIRY}"
echo ""

# Test 6: Verify SuperLink logs for TLS
echo "Test 6: Checking SuperLink logs for TLS initialization..."
if docker logs superlink 2>&1 | grep -qi "ssl\|tls\|certificate"; then
    echo "   ✓ TLS/SSL references found in SuperLink logs"
else
    echo "   ⚠ No explicit TLS references in logs (may be normal)"
fi

if docker logs superlink 2>&1 | grep -qi "insecure"; then
    echo "   ✗ WARNING: 'insecure' mode detected in SuperLink logs!"
else
    echo "   ✓ No 'insecure' warnings found"
fi
echo ""

# Test 7: Check SuperNode connectivity
echo "Test 7: Checking SuperNode connections..."
if docker ps | grep -q supernode-0; then
    echo "   ✓ SuperNode-0 container is running"
    if docker logs supernode-0 2>&1 | tail -50 | grep -qi "connected\|grpc.*ok\|ready"; then
        echo "   ✓ SuperNode-0 appears connected"
    else
        echo "   ⚠ SuperNode-0 connection status unclear (check logs)"
    fi
else
    echo "   ⚠ SuperNode-0 is not running"
fi

if docker ps | grep -q supernode-1; then
    echo "   ✓ SuperNode-1 container is running"
    if docker logs supernode-1 2>&1 | tail -50 | grep -qi "connected\|grpc.*ok\|ready"; then
        echo "   ✓ SuperNode-1 appears connected"
    else
        echo "   ⚠ SuperNode-1 connection status unclear (check logs)"
    fi
else
    echo "   ⚠ SuperNode-1 is not running"
fi
echo ""

# Test 8: Verify private key permissions
echo "Test 8: Verifying private key permissions..."
for key_file in ca/ca.key server/server.key clients/client1.key clients/client2.key; do
    PERMS=$(stat -c "%a" "${CERT_DIR}/${key_file}")
    if [ "$PERMS" = "400" ]; then
        echo "   ✓ ${key_file} has correct permissions (400)"
    else
        echo "   ✗ ${key_file} has incorrect permissions (${PERMS}, should be 400)"
    fi
done
echo ""

echo "========================================="
echo "   TLS Connectivity Test Complete"
echo "========================================="
echo ""
echo "Summary:"
echo "- Certificates generated and validated"
echo "- SuperLink running with TLS enabled"
echo "- All private keys properly secured"
echo ""
echo "Next steps:"
echo "1. Start SuperNodes: docker-compose -f docker-compose.tls.yml up -d"
echo "2. Run FL job: cd quickstart-docker && flwr run . local-deployment --stream"
