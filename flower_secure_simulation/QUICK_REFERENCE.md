# Quick Reference - Federated Learning Infrastructure

## Key File Locations

### Certificate Authority

- **Root CA Certificate**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/ca/pki/ca.crt`
- **CA Private Key**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/ca/pki/private/ca.key` (SECRET - 600 permissions)
- **CA Configuration**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/ca/pki/vars`

### Documentation

- **Project Structure**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/PROJECT_STRUCTURE.md`
- **Completion Report**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/PHASE1_COMPLETION_REPORT.md`
- **Implementation Plan**: `/home/ghost/workspace/internship_project/flower_fl_simulation/implementation_guide/phase1_implementation_plan.md`

### Docker Configuration

- **Network Definitions**: `/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/docker/networks.yml`

## CA Certificate Details

**Common Name**: Federated Learning Root CA
**Fingerprint (SHA-256)**: B6:8D:7D:A4:4A:28:52:BF:D8:43:85:9E:DB:4D:33:DD:D9:F1:8C:2D:70:08:47:64:61:06:34:0E:9A:EA:57:FF
**Key Size**: 4096 bits
**Signature Algorithm**: sha512WithRSAEncryption
**Valid From**: Oct 25 08:15:23 2025 GMT
**Valid Until**: Oct 23 08:15:23 2035 GMT

## Network Configuration

| Network Name | Subnet | Gateway | Purpose |
|--------------|--------|---------|---------|
| fl-services-network | 172.20.0.0/16 | 172.20.0.1 | Services |
| fl-clients-network | 172.21.0.0/16 | 172.21.0.1 | SuperNodes |
| fl-monitoring-network | 172.22.0.0/16 | 172.22.0.1 | Monitoring |

## IP Allocations

### Services (172.20.0.x)

- 172.20.0.4 - Nginx
- 172.20.0.5 - PostgreSQL
- 172.20.0.6 - Keycloak
- 172.20.0.7 - JupyterHub
- 172.20.0.10 - SuperLink

### SuperNodes (172.21.0.x)

- 172.21.0.10 - SuperNode-1 (Organization 1)
- 172.21.0.11 - SuperNode-2 (Organization 2)
- 172.21.0.12 - SuperNode-3 (Organization 3)
- 172.21.0.13 - SuperNode-4 (Organization 4)
- 172.21.0.14 - SuperNode-5 (Organization 5)

### Monitoring (172.22.0.x)

- 172.22.0.10 - Prometheus
- 172.22.0.11 - Grafana

## Common Commands

### View CA Certificate

```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation
openssl x509 -in ca/pki/ca.crt -noout -text
```

### Generate Service Certificate (Phase 1.3)

```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation
./scripts/generate_service_cert.sh <service-name> "<SAN-entries>"
```

### Verify Certificate

```bash
openssl verify -CAfile ca/pki/ca.crt <certificate-file>
```

### Check Certificate Expiration

```bash
openssl x509 -in <certificate-file> -noout -dates
```

## Security Checklist

- [ ] CA private key has 600 permissions
- [ ] CA private key is NOT in version control
- [ ] CA certificate distributed to all services
- [ ] Encrypted backup of CA private key created
- [ ] Certificate expiration monitoring configured
- [ ] All private keys excluded from git

## Phase Status

- [x] Phase 1.1 - Project Structure Setup
- [x] Phase 1.2 - Certificate Authority Setup
- [ ] Phase 1.3 - Service Certificate Generation
- [ ] Phase 2 - Docker Network Configuration
- [ ] Phase 3 - Service Deployment

## Support Contacts

**Organization**: Federated Learning Lab
**Email**: <admin@fl-lab.local>
**Location**: Brisbane, Queensland, Australia

## Next Actions

1. Execute Phase 1.3 to generate service certificates
2. Create docker-compose.yml for service orchestration
3. Configure service-specific settings
4. Deploy and test infrastructure
