# Secure Flower FL Docker Deployment Guide

## Overview

This deployment provides a production-ready Flower Federated Learning infrastructure with:
- **TLS Security**: All communications encrypted with TLS
- **Docker Containerization**: 1 SuperLink + 2 SuperNodes in isolated containers
- **Health Monitoring**: Automatic health checks and restart on failure
- **Resource Management**: CPU and memory limits
- **Persistent Storage**: Models, logs, and cache persist across restarts

**Security Note**: This deployment uses TLS for encryption. Flower 1.22.0 supports SSH key-based authentication (not X.509 certificate-based mTLS) for client authentication. The X.509 certificates are used only for TLS encryption.

## Quick Start

### 1. Start the Deployment

```bash
./scripts/start-secure.sh
```

This automated script will:
1. Validate all certificates exist
2. Verify certificate chain integrity
3. Set proper permissions for Docker
4. Build Docker images
5. Start all containers with health monitoring

### 2. Monitor Status

```bash
./scripts/check-status.sh
```

View real-time logs:

```bash
./scripts/check-status.sh --follow
```

### 3. Run Federated Learning

Once all containers are healthy:

```bash
flwr run . --federation local-deployment
```

### 4. Stop the Deployment

```bash
./scripts/stop-secure.sh
```

To remove all data (volumes and images):

```bash
./scripts/stop-secure.sh --all
```

## Architecture

### Components

```
┌────────────────────────────────────────────────────────────────┐
│            Docker Network: flower-fl-network                   │
│                     (172.28.0.0/16)                            │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  SuperLink (flower-superlink)                            │ │
│  │  • Ports: 9092 (Fleet API), 9093 (Control API)           │ │
│  │  •        9091 (ServerAppIO API - for SuperExec)         │ │
│  │  • Certs: server.crt + server.key + CA                   │ │
│  │  • Health: gRPC health probe                             │ │
│  │  • Resources: 2 CPU, 2GB RAM                             │ │
│  └────────────────────┬─────────────────────────────────────┘ │
│                       │                                        │
│         ┌─────────────┼─────────────┬─────────────┐           │
│         │ TLS (9091)  │ TLS (9092)  │ TLS (9092)  │           │
│         ▼             ▼             ▼             │           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│  │SuperExec-SA  │ │SuperNode-1   │ │SuperNode-2   │          │
│  │• ServerApp   │ │• TLS Auth    │ │• TLS Auth    │          │
│  │  executor    │ │• CA cert     │ │• CA cert     │          │
│  │• CA cert     │ │• partition=0 │ │• partition=1 │          │
│  │• 2 CPU, 2GB  │ │• Port: 9094  │ │• Port: 9095  │          │
│  └──────────────┘ │• 2 CPU, 4GB  │ │• 2 CPU, 4GB  │          │
│                   └──────┬───────┘ └──────┬───────┘          │
│                          │ TLS (9094)      │ TLS (9095)       │
│                          ▼                 ▼                  │
│                   ┌──────────────┐  ┌──────────────┐         │
│                   │SuperExec-CA1 │  │SuperExec-CA2 │         │
│                   │• ClientApp   │  │• ClientApp   │         │
│                   │  executor #1 │  │  executor #2 │         │
│                   │• CA cert     │  │• CA cert     │         │
│                   │• 2 CPU, 2GB  │  │• 2 CPU, 2GB  │         │
│                   └──────────────┘  └──────────────┘         │
└────────────────────────────────────────────────────────────────┘

Architecture:
• SuperExec-SA: Executes ServerApp (aggregation logic)
• SuperExec-CA1: Executes ClientApp for SuperNode-1
• SuperExec-CA2: Executes ClientApp for SuperNode-2
• Each SuperExec instance has a specific role (serverapp or clientapp)
```

### Services

