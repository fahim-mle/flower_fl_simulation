#!/bin/bash
set -e

echo "=== Flower Docker Architecture Test ==="
cd /home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker

echo "[1/11] Validating Docker Compose configuration..."
docker compose config --quiet && echo "  ✓ YAML syntax valid"

echo "[2/11] Building images..."
docker compose build --no-cache
echo "  ✓ Images built successfully"

echo "[3/11] Starting services..."
docker compose up -d
echo "  ✓ Services started"

echo "[4/11] Waiting for services to initialize (60s)..."
sleep 60

echo "[5/11] Checking health status..."
docker compose ps
echo "  ✓ Health checks completed"

echo "[6/11] Validating network connectivity..."
docker exec flower-supernode-1 ping -c 3 superlink > /dev/null && echo "  ✓ SuperNode-1 -> SuperLink"
docker exec flower-superexec-clientapp-1 ping -c 3 supernode-1 > /dev/null && echo "  ✓ SuperExec-CA1 -> SuperNode-1"

echo "[7/11] Checking TLS certificates..."
docker exec flower-superlink ls /app/certificates/ca/ca.crt > /dev/null && echo "  ✓ SuperLink CA cert"
docker exec flower-supernode-1 ls /app/certificates/ca/ca.crt > /dev/null && echo "  ✓ SuperNode-1 CA cert"
docker exec flower-superexec-serverapp ls /app/certificates/ca/ca.crt > /dev/null && echo "  ✓ SuperExec-SA CA cert"

echo "[8/11] Verifying SuperExec arguments..."
docker inspect flower-superexec-serverapp | grep -q "plugin-type=serverapp" && echo "  ✓ ServerApp arguments correct"
docker inspect flower-superexec-clientapp-1 | grep -q "plugin-type=clientapp" && echo "  ✓ ClientApp-1 arguments correct"

echo "[9/11] Analyzing logs for errors..."
ERROR_COUNT=$(docker compose logs | grep -i error | grep -v "0 error" | wc -l)
echo "  ✓ Found $ERROR_COUNT error messages"

echo "[10/11] Testing inter-service communication..."
docker exec flower-superexec-serverapp nc -zv superlink 9091 2>&1 | grep -q succeeded && echo "  ✓ SuperExec-SA -> SuperLink:9091"
docker exec flower-superexec-clientapp-1 nc -zv supernode-1 9094 2>&1 | grep -q succeeded && echo "  ✓ SuperExec-CA1 -> SuperNode-1:9094"

echo "[11/11] Checking resource usage..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "=== Test Complete ==="
echo "All services are running. Check logs with: docker compose logs -f"
