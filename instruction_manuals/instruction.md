# Federated Learning Infrastructure - Dockerized OPS Manual Tasklist

## PHASE 1: PROJECT FOUNDATION & CERTIFICATE AUTHORITY

**Objective**: Replicate OPS manual PKI in project directory with Docker adaptations

### 1.1. Project Structure Setup

- [ ] Create project directory structure mirroring OPS manual but containerized
- [ ] Establish `./ca/` directory for certificate authority (not system-wide)
- [ ] Create Docker volume directories for certificate distribution
- [ ] Set up configuration directories for each service

### 1.2. Certificate Authority Setup (OPS 4.1.2.2 Adapted)

- [ ] Install easy-rsa locally (not in containers)
- [ ] Initialize CA in `./ca/` directory (not `/usr/share/easy-rsa`)
- [ ] Generate CA certificate with your organization details
- [ ] Modify certificate generation for Docker service names vs IP addresses

### 1.3. Service Certificate Generation

- [ ] Generate server certificates for all services using Docker DNS names
- [ ] Create client certificates for organizations (SuperNodes)
- [ ] Adapt Subject Alternative Names for `localhost` and container names
- [ ] Deploy certificates to Docker volume mounts for container access

## PHASE 2: DOCKER NETWORKING ARCHITECTURE

**Objective**: Recreate OPS manual network topology using Docker networks

### 2.1. Network Segmentation (OPS 2.1 Adapted)

- [ ] Create `fl-services-network` (172.20.0.0/16) - Main services
- [ ] Create `fl-clients-network` (172.21.0.0/16) - SuperNode clients
- [ ] Create `fl-monitoring-network` (172.22.0.0/16) - Monitoring stack
- [ ] Configure inter-network communication for service discovery

### 2.2. Host Integration

- [ ] Configure `/etc/hosts` for local domain resolution
- [ ] Set up localhost-only port binding for development safety
- [ ] Plan external access via NGINX reverse proxy

## PHASE 3: CORE INFRASTRUCTURE DEPLOYMENT

**Objective**: Deploy foundational services following OPS manual sequence

### 3.1. Database Layer (OPS 4.1.2.8)

- [ ] Deploy PostgreSQL container with persistent volume
- [ ] Initialize databases for Keycloak and application data
- [ ] Configure SSL connections using mounted certificates

### 3.2. Identity Management (OPS 4.1.2.9-4.1.2.10)

- [ ] Deploy Keycloak container with PostgreSQL backend
- [ ] Configure realms, clients, and users following OPS manual
- [ ] Set up OIDC configuration for service authentication
- [ ] Mount SSL certificates for HTTPS termination

### 3.3. Reverse Proxy (OPS 4.1.2.5-4.1.2.7 Adapted)

- [ ] Deploy NGINX container as reverse proxy
- [ ] Configure virtual hosts for all services
- [ ] Set up SSL termination with all service certificates
- [ ] Implement domain-based routing to containers

## PHASE 4: FEDERATED LEARNING CORE SERVICES

**Objective**: Deploy Flower components with Docker adaptations

### 4.1. SuperLink Deployment (OPS 4.1.2.16)

- [ ] Create SuperLink container with Python environment
- [ ] Configure SSL/mTLS using mounted certificates
- [ ] Set up database connection and state management
- [ ] Implement OIDC authentication (if using QCIF customization)

### 4.2. SuperNode Deployment (OPS 4.1.3 & Appendix 5.7)

- [ ] Build SuperNode containers using OPS manual Dockerfiles
- [ ] Deploy multiple SuperNodes for different organizations
- [ ] Configure partition IDs and cluster topology
- [ ] Set up GPU passthrough for training containers

## PHASE 5: USER INTERFACE & MONITORING

**Objective**: Deploy user-facing services and monitoring

### 5.1. JupyterHub Deployment (OPS 4.1.2.13-4.1.2.15)

- [ ] Deploy JupyterHub container with OIDC authentication
- [ ] Configure DockerSpawner for user containers
- [ ] Set up user workspace persistence
- [ ] Mount certificates for secure communication

### 5.2. Monitoring Stack (OPS Chapter 5)

- [ ] Deploy Prometheus for metrics collection
- [ ] Set up Grafana for dashboards and alerting
- [ ] Configure node exporters for host monitoring
- [ ] Implement GPU monitoring with DCGM exporters

## PHASE 6: VPN SIMULATION (OPTIONAL)

**Objective**: Simulate OPS manual VPN topology in Docker

### 6.1. Network Isolation

- [ ] Use Docker networks to simulate organizational boundaries
- [ ] Configure firewall rules between networks
- [ ] Set up routing between "organizations"

### 6.2. VPN Alternative

- [ ] Use Docker network policies for access control
- [ ] Implement service discovery across networks
- [ ] Test cross-organizational communication

## PHASE 7: DEPLOYMENT VALIDATION

**Objective**: Verify complete system functionality

### 7.1. Service Health Checks

- [ ] Verify all containers are running and healthy
- [ ] Test inter-service communication
- [ ] Validate certificate-based authentication
- [ ] Confirm OIDC authentication flow

### 7.2. Federated Learning Workflow Test

- [ ] Test SuperNode registration with SuperLink
- [ ] Run sample FL training round
- [ ] Verify secure parameter exchange
- [ ] Validate monitoring and logging

## PHASE 8: PRODUCTION PREPARATION

**Objective**: Prepare for potential production deployment

### 8.1. Security Hardening

- [ ] Review container security configurations
- [ ] Implement secret management
- [ ] Set up backup and recovery procedures
- [ ] Configure logging and audit trails

### 8.2. Operational Readiness

- [ ] Create startup/shutdown scripts
- [ ] Set up monitoring and alerting
- [ ] Document operational procedures
- [ ] Prepare for scaling considerations

## KEY MODIFICATIONS FROM OPS MANUAL

### Certificate Management

- **OPS**: System-wide CA in `/usr/share/easy-rsa`
- **Your Setup**: Project-based CA in `./ca/` with volume mounts

### Service Deployment

- **OPS**: Systemd services on Ubuntu VMs
- **Your Setup**: Docker containers with compose orchestration

### Networking

- **OPS**: Physical/VPN network segmentation
- **Your Setup**: Docker network isolation with localhost access

### Storage

- **OPS**: System directories and volumes
- **Your Setup**: Docker volumes in project directory

This approach gives you a complete OPS manual-compliant infrastructure that runs entirely in Docker on your local machine, ready for development and testing.