| Service | Container Name | Port | Purpose | Resources |
|---------|---------------|------|---------|-----------|
| SuperLink | flower-superlink | 9091, 9092, 9093 | FL coordination server | 2 CPU, 2GB RAM |
| SuperExec-ServerApp | flower-superexec-serverapp | - | ServerApp executor (aggregation) | 2 CPU, 2GB RAM |
| SuperExec-ClientApp-1 | flower-superexec-clientapp-1 | - | ClientApp executor for Node-1 | 2 CPU, 2GB RAM |
| SuperExec-ClientApp-2 | flower-superexec-clientapp-2 | - | ClientApp executor for Node-2 | 2 CPU, 2GB RAM |
| SuperNode-1 | flower-supernode-1 | 9094 | FL client (partition 0) | 2 CPU, 4GB RAM |
| SuperNode-2 | flower-supernode-2 | 9095 | FL client (partition 1) | 2 CPU, 4GB RAM |

**Note**: Flower 1.22.0 requires separate SuperExec instances for ServerApp and each ClientApp. The SuperExec containers manage the execution of Flower applications but do not expose external ports.

### Network

- **Name**: flower-fl-network
- **Type**: Bridge (isolated)
- **Subnet**: 172.28.0.0/16
- **Purpose**: Secure container-to-container communication

### Volumes

| Volume | Purpose | Mounted To |
|--------|---------|-----------|
| flower-superlink-data | SuperLink state | /app/data |
| flower-superlink-logs | SuperLink logs | /app/logs |
| flower-model-outputs | Trained models | /app/outputs |
| flower-supernode1-data | Client 1 data | /app/data |
| flower-supernode1-cache | Client 1 dataset cache | /app/.cache |
| flower-supernode2-data | Client 2 data | /app/data |
| flower-supernode2-cache | Client 2 dataset cache | /app/.cache |

## Security Configuration

### TLS Setup

**SuperLink (Server-side TLS):**
- Server certificate: `server/server.crt`
- Server private key: `server/server.key`
- CA certificate: `ca/ca.crt`
- Ports: 9092 (Fleet API), 9093 (Other services)

**SuperNode (Client-side TLS):**
- CA certificate: `ca/ca.crt` (verifies SuperLink identity)
- Connects to: port 9092

**SuperExec (3 instances):**
- SuperExec-ServerApp: Connects to SuperLink:9091 with CA cert
- SuperExec-ClientApp-1: Connects to SuperNode-1:9094 with CA cert
- SuperExec-ClientApp-2: Connects to SuperNode-2:9095 with CA cert
- All instances use TLS (no --insecure flag)

**Authentication Note**: For client authentication, use SSH keys with `--auth-supernode-private-key` and `--auth-supernode-public-key` options. The X.509 certificates provide encryption only.

### Certificate Mounting

All certificates are mounted read-only from the host:

```yaml
volumes:
  - ../certificates/ca/ca.crt:/app/certificates/ca/ca.crt:ro
  - ../certificates/server/server.crt:/app/certificates/server/server.crt:ro
  - ../certificates/server/server.key:/app/certificates/server/server.key:ro
```

### Security Features

1. **Encrypted Communication**: TLS 1.2+ for all gRPC traffic
2. **Server Authentication**: SuperNodes verify SuperLink identity via CA certificate
3. **Certificate Chain Validation**: All certificates verified against CA
4. **Network Isolation**: No direct host network access
5. **Read-only Mounts**: Certificates cannot be modified
6. **Resource Limits**: Prevent DoS via resource exhaustion
7. **Health Checks**: Detect and restart unhealthy containers

## Management Scripts

### start-secure.sh

Starts the secure deployment with validation:

```bash
./scripts/start-secure.sh
```

Features:
- Certificate existence validation
- Certificate chain verification
- Permission fixing for Docker
- Image building
- Container startup
- Health check monitoring

### stop-secure.sh

Stops and optionally cleans up the deployment:

