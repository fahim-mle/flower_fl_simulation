# National Infrastructure for Secure Federated Learning - Project Tasklist

Based on the FL_FLWR_OPS Operations Manual Version 1.0 (01/07/2025)

## Phase 1: Infrastructure Setup & Planning

### 1.1 Environment Setup

- [ ] Set up Test Environment in Nectar cluster
  - [ ] Configure server network segment
  - [ ] Deploy Jupyter Hub VM
  - [ ] Deploy Flower Superlink VM
  - [ ] Deploy VPN Server VM
  - [ ] Configure org network segment
  - [ ] Deploy Org Supernode VM
- [ ] Set up User Acceptance Test (UAT) Environment
  - [ ] Configure server network segment
  - [ ] Deploy Jupyter Hub VM
  - [ ] Deploy Flower Superlink VM
  - [ ] Deploy VPN Server VM
  - [ ] Configure org network segment
  - [ ] Deploy Org Supernode VM

### 1.2 Network Topology Planning

- [ ] Design network segmentation (Public, Internal, VPN)
- [ ] Plan IP address allocation for each segment
- [ ] Define firewall rules for each network boundary
- [ ] Document network protocols and ports required
- [ ] Plan VPN connectivity between Nectar and organizations

### 1.3 Security Framework Implementation

- [ ] Implement least trust security model
- [ ] Set up network segment firewalls
- [ ] Plan SSL/TLS certificate requirements
- [ ] Define mutual trust certificate framework
- [ ] Document security layers (Network, Transport, Application)

### 1.4 Certificate Authority Setup

- [ ] Install easy-rsa tools
- [ ] Configure organization-specific CA variables
- [ ] Initialize PKI infrastructure
- [ ] Build local Certificate Authority
- [ ] Create CA certificate distribution plan
- [ ] Set up CA certificate trust on all participating hosts

## Phase 2: Server-Side Deployment (Nectar Cloud)

### 2.1 Operating System Preparation

- [ ] Install Ubuntu 24.04 LTS on all server VMs
- [ ] Create fl_system group
- [ ] Create service user accounts (keycloak, superlink, jupyterhub)
- [ ] Add users to fl_system group
- [ ] Update system packages
- [ ] Configure system security settings

### 2.2 Local Certificate Authority Operations

- [ ] Generate server certificates for internal services
- [ ] Create certificates for: OpenVPN server, Superlink, Keycloak, JupyterHub
- [ ] Distribute certificates to appropriate servers
- [ ] Configure certificate trust relationships
- [ ] Set up certificate renewal procedures

### 2.3 VPN Server Deployment

- [ ] Install OpenVPN server
- [ ] Generate OpenVPN server certificates
- [ ] Configure server.conf with network settings
- [ ] Set up iptables IP masquerading
- [ ] Configure systemd service for automatic startup
- [ ] Set up Nectar security groups for UDP port 1194
- [ ] Test VPN server connectivity

### 2.4 Nginx Reverse Proxy Configuration

