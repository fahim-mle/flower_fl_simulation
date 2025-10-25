# Phase 1 Scripts - Quick Reference Card

## One-Line Commands

### Generate All Certificates (Recommended)
```bash
cd /home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/scripts
./generate_all_certs.sh
```

### Force Regenerate All Certificates
```bash
./generate_all_certs.sh --force
```

### Verify All Certificates
```bash
./verify_certificates.sh
```

### Validate Phase 1 Completion
```bash
./validate_phase1.sh
```

### Generate Individual Certificate
```bash
./generate_service_cert.sh <service> "<SANs>"
```

---

## Service-Specific Commands

### SuperLink
```bash
./generate_service_cert.sh superlink "DNS:superlink,DNS:superlink.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.10"
```

### PostgreSQL
```bash
./generate_service_cert.sh postgres "DNS:postgres,DNS:postgres.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.5"
```

### Keycloak
```bash
./generate_service_cert.sh keycloak "DNS:keycloak,DNS:keycloak.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.6"
```

### JupyterHub
```bash
./generate_service_cert.sh jupyterhub "DNS:jupyterhub,DNS:jupyterhub.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.7"
```

### Nginx
```bash
./generate_service_cert.sh nginx "DNS:nginx,DNS:nginx.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.4"
```

### SuperNode-1
```bash
./generate_service_cert.sh supernode-1 "DNS:supernode-1,DNS:supernode-1.fl-lab.local,IP:172.21.0.10"
```

### SuperNode-2
```bash
./generate_service_cert.sh supernode-2 "DNS:supernode-2,DNS:supernode-2.fl-lab.local,IP:172.21.0.11"
```

### SuperNode-3
```bash
./generate_service_cert.sh supernode-3 "DNS:supernode-3,DNS:supernode-3.fl-lab.local,IP:172.21.0.12"
```

### SuperNode-4
```bash
./generate_service_cert.sh supernode-4 "DNS:supernode-4,DNS:supernode-4.fl-lab.local,IP:172.21.0.13"
```

### SuperNode-5
```bash
./generate_service_cert.sh supernode-5 "DNS:supernode-5,DNS:supernode-5.fl-lab.local,IP:172.21.0.14"
```

---

## Useful OpenSSL Commands

### View Certificate Details
```bash
openssl x509 -in <cert>.crt -text -noout
```

### Check Certificate Expiry
```bash
openssl x509 -in <cert>.crt -noout -dates
```

### View Subject Alternative Names
```bash
openssl x509 -in <cert>.crt -noout -text | grep -A1 "Subject Alternative Name"
```

### Verify Certificate Chain
```bash
openssl verify -CAfile ca.crt <service>.crt
```

### Check Private Key
```bash
openssl rsa -in <key>.key -check -noout
```

### Verify Key Matches Certificate
```bash
openssl x509 -noout -modulus -in <cert>.crt | openssl md5
openssl rsa -noout -modulus -in <key>.key | openssl md5
# Both outputs should match
```

---

## Network Reference

| Service | IP Address | Network | SANs |
|---------|-----------|---------|------|
| SuperLink | 172.20.0.10 | fl-services | DNS:superlink, DNS:superlink.fl-lab.local, localhost |
| PostgreSQL | 172.20.0.5 | fl-services | DNS:postgres, DNS:postgres.fl-lab.local, localhost |
| Keycloak | 172.20.0.6 | fl-services | DNS:keycloak, DNS:keycloak.fl-lab.local, localhost |
| JupyterHub | 172.20.0.7 | fl-services | DNS:jupyterhub, DNS:jupyterhub.fl-lab.local, localhost |
| Nginx | 172.20.0.4 | fl-services | DNS:nginx, DNS:nginx.fl-lab.local, localhost |
| SuperNode-1 | 172.21.0.10 | fl-clients | DNS:supernode-1, DNS:supernode-1.fl-lab.local |
| SuperNode-2 | 172.21.0.11 | fl-clients | DNS:supernode-2, DNS:supernode-2.fl-lab.local |
| SuperNode-3 | 172.21.0.12 | fl-clients | DNS:supernode-3, DNS:supernode-3.fl-lab.local |
| SuperNode-4 | 172.21.0.13 | fl-clients | DNS:supernode-4, DNS:supernode-4.fl-lab.local |
| SuperNode-5 | 172.21.0.14 | fl-clients | DNS:supernode-5, DNS:supernode-5.fl-lab.local |

---

## Troubleshooting One-Liners

### Check All Certificate Files Exist
```bash
for svc in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
  ls -l ../volumes/certificates/$svc/ 2>/dev/null || echo "Missing: $svc"
done
```

