# quickstart-docker: A Flower / PyTorch app

## Install dependencies and project

The dependencies are listed in the `pyproject.toml` and you can install them as follows:

```bash
pip install -e .
```

> **Tip:** Your `pyproject.toml` file can define more than just the dependencies of your Flower app. You can also use it to specify hyperparameters for your runs and control which Flower Runtime is used. By default, it uses the Simulation Runtime, but you can switch to the Deployment Runtime when needed.
> Learn more in the [TOML configuration guide](https://flower.ai/docs/framework/how-to-configure-pyproject-toml.html).

## Run with the Simulation Engine

In the `quickstart-docker` directory, use `flwr run` to run a local simulation:

```bash
flwr run .
```

Refer to the [How to Run Simulations](https://flower.ai/docs/framework/how-to-run-simulations.html) guide in the documentation for advice on how to optimize your simulations.

## Run with Secure Docker Deployment (TLS)

This project includes a production-ready Docker deployment with TLS encryption for secure communication.

### Prerequisites

1. **Certificates**: Ensure TLS certificates are generated in `../certificates/`
   - CA certificate: `ca/ca.crt` (for verification)
   - Server certificates: `server/server.crt`, `server/server.key` (for SuperLink TLS)

   If certificates don't exist, generate them using the scripts in `../certificates/scripts/setup/`:
   ```bash
   cd ../certificates
   ./scripts/setup/generate_ca.sh
   ./scripts/setup/generate_server_cert.sh
   ```

2. **Docker**: Docker and Docker Compose must be installed and running.

### Quick Start

Start the secure Flower FL deployment:

```bash
./scripts/start-secure.sh
```

This script will:
- Validate all required certificates
- Verify certificate chain integrity
- Set proper permissions for Docker
- Build Docker images
- Start SuperLink, 3 SuperExec instances, and 2 SuperNodes (all with TLS enabled)

### Check Deployment Status

Monitor the health and status of all containers:

```bash
./scripts/check-status.sh
```

View logs:

```bash
./scripts/check-status.sh --logs           # Show recent logs
./scripts/check-status.sh --follow         # Follow logs in real-time
./scripts/check-status.sh -s superlink -l  # Show SuperLink logs only
```

### Run Federated Learning

Once the deployment is running (all containers healthy), execute your FL job:

```bash
# From the quickstart-docker directory
flwr run . --federation local-deployment
```

Note: The FL job execution is managed automatically by the three SuperExec containers (serverapp, clientapp-1, clientapp-2). You don't need to manually execute commands in the SuperExec containers.

### Stop the Deployment

Stop all containers (preserves volumes):

```bash
./scripts/stop-secure.sh
```

Stop and remove all data (volumes + images):

```bash
./scripts/stop-secure.sh --all
```

Options:
- `--volumes` or `-v`: Remove persistent volumes (model data, logs, cache)
- `--images` or `-i`: Remove Docker images
- `--all` or `-a`: Remove everything

### Architecture

The deployment consists of:

- **SuperLink** (flower-superlink): Central FL server with TLS encryption
  - Ports: 9091 (ServerAppIO API), 9092 (Fleet API), 9093 (Control API)
  - Certificates: Server cert + CA cert
  - Health checks: Automatic monitoring and restart

- **SuperExec (3 instances)**: Manages FL app execution
  - **SuperExec-ServerApp** (flower-superexec-serverapp): Executes ServerApp logic
    - Connects to SuperLink:9091 via TLS
  - **SuperExec-ClientApp-1** (flower-superexec-clientapp-1): Executes ClientApp for Node-1
    - Connects to SuperNode-1:9094 via TLS
  - **SuperExec-ClientApp-2** (flower-superexec-clientapp-2): Executes ClientApp for Node-2
    - Connects to SuperNode-2:9095 via TLS
  - All instances use CA cert for verification

- **SuperNode 1 & 2** (flower-supernode-1, flower-supernode-2): FL clients
  - TLS encryption with CA certificate verification
  - Isolated data partitions (partition-id=0, partition-id=1)
  - Resource limits: 2 CPU cores, 4GB RAM each

**Why 3 SuperExec instances?** Flower 1.22.0 deployment architecture requires separate execution engines for ServerApp (aggregation) and each ClientApp (training). This separation provides better isolation and resource management.

All containers communicate over an isolated Docker bridge network (`flower-fl-network`).

### Persistent Storage

The following volumes persist data across container restarts:

- `flower-superlink-data`: SuperLink state
- `flower-superlink-logs`: SuperLink logs
- `flower-model-outputs`: Trained model checkpoints
- `flower-supernode1-data` / `flower-supernode2-data`: Client data
- `flower-supernode1-cache` / `flower-supernode2-cache`: Dataset cache

### Security Features

- **TLS Encryption**: All communication encrypted with TLS 1.2+
- **Certificate Validation**: SuperNodes verify SuperLink identity using CA certificate
- **Network Isolation**: Custom Docker bridge network
- **Read-only Mounts**: Certificates mounted read-only for security
- **Resource Limits**: CPU and memory limits prevent resource exhaustion

**Note**: This deployment uses TLS for encryption only. For client authentication, Flower 1.22.0 supports SSH key-based authentication (not X.509 certificates). To add client authentication, use the `--auth-supernode-private-key` and `--auth-supernode-public-key` options with SSH keys.

### Troubleshooting

**Certificates not found:**
```bash
cd ../certificates
./scripts/setup/generate_ca.sh
./scripts/setup/generate_server_cert.sh
```

**SuperLink unhealthy:**
```bash
docker logs flower-superlink
# Check certificate paths and permissions
```

**SuperNode connection failed:**
```bash
docker logs flower-supernode-1
# Check if SuperNode can reach SuperLink
docker exec flower-supernode-1 ping -c 3 superlink
# Verify CA certificate is valid
openssl verify -CAfile ../certificates/ca/ca.crt ../certificates/server/server.crt
```

**Ports already in use:**
```bash
# Check what's using port 9092 or 9093
sudo lsof -i :9092
sudo lsof -i :9093
# Stop conflicting service or modify docker-compose.yml port mapping
```

### Manual Docker Commands

If you prefer manual control:

```bash
# Build images
docker compose build

# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Remove everything
docker compose down -v --rmi all
```

## Run with the Deployment Engine (Local)

Follow this [how-to guide](https://flower.ai/docs/framework/how-to-run-flower-with-deployment-engine.html) to run the same app in this example but with Flower's Deployment Engine. After that, you might be interested in setting up [secure TLS-enabled communications](https://flower.ai/docs/framework/how-to-enable-tls-connections.html) and [SuperNode authentication](https://flower.ai/docs/framework/how-to-authenticate-supernodes.html) in your federation.

## Resources

- Flower website: [flower.ai](https://flower.ai/)
- Check the documentation: [flower.ai/docs](https://flower.ai/docs/)
- Give Flower a ⭐️ on GitHub: [GitHub](https://github.com/adap/flower)
- Join the Flower community!
  - [Flower Slack](https://flower.ai/join-slack/)
  - [Flower Discuss](https://discuss.flower.ai/)
