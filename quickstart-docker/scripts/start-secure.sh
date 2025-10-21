#!/bin/bash

# Secure Flower FL Docker Deployment Startup Script
# This script starts the Flower FL infrastructure with TLS security

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Flower FL Secure Docker Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Change to script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo -e "${YELLOW}[1/5] Validating certificates...${NC}"

# Check if certificates exist
CERT_DIR="../certificates"
REQUIRED_CERTS=(
    "$CERT_DIR/ca/ca.crt"
    "$CERT_DIR/server/server.crt"
    "$CERT_DIR/server/server.key"
)

MISSING_CERTS=0
for cert in "${REQUIRED_CERTS[@]}"; do
    if [ ! -f "$cert" ]; then
        echo -e "${RED}  ✗ Missing: $cert${NC}"
        MISSING_CERTS=1
    else
        echo -e "${GREEN}  ✓ Found: $cert${NC}"
    fi
done

if [ $MISSING_CERTS -eq 1 ]; then
    echo -e "${RED}Error: Required certificates are missing!${NC}"
    echo -e "${YELLOW}Please run the certificate generation scripts first:${NC}"
    echo -e "${YELLOW}  cd ../certificates${NC}"
    echo -e "${YELLOW}  ./scripts/setup/generate_ca.sh${NC}"
    echo -e "${YELLOW}  ./scripts/setup/generate_server_cert.sh${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[2/5] Verifying certificate validity...${NC}"

# Verify certificates are valid
if openssl verify -CAfile "$CERT_DIR/ca/ca.crt" "$CERT_DIR/server/server.crt" > /dev/null 2>&1; then
    echo -e "${GREEN}  ✓ Server certificate is valid${NC}"
else
    echo -e "${RED}  ✗ Server certificate verification failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}[3/5] Setting certificate permissions for Docker...${NC}"

# Set appropriate permissions for Docker to read certificates
chmod 644 "$CERT_DIR/server/server.key" 2>/dev/null || true

echo -e "${GREEN}  ✓ Certificate permissions updated${NC}"

echo ""
echo -e "${YELLOW}[4/5] Building Docker images...${NC}"

# Build Docker images
docker compose build --progress=plain

echo ""
echo -e "${YELLOW}[5/5] Starting Flower FL infrastructure...${NC}"

# Start Docker containers
docker compose up -d

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Started Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo -e "  • SuperLink:   https://127.0.0.1:9093 (TLS enabled)"
echo -e "  • SuperNode-1: Running with mTLS authentication"
echo -e "  • SuperNode-2: Running with mTLS authentication"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "  • Check status:    ${YELLOW}./scripts/check-status.sh${NC}"
echo -e "  • View logs:       ${YELLOW}docker compose logs -f${NC}"
echo -e "  • Stop deployment: ${YELLOW}./scripts/stop-secure.sh${NC}"
echo ""
echo -e "${YELLOW}Waiting for services to become healthy...${NC}"
echo -e "(This may take 30-60 seconds)"
echo ""

# Wait for SuperLink to become healthy
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if docker inspect flower-superlink --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        echo -e "${GREEN}✓ SuperLink is healthy and ready!${NC}"
        break
    fi
    sleep 2
    WAITED=$((WAITED + 2))
    echo -n "."
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo ""
    echo -e "${YELLOW}Warning: SuperLink health check timeout. Check logs with: docker compose logs superlink${NC}"
fi

echo ""
echo -e "${GREEN}Deployment ready! Run federated learning with:${NC}"
echo -e "${YELLOW}  flwr run . --federation local-deployment${NC}"
echo ""
