# Docker Architecture Testing Procedure

## Overview
This document provides a comprehensive testing procedure for the three-SuperExec Docker architecture with TLS/mTLS security.

## Architecture Summary

```
SuperLink (Port 9091, 9092, 9093)
    |
    +-- SuperExec-ServerApp (connects to SuperLink:9091)
    |
    +-- SuperNode-1 (connects to SuperLink:9092, exposes 9094)
    |       |
    |       +-- SuperExec-ClientApp-1 (connects to SuperNode-1:9094)
    |
    +-- SuperNode-2 (connects to SuperLink:9092, exposes 9095)
            |
            +-- SuperExec-ClientApp-2 (connects to SuperNode-2:9095)
```

## Pre-Test Checklist

### 1. Certificate Validation
```bash
# Verify certificates exist
ls -la /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/ca/ca.crt
ls -la /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/server/server.crt
ls -la /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/server/server.key

# Check certificate validity
openssl x509 -in /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/ca/ca.crt -noout -text
openssl x509 -in /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/server/server.crt -noout -text

# Verify server cert is signed by CA
openssl verify -CAfile /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/ca/ca.crt \
  /home/ghost/workspace/internship_project/flower_fl_simulation/certificates/server/server.crt
```

### 2. Docker Environment Check
```bash
# Check Docker version
docker --version
docker compose version

# Clean up any existing containers
docker compose down -v
cd quickstart-docker && docker compose down -v && cd ..

# Remove old images (optional - for fresh build)
docker images | grep flower | awk '{print $3}' | xargs docker rmi -f
```

## Testing Procedures

### Test 1: Docker Compose Validation

**Location**: `/home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker`

```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker

# Validate YAML syntax
docker compose config --quiet
echo "Exit code: $?"  # Should be 0

# Check for circular dependencies (should show no errors)
docker compose config > /tmp/compose-validated.yml

# Verify service dependencies
docker compose config | grep -A 5 "depends_on:"
```

**Expected Result**: No errors, clean YAML output

---

### Test 2: Image Building

```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker

# Build all custom images
docker compose build --no-cache

# Verify images were created
docker images | grep flower
```

**Expected Images**:
- `quickstart-docker-superlink`
- `quickstart-docker-superexec-serverapp`
- `quickstart-docker-superexec-clientapp-1`
- `quickstart-docker-superexec-clientapp-2`
- `quickstart-docker-supernode-1`
- `quickstart-docker-supernode-2`

**Success Criteria**:
- All images build without errors
- No certificate copying errors
- Dependencies installed successfully

---

### Test 3: Service Startup Sequence

```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker

# Start services in detached mode
docker compose up -d

# Watch logs for startup sequence
docker compose logs -f
```

**Expected Startup Order**:
1. `superlink` starts first (40s start period)
2. `superlink` becomes healthy
3. `superexec-serverapp` starts (depends on healthy SuperLink)
4. `supernode-1` and `supernode-2` start in parallel
5. `superexec-clientapp-1` and `superexec-clientapp-2` start last

**Success Indicators**:
- SuperLink: "Starting Flower SuperLink" message
- SuperExec: "Starting Flower SuperExec" with correct plugin type
- SuperNode: "Connected to SuperLink" message
- No TLS/certificate errors

---

### Test 4: Health Check Validation

```bash
# Wait 60 seconds for all services to initialize
sleep 60

# Check health status of all services
docker compose ps

# Detailed health check
docker inspect flower-superlink | grep -A 10 "Health"
docker inspect flower-superexec-serverapp | grep -A 10 "Health"
docker inspect flower-supernode-1 | grep -A 10 "Health"
```

**Expected Status**: All services should show `(healthy)` or `Up`

---

### Test 5: Network Connectivity

