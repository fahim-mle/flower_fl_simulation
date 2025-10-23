# Phase 1: Infrastructure Setup & Planning

## Overview

This phase covers the initial setup and planning for the National Infrastructure for Secure Federated Learning deployment across Nectar Cloud and participating organizations.

## 1.1 Environment Setup

### Test Environment Configuration (Nectar Cloud)

#### Network Segments

- **Public Network**: Internet-facing services (Nginx reverse proxy)
- **Internal Network**: Backend services communication
- **VPN Network**: Secure connectivity to organizations

#### VM Specifications

| Service | VM Type | vCPUs | RAM | Storage | Network |
|---------|---------|-------|-----|---------|---------|
| Jupyter Hub | m3.large | 4 | 16GB | 100GB | Internal + VPN |
| Flower Superlink | m3.medium | 2 | 8GB | 50GB | Internal + VPN |
| VPN Server | m3.small | 2 | 4GB | 20GB | Public + Internal |
| PostgreSQL | m3.medium | 2 | 8GB | 100GB | Internal |
| Keycloak | m3.medium | 2 | 8GB | 20GB | Internal |
| Grafana | m3.small | 2 | 4GB | 20GB | Internal |
| Prometheus | m3.small | 2 | 4GB | 50GB | Internal |

#### Organization VM Specifications

| Service | VM Type | vCPUs | RAM | Storage | GPU | Network |
|---------|---------|-------|-----|---------|-----|---------|
| SuperNode (CPU) | m3.large | 4 | 16GB | 100GB | No | VPN |
| SuperNode (GPU) | g3.large | 8 | 32GB | 200GB | NVIDIA T4 | VPN |

## 1.2 Network Topology Planning

### IP Address Allocation

#### Nectar Internal Network (10.0.1.0/24)

- 10.0.1.10 - Nginx Reverse Proxy
- 10.0.1.20 - Keycloak Server
- 10.0.1.30 - PostgreSQL Server
- 10.0.1.40 - JupyterHub Server
- 10.0.1.50 - Flower Superlink
- 10.0.1.60 - Grafana Server
- 10.0.1.70 - Prometheus Server
- 10.0.1.80 - VPN Server (internal interface)

#### VPN Network (10.10.0.0/24)

- 10.10.0.1 - VPN Server
- 10.10.0.10-50 - Organization SuperNodes

### Firewall Rules

#### Public Network Security Group

- Inbound:
  - TCP 80, 443: HTTP/HTTPS (Nginx)
  - UDP 1194: OpenVPN
- Outbound: All traffic allowed

#### Internal Network Security Group

- Inbound: Only from Internal Network and VPN Network
- Outbound: All traffic allowed

#### VPN Network Security Group

- Inbound: Only from VPN clients
- Outbound: To Internal Network only

### Required Ports and Protocols

| Service | Port | Protocol | Direction | Source |
|---------|------|----------|-----------|---------|
| Nginx | 80, 443 | TCP | Inbound | Internet |
| OpenVPN | 1194 | UDP | Inbound | Internet |
| PostgreSQL | 5432 | TCP | Inbound | Internal Network |
| Keycloak | 8080 | TCP | Inbound | Internal Network |
| JupyterHub | 8000 | TCP | Inbound | Internal Network |
| Superlink | 9091, 9092 | TCP | Inbound | Internal + VPN |
| Grafana | 3000 | TCP | Inbound | Internal Network |
| Prometheus | 9090 | TCP | Inbound | Internal Network |
| Node Exporter | 9100 | TCP | Inbound | Internal Network |

## 1.3 Security Framework Implementation

### Network Layer Security

- Network segmentation using Nectar security groups
- Firewall rules restricting traffic between segments
- VPN encryption for organization connectivity

### Transport Layer Security

- SSL/TLS certificates for all services
- Mutual authentication between Superlink and SuperNodes
- Certificate-based client authentication for VPN

### Application Layer Security

- OAuth/OIDC authentication via Keycloak
- Role-based access control (RBAC)
- Service-to-service authentication

### Certificate Authority Structure

```
National FL CA
├── Server Certificates
│   ├── VPN Server
│   ├── Superlink
│   ├── Keycloak
│   ├── JupyterHub
│   └── Internal Services
└── Client Certificates
    ├── Organization SuperNodes
    └── VPN Clients
```

## 1.4 Certificate Authority Setup

### easy-rsa Configuration

- Organization-specific CA variables
- Certificate lifecycle management
- Revocation procedures
- Distribution mechanisms

### Certificate Requirements

- Server certificates with appropriate SANs
- Client certificates for mutual authentication
- CA certificate distribution to all hosts
- Certificate renewal automation

## Implementation Steps

### Step 1: Nectar Environment Setup

1. Create Nectar project and security groups
2. Deploy VM instances with specified configurations
3. Configure network segments and routing
4. Set up DNS entries for public services

### Step 2: Certificate Authority Setup

1. Install easy-rsa on CA management host
2. Configure organization-specific CA parameters
3. Generate root CA certificate
4. Create server and client certificates
5. Distribute certificates to appropriate hosts

### Step 3: Network Configuration

1. Configure security groups and firewall rules
2. Set up internal DNS resolution
3. Configure routing between network segments
4. Test network connectivity

### Step 4: Security Validation

1. Verify network segmentation
2. Test certificate validity
3. Validate firewall rules
4. Document security procedures

## Next Steps

After completing Phase 1:

1. Proceed to Phase 2: Server-Side Deployment
2. Begin with operating system preparation
3. Continue with certificate deployment
4. Deploy core services sequentially

## Dependencies

- Nectar Cloud access and quotas
- Domain name configuration for public services
- Organization network connectivity requirements
- Security policy approvals

## Risk Mitigation

- Test all procedures in development environment first
- Implement backup and recovery procedures
- Document all configurations and procedures
- Establish monitoring and alerting early

## Success Criteria

- All VM instances deployed and accessible
- Network segmentation functioning correctly
- Certificate authority operational
- Security controls validated
- Documentation complete and approved