```bash
# Stop containers (preserve data)
./scripts/stop-secure.sh

# Remove volumes (delete data)
./scripts/stop-secure.sh --volumes

# Remove images (delete Docker images)
./scripts/stop-secure.sh --images

# Remove everything
./scripts/stop-secure.sh --all
```

### check-status.sh

Monitors deployment health and status:

```bash
# Show status
./scripts/check-status.sh

# Show recent logs
./scripts/check-status.sh --logs

# Follow logs in real-time
./scripts/check-status.sh --follow

# Check specific service
./scripts/check-status.sh -s superlink -l
```

## Configuration Files

### docker-compose.yml

Orchestrates all services with:
- Service definitions
- Network configuration
- Volume mounts
- Health checks
- Resource limits
- Dependencies

### pyproject.toml

Defines federation configurations:

```toml
[tool.flwr.federations.local-deployment]
address = "127.0.0.1:9093"
insecure = false
root-certificates = "../certificates/ca/ca.crt"

[tool.flwr.federations.docker-deployment]
address = "superlink:9093"
insecure = false
root-certificates = "/app/certificates/ca/ca.crt"
```

### Dockerfiles

- `superlink.Dockerfile`: SuperLink with TLS
- `supernode.Dockerfile`: SuperNode with mTLS
- `superexec.Dockerfile`: SuperExec with CA cert

## Troubleshooting

### Certificate Issues

**Problem**: Certificates not found

```bash
cd ../certificates
./scripts/setup/generate_ca.sh
./scripts/setup/generate_server_cert.sh
./scripts/setup/generate_client_cert.sh 1
./scripts/setup/generate_client_cert.sh 2
```

**Problem**: Certificate verification failed

```bash
# Verify server cert
openssl verify -CAfile ../certificates/ca/ca.crt ../certificates/server/server.crt

# Verify client certs
openssl verify -CAfile ../certificates/ca/ca.crt ../certificates/clients/client1.crt
openssl verify -CAfile ../certificates/ca/ca.crt ../certificates/clients/client2.crt
```

**Problem**: Certificate expired

```bash
# Check expiration
openssl x509 -in ../certificates/server/server.crt -noout -enddate

# Regenerate if expired
cd ../certificates
./scripts/setup/generate_server_cert.sh
./scripts/setup/generate_client_cert.sh 1
./scripts/setup/generate_client_cert.sh 2
```

### Container Issues

**Problem**: SuperLink unhealthy

```bash
# Check logs
docker logs flower-superlink

# Verify certificate paths
docker exec flower-superlink ls -la /app/certificates/

# Restart
docker restart flower-superlink
```

**Problem**: SuperNode connection failed

```bash
# Check logs
docker logs flower-supernode-1

# Test connectivity
docker exec flower-supernode-1 ping -c 3 superlink

# Verify certificates
docker exec flower-supernode-1 ls -la /app/certificates/
```

**Problem**: Port 9093 already in use

```bash
# Find what's using the port
sudo lsof -i :9093

# Kill the process or modify docker-compose.yml ports section
```

### Network Issues

**Problem**: Cannot reach SuperLink

```bash
# Check network exists
docker network ls | grep flower-fl-network

# Inspect network
docker network inspect flower-fl-network

# Verify containers are connected
docker network inspect flower-fl-network | grep -A 10 Containers
```

### Volume Issues

**Problem**: Data not persisting

```bash
# List volumes
docker volume ls | grep flower

# Inspect volume
docker volume inspect flower-model-outputs

# Check mounts
docker inspect flower-supernode-1 | grep -A 20 Mounts
```

## Manual Operations

### Build Images

```bash
docker compose build
```

Build specific service:

```bash
docker compose build superlink
```

### Start Services

```bash
# Start in background
docker compose up -d

# Start with logs
docker compose up

# Start specific service
docker compose up -d superlink
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f superlink

# Last N lines
docker compose logs --tail=100 supernode-1
```