- [ ] Install Nginx
- [ ] Obtain public domain HTTPS certificates (Let's Encrypt)
- [ ] Configure reverse proxy for Keycloak
- [ ] Configure reverse proxy for JupyterHub
- [ ] Set up SSL termination
- [ ] Test reverse proxy functionality

### 2.5 PostgreSQL Database Setup

- [ ] Deploy PostgreSQL server in Nectar
- [ ] Create keycloak database owner account
- [ ] Create keycloak database and schema
- [ ] Configure database security (internal network only)
- [ ] Set up database backup procedures

### 2.6 Keycloak IAM Server Deployment

- [ ] Install OpenJDK 21 JRE/JDK
- [ ] Download and extract Keycloak 26.3.0
- [ ] Configure database connection
- [ ] Generate HTTPS certificates for Keycloak
- [ ] Configure Keycloak for reverse proxy
- [ ] Set up systemd service
- [ ] Create federated learning realm
- [ ] Configure OAuth client with device authentication
- [ ] Define realm roles (jupyter_admin, jupyter_user, superlink_user)
- [ ] Create user groups (jupyter_admins, jupyter_users)

### 2.7 JupyterHub Configuration with Docker

- [ ] Install Docker
- [ ] Create Python virtual environment for JupyterHub
- [ ] Install JupyterHub and dependencies
- [ ] Install configurable-http-proxy
- [ ] Configure OAuth authentication against Keycloak
- [ ] Set up DockerSpawner configuration
- [ ] Configure allowed Docker images
- [ ] Set up notebook directory mount points
- [ ] Configure pre_spawn_hook for directory creation
- [ ] Create systemd service for JupyterHub

### 2.8 Flower Superlink Deployment

- [ ] Create Python virtual environment for Flower
- [ ] Install Flower framework and dependencies
- [ ] Generate Superlink server certificates with custom SANs
- [ ] Create mutual trust certificates for SuperNodes
- [ ] Configure Superlink command line arguments
- [ ] Set up OIDC authentication (optional QCIF customization)
- [ ] Create systemd service for Superlink
- [ ] Test Superlink functionality

### 2.9 Systemd Service Configuration

- [ ] Create systemd unit for Keycloak
- [ ] Create systemd unit for JupyterHub
- [ ] Create systemd unit for Superlink
- [ ] Configure service dependencies and restart policies
- [ ] Test all services start automatically on boot

## Phase 3: Client-Side Deployment (Organization Premises)

### 3.1 VPN Client Configuration

- [ ] Install OpenVPN client
- [ ] Copy client certificates from VPN server
- [ ] Configure client.conf with server details
- [ ] Test VPN connectivity to Nectar
- [ ] Configure automatic startup on boot
- [ ] Verify network routing through VPN

### 3.2 Flower SuperNode Deployment

- [ ] Create Python virtual environment for Flower
- [ ] Install Flower framework and dependencies
- [ ] Install GPU drivers (NVIDIA 575) and CUDA 12
- [ ] Copy SuperNode certificates from CA
- [ ] Configure SuperNode settings (partition ID, total partitions)
- [ ] Test SuperNode connectivity to Superlink
- [ ] Create systemd service for SuperNode

### 3.3 Container Deployment Options

- [ ] Create Docker build files for CPU-only SuperNode
- [ ] Create Docker build files for GPU-enabled SuperNode
- [ ] Test container deployment with volume mounts
- [ ] Configure GPU pass-through for containers
- [ ] Document container deployment procedures

## Phase 4: Monitoring & Operations

### 4.1 Grafana Installation and Configuration

- [ ] Install Grafana server
- [ ] Create Grafana database in PostgreSQL
- [ ] Configure Grafana database connection
- [ ] Set up OAuth authentication against Keycloak
- [ ] Configure email alerting
- [ ] Install Grafana dashboards

### 4.2 Prometheus Setup and Node Exporter Deployment

- [ ] Install Prometheus server
- [ ] Configure Prometheus targets for all hosts
- [ ] Install Prometheus Node Exporter on all servers
- [ ] Configure custom ports if needed
- [ ] Set up data retention policies
- [ ] Test metric collection

### 4.3 GPU Monitoring with DCGM

- [ ] Install NVIDIA Data Center GPU Manager
- [ ] Build and install DCGM exporter
- [ ] Configure DCGM exporter systemd service
- [ ] Add GPU metrics to Prometheus configuration
- [ ] Import GPU monitoring dashboards to Grafana
- [ ] Test GPU metric collection

### 4.4 Alerting Configuration

- [ ] Configure CPU load alerts (>80% for 30min, >95% for 30min)
- [ ] Configure memory alerts (<10% for 30min, <5% for 30min)
- [ ] Configure disk space alerts (<30%, <20%, <10%)
- [ ] Configure service failure alerts for all key services
- [ ] Configure GPU temperature alerts (>85°C for 30min)
- [ ] Configure GPU memory utilization alerts (>90% for 1hr)
- [ ] Test alert delivery via email

### 4.5 Logging Setup and Management

- [ ] Configure systemd journal size limits
- [ ] Set up logrotate for file-based logs
- [ ] Configure log rotation for each service
- [ ] Test log collection and rotation
- [ ] Document log locations and access procedures

## Phase 5: Validation & Testing

### 5.1 Deployment Validation

- [ ] Clone QCIF test repository
- [ ] Update configuration for Superlink node
- [ ] Run end-to-end federated learning test
- [ ] Verify secure connectivity between components
- [ ] Test authentication and authorization flows
- [ ] Validate data isolation (no data leaves organization boundary)

### 5.2 Security Validation

- [ ] Test network segmentation and firewall rules
- [ ] Verify SSL/TLS certificate validity
- [ ] Test mutual authentication between Superlink and SuperNodes
- [ ] Validate VPN encryption and authentication
- [ ] Test user access controls and permissions

### 5.3 Performance Testing

- [ ] Test system under load with multiple users
- [ ] Validate GPU performance and utilization
- [ ] Test network latency and throughput
- [ ] Monitor resource utilization during training
- [ ] Document performance benchmarks

## Phase 6: Operational Procedures

### 6.1 Backup and Restore Procedures

- [ ] Implement configuration file backup to git repository
- [ ] Set up PostgreSQL database backup schedules
- [ ] Test database backup and restore procedures
- [ ] Document backup retention policies
- [ ] Create disaster recovery procedures

### 6.2 Diagnostic Procedures

- [ ] Document Grafana dashboard usage
- [ ] Create systemd status check procedures
- [ ] Document journalctl log analysis procedures
- [ ] Create file-based log analysis procedures
- [ ] Document Flower command line diagnostic tools

### 6.3 Maintenance Procedures

- [ ] Create certificate renewal procedures
- [ ] Document software update procedures
- [ ] Create system monitoring checklists
- [ ] Document user onboarding procedures
- [ ] Create troubleshooting guides

### 6.4 Documentation Updates

- [ ] Update this tasklist with actual implementation details
- [ ] Create user documentation for researchers
- [ ] Create operator documentation for support team
- [ ] Document network diagrams and architecture
- [ ] Create security procedures documentation

---

## Notes

- Each phase should be implemented in a separate git branch
- All procedures should be tested in the Test environment before UAT
- Security validations must be completed before production deployment
- All certificates and credentials must be stored securely
- Monitor system performance throughout implementation