```bash
# Check network exists
docker network inspect flower-fl-network

# Verify all containers are on the network
docker network inspect flower-fl-network | grep -A 3 "Containers"

# Test DNS resolution between containers
docker exec flower-supernode-1 ping -c 3 superlink
docker exec flower-superexec-clientapp-1 ping -c 3 supernode-1
docker exec flower-superexec-serverapp ping -c 3 superlink

# Check if ports are exposed
docker exec flower-supernode-1 netstat -tlnp | grep 9094
docker exec flower-supernode-2 netstat -tlnp | grep 9095
```

**Success Criteria**:
- Ping successful between all containers
- DNS resolution works (hostname -> IP)
- ClientAppIO ports (9094, 9095) are listening

---

### Test 6: TLS Certificate Validation

```bash
# Verify CA cert is mounted in SuperLink
docker exec flower-superlink ls -la /app/certificates/ca/ca.crt

# Verify CA cert is mounted in SuperNodes
docker exec flower-supernode-1 ls -la /app/certificates/ca/ca.crt
docker exec flower-supernode-2 ls -la /app/certificates/ca/ca.crt

# Verify CA cert is mounted in SuperExec services
docker exec flower-superexec-serverapp ls -la /app/certificates/ca/ca.crt
docker exec flower-superexec-clientapp-1 ls -la /app/certificates/ca/ca.crt
docker exec flower-superexec-clientapp-2 ls -la /app/certificates/ca/ca.crt

# Check SSL environment variables in SuperExec
docker exec flower-superexec-serverapp env | grep -E "SSL_CERT_FILE|REQUESTS_CA_BUNDLE"
docker exec flower-superexec-clientapp-1 env | grep -E "SSL_CERT_FILE|REQUESTS_CA_BUNDLE"
```

**Expected Output**:
- All CA certificates present and readable
- SSL environment variables set correctly:
  - `SSL_CERT_FILE=/app/certificates/ca/ca.crt`
  - `REQUESTS_CA_BUNDLE=/app/certificates/ca/ca.crt`

---

### Test 7: SuperExec Command Arguments

```bash
# Check SuperExec-ServerApp command
docker inspect flower-superexec-serverapp | grep -A 5 "Cmd"

# Check SuperExec-ClientApp-1 command
docker inspect flower-superexec-clientapp-1 | grep -A 5 "Cmd"

# Check SuperExec-ClientApp-2 command
docker inspect flower-superexec-clientapp-2 | grep -A 5 "Cmd"
```

**Expected Arguments**:
- **ServerApp**: `--plugin-type=serverapp --appio-api-address=superlink:9091`
- **ClientApp-1**: `--plugin-type=clientapp --appio-api-address=supernode-1:9094`
- **ClientApp-2**: `--plugin-type=clientapp --appio-api-address=supernode-2:9095`

**No Invalid Arguments**: Should NOT see `--executor` or `--executor-config`

---

### Test 8: Log Analysis

```bash
# Check for errors in SuperLink logs
docker compose logs superlink | grep -i error

# Check for errors in SuperExec logs
docker compose logs superexec-serverapp | grep -i error
docker compose logs superexec-clientapp-1 | grep -i error
docker compose logs superexec-clientapp-2 | grep -i error

# Check for errors in SuperNode logs
docker compose logs supernode-1 | grep -i error
docker compose logs supernode-2 | grep -i error

# Look for specific success messages
docker compose logs superlink | grep "Starting Flower SuperLink"
docker compose logs superexec-serverapp | grep "ServerApp"
docker compose logs supernode-1 | grep "Connected"
```

**Success Indicators**:
- No "unrecognized arguments" errors
- No TLS handshake failures
- No connection refused errors
- Positive connection messages present

---

### Test 9: Inter-Service Communication

```bash
# Check if SuperExec can reach SuperLink
docker exec flower-superexec-serverapp nc -zv superlink 9091

# Check if SuperExec can reach SuperNodes
docker exec flower-superexec-clientapp-1 nc -zv supernode-1 9094
docker exec flower-superexec-clientapp-2 nc -zv supernode-2 9095

# Check if SuperNodes can reach SuperLink
docker exec flower-supernode-1 nc -zv superlink 9092
docker exec flower-supernode-2 nc -zv superlink 9092
```