### Stop Services

```bash
# Stop all
docker compose down

# Stop but keep volumes
docker compose stop

# Stop specific service
docker compose stop supernode-1
```

### Clean Up

```bash
# Remove containers and network (keep volumes)
docker compose down

# Remove everything including volumes
docker compose down -v

# Remove everything including images
docker compose down -v --rmi all
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart superlink
```

### Scale SuperNodes

To add more SuperNodes:

1. Generate new client certificate:
   ```bash
   cd ../certificates
   ./scripts/setup/generate_client_cert.sh 3
   ```

2. Add service to `docker-compose.yml`:
   ```yaml
   supernode-3:
     build:
       context: .
       dockerfile: supernode.Dockerfile
     container_name: flower-supernode-3
     # ... copy from supernode-2 and update partition-id
   ```

3. Restart deployment:
   ```bash
   ./scripts/stop-secure.sh
   ./scripts/start-secure.sh
   ```

## Best Practices

### Development

1. **Test certificates first**: Run `start-secure.sh` to validate certs
2. **Monitor logs**: Use `check-status.sh --follow` during development
3. **Incremental updates**: Rebuild only changed services
4. **Clean restarts**: Use `stop-secure.sh && start-secure.sh`

### Production

1. **Secure certificate storage**: Store private keys in secrets management
2. **Certificate rotation**: Rotate certs before expiry (see ../certificates/README.md)
3. **Resource monitoring**: Monitor CPU/memory usage
4. **Log aggregation**: Forward logs to centralized logging system
5. **Backup volumes**: Regularly backup model outputs and data
6. **Network policies**: Use Docker network policies for additional isolation
7. **Health monitoring**: Set up external monitoring for container health
8. **Update strategy**: Test updates in staging before production

### Security Hardening

1. **Restrict permissions**: `chmod 400` on private keys (development uses 644 for Docker)
2. **Rotate certificates**: Before expiration (calendar reminder set for 2026-09-18)
3. **Audit access**: Monitor who accesses certificate files
4. **Network segmentation**: Deploy in isolated network segment
5. **Firewall rules**: Only allow necessary ports (9093)
6. **Image scanning**: Scan Docker images for vulnerabilities
7. **Minimize images**: Use multi-stage builds (already implemented)
8. **Secrets management**: Use Docker secrets for production

## Performance Tuning

### Resource Allocation

Adjust in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4.0'      # Increase for better performance
      memory: 8G
    reservations:
      cpus: '1.0'
      memory: 2G
```

### Network Performance

For high-throughput scenarios:

```yaml
networks:
  flower-fl-network:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 9000  # Jumbo frames
```

### Volume Performance

Use local volumes for better I/O:

```yaml
volumes:
  model-outputs:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/fast/storage
```

## Monitoring and Observability

### Container Metrics

```bash
# Real-time stats
docker stats

# Specific container
docker stats flower-superlink
```

### Health Status

```bash
# Check health
docker inspect flower-superlink --format='{{.State.Health.Status}}'

# View health logs
docker inspect flower-superlink --format='{{json .State.Health}}' | jq
```

### Network Traffic

```bash
# Monitor network
docker network inspect flower-fl-network

# Traffic between containers
docker exec flower-supernode-1 netstat -an | grep 9093
```

## References

- [Flower Documentation](https://flower.ai/docs/)
- [Flower with Docker](https://flower.ai/docs/framework/docker/index.html)
- [TLS Configuration](https://flower.ai/docs/framework/how-to-enable-tls-connections.html)
- [SuperNode Authentication](https://flower.ai/docs/framework/how-to-authenticate-supernodes.html)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Certificate Management](../certificates/README.md)

## Support

For issues or questions:
1. Check logs: `./scripts/check-status.sh --logs`
2. Review troubleshooting section above
3. Verify certificates: See ../certificates/README.md
4. Check Flower documentation: https://flower.ai/docs/