### Check All Certificate Expiry Dates
```bash
for svc in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
  echo "$svc: $(openssl x509 -in ../volumes/certificates/$svc/$svc.crt -noout -enddate 2>/dev/null)"
done
```

### Check All Key Permissions
```bash
for svc in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
  stat -c "%n: %a" ../volumes/certificates/$svc/$svc.key 2>/dev/null || echo "$svc: missing"
done
```

### Verify All Certificate Chains
```bash
for svc in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
  openssl verify -CAfile ../volumes/certificates/$svc/ca.crt ../volumes/certificates/$svc/$svc.crt 2>&1 | grep -q OK && echo "$svc: OK" || echo "$svc: FAIL"
done
```

---

## Common Workflows

### Initial Setup (First Time)
```bash
# 1. Install prerequisites
sudo apt-get update && sudo apt-get install -y easy-rsa openssl

# 2. Initialize CA (if not done)
cd ../ca
cp -r /usr/share/easy-rsa/* .
./easyrsa init-pki

# 3. Configure CA vars
nano pki/vars  # Add organization details

# 4. Build CA
./easyrsa build-ca nopass

# 5. Generate all certificates
cd ../scripts
./generate_all_certs.sh

# 6. Validate Phase 1
./validate_phase1.sh
```

### Regenerate Single Certificate
```bash
# Interactive mode
./generate_service_cert.sh <service> "<SANs>"

# Or use generate_all_certs.sh for specific services
# (modify the script to comment out unwanted services)
```

### Check Phase 1 Status
```bash
# Quick check
./verify_certificates.sh

# Comprehensive validation with report
./validate_phase1.sh --report phase1_status.md
```

### Certificate Rotation (Before Expiry)
```bash
# 1. Backup current certificates
cp -r ../volumes/certificates ../volumes/certificates.backup.$(date +%Y%m%d)

# 2. Regenerate all (force mode)
./generate_all_certs.sh --force

# 3. Verify
./verify_certificates.sh

# 4. Restart affected services (Phase 2)
```

---

## File Locations

### Scripts
```
/home/ghost/workspace/internship_project/flower_fl_simulation/flower_secure_simulation/scripts/
├── generate_service_cert.sh    # Individual cert generation
├── verify_certificates.sh      # Certificate verification
├── generate_all_certs.sh       # Batch generation
├── validate_phase1.sh          # Phase 1 validation
├── README.md                   # Full documentation
└── QUICK_REFERENCE.md          # This file
```

### Certificates (CA)
```
../ca/pki/
├── ca.crt                      # Root CA certificate
├── private/ca.key              # CA private key (SECURE!)
├── issued/*.crt                # All service certificates
└── private/*.key               # All service private keys
```

### Certificates (Volumes)
```
../volumes/certificates/
└── <service>/
    ├── ca.crt                  # CA certificate (644)
    ├── <service>.crt           # Service certificate (644)
    └── <service>.key           # Private key (600)
```

---

## Quick Diagnostics

### Is CA Initialized?
```bash
[ -f ../ca/pki/ca.crt ] && echo "CA OK" || echo "CA NOT INITIALIZED"
```

### How Many Certificates Generated?
```bash
ls ../volumes/certificates/*/ca.crt 2>/dev/null | wc -l
# Should be 10
```

### Any Certificates Expiring Soon?
```bash
for svc in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
  cert="../volumes/certificates/$svc/$svc.crt"
  [ -f "$cert" ] && openssl x509 -in "$cert" -noout -checkend $((90*86400)) || echo "$svc expires < 90 days"
done
```

### All Scripts Executable?
```bash
ls -l *.sh | grep -v "rwx" && echo "Some scripts not executable" || echo "All scripts executable"
```

---

## Exit Codes Reference

| Script | Success | Failure | Warnings |
|--------|---------|---------|----------|
| generate_service_cert.sh | 0 | 1 | N/A |
| verify_certificates.sh | 0 | 1 | Warnings in output |
| generate_all_certs.sh | 0 | 1 | N/A |
| validate_phase1.sh | 0 | 1 | Shows in report |

---

## Script Options Summary

### generate_service_cert.sh
- `-h, --help` - Show help

### generate_all_certs.sh
- `-h, --help` - Show help
- `--skip-verification` - Skip verification after generation
- `--force` - Force regeneration without prompts

### verify_certificates.sh
- No options (runs automatically)

### validate_phase1.sh
- `-h, --help` - Show help
- `--report <file>` - Generate markdown report
- `--no-report` - Skip report generation

---

**Last Updated**: 2025-10-25
**For Full Documentation**: See `README.md`