**Expected Result**: All connections should succeed

---

### Test 10: Resource Usage Monitoring

```bash
# Check resource consumption
docker stats --no-stream

# Verify resource limits are applied
docker inspect flower-superlink | grep -A 10 "Resources"
docker inspect flower-superexec-serverapp | grep -A 10 "Resources"
docker inspect flower-supernode-1 | grep -A 10 "Resources"
```

**Expected Limits**:
- **SuperLink**: 2 CPU, 2GB memory (reserve: 0.5 CPU, 512MB)
- **SuperExec**: 2 CPU, 2GB memory (reserve: 0.5-1.0 CPU, 512MB)
- **SuperNode**: 2 CPU, 4GB memory (reserve: 0.5 CPU, 1GB)

---

### Test 11: Volume Persistence

```bash
# Check volume mounts
docker inspect flower-superlink | grep -A 20 "Mounts"
docker inspect flower-supernode-1 | grep -A 20 "Mounts"

# Verify volumes exist
docker volume ls | grep flower

# Check data persistence
docker exec flower-supernode-1 ls -la /app/data
docker exec flower-supernode-1 ls -la /app/.cache
```

**Expected Volumes**:
- `flower-superlink-data`
- `flower-superlink-logs`
- `flower-model-outputs`
- `flower-supernode1-data`
- `flower-supernode1-cache`
- `flower-supernode2-data`
- `flower-supernode2-cache`

---

## Troubleshooting Guide

### Issue: Circular Dependency Error
**Symptom**: `dependency cycle detected`
**Fix**: Ensure SuperNodes do NOT depend on SuperExec services. SuperExec depends on SuperNode, not vice versa.

### Issue: Certificate Not Found
**Symptom**: `No such file or directory: /app/certificates/ca/ca.crt`
**Fix**:
1. Verify certificate path in host: `ls -la ../certificates/ca/ca.crt`
2. Check volume mount syntax: `- ../certificates/ca/ca.crt:/app/certificates/ca/ca.crt:ro`

### Issue: TLS Handshake Failure
**Symptom**: `SSL: CERTIFICATE_VERIFY_FAILED`
**Fix**:
1. Verify SSL environment variables are set in SuperExec
2. Check CA certificate is valid and not expired
3. Ensure server certificate is signed by the mounted CA

### Issue: SuperExec Invalid Arguments
**Symptom**: `unrecognized arguments: --executor`
**Fix**: Use `--plugin-type` and `--appio-api-address` only

### Issue: Connection Refused
**Symptom**: `Connection refused on port 9094/9095`
**Fix**:
1. Verify SuperNode is running: `docker compose ps`
2. Check SuperNode command includes `--clientappio-api-address=0.0.0.0:9094`
3. Ensure no firewall blocking container communication

---

## Complete Test Run Script

Save this as `/home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker/scripts/test-architecture.sh`:

```bash
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
```

---

## Cleanup Procedure

```bash
# Stop all services
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v

# Remove images
docker images | grep quickstart-docker | awk '{print $3}' | xargs docker rmi -f

# Remove network
docker network rm flower-fl-network
```

---

## Success Criteria Summary

- [ ] No circular dependency errors in `docker compose config`
- [ ] All images build successfully
- [ ] All containers start and reach healthy state
- [ ] Network connectivity works between all services
- [ ] TLS certificates are properly mounted and accessible
- [ ] SuperExec uses correct command arguments (no --executor)
- [ ] SSL environment variables are set in SuperExec containers
- [ ] No TLS handshake or certificate verification errors in logs
- [ ] Inter-service communication works (SuperExec -> SuperLink/SuperNode)
- [ ] Resource limits are applied correctly
- [ ] Volumes persist data across restarts

---

## Next Steps After Successful Testing

1. Test with actual Flower application (run training job)
2. Verify model aggregation works correctly
3. Test failover scenarios (kill containers, check restart)
4. Load testing (more SuperNodes)
5. Security audit (check exposed ports, certificate validation)
