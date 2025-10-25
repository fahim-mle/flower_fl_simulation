# Phase 1 Automation Scripts

This directory contains automation scripts for Phase 1 of the Federated Learning PKI infrastructure setup.

## Overview

These scripts automate the certificate generation and validation process for all FL services, ensuring a secure mTLS-enabled infrastructure.

## Scripts

### 1. `generate_service_cert.sh`

**Purpose**: Generate individual service certificates with Subject Alternative Names (SANs)

**Usage**:
```bash
./generate_service_cert.sh <service-name> <san-entries>
```

**Examples**:
```bash
# Generate certificate for SuperLink
./generate_service_cert.sh superlink "DNS:superlink,DNS:superlink.fl-lab.local,IP:127.0.0.1,IP:172.20.0.10"

# Generate certificate for PostgreSQL
./generate_service_cert.sh postgres "DNS:postgres,DNS:postgres.fl-lab.local,IP:127.0.0.1,IP:172.20.0.5"
```

**Features**:
- Comprehensive input validation
- Automatic prerequisite checking (CA existence, directories)
- Support for certificate regeneration with revocation
- Automatic file permission setting (644 for certs, 600 for keys)
- Certificate verification after generation
- Colored output for better readability
- Detailed error messages and logging

**Output Files** (per service):
- `../volumes/certificates/<service>/<service>.crt` - Service certificate
- `../volumes/certificates/<service>/<service>.key` - Private key (600 permissions)
- `../volumes/certificates/<service>/ca.crt` - CA certificate

---

### 2. `verify_certificates.sh`

**Purpose**: Comprehensive verification of all service certificates

**Usage**:
```bash
./verify_certificates.sh
```

**Checks Performed**:
- Certificate file existence
- Private key file existence
- CA certificate existence
- Certificate expiry dates (warns if < 90 days)
- Subject Alternative Names (SANs) presence
- Certificate chain validity
- File permissions (644 for certs, 600 for keys)
- Private key matches certificate
- CA certificate validity

**Services Verified**:
1. SuperLink
2. PostgreSQL
3. Keycloak
4. JupyterHub
5. Nginx
6. SuperNode-1 through SuperNode-5 (5 client nodes)

**Exit Codes**:
- `0` - All certificates valid
- `1` - One or more certificates invalid or missing

**Output**: Detailed report with ✓/✗/⚠ symbols for each check

---

### 3. `generate_all_certs.sh`

**Purpose**: Batch generation of all service certificates

**Usage**:
```bash
./generate_all_certs.sh [OPTIONS]
```

**Options**:
- `--skip-verification` - Skip certificate verification at the end
- `--force` - Force regeneration without prompts (auto-answers "yes")
- `-h, --help` - Show help message

**Examples**:
```bash
# Interactive mode - generate all certificates with prompts
./generate_all_certs.sh

# Force mode - regenerate all without prompts
./generate_all_certs.sh --force

# Generate without verification
./generate_all_certs.sh --skip-verification
```

**Certificate Generation Order**:

**Phase 1: Core Infrastructure Services**
1. SuperLink (FL coordination service) - `172.20.0.10`
2. PostgreSQL (database backend) - `172.20.0.5`
3. Keycloak (identity management) - `172.20.0.6`
4. JupyterHub (user interface) - `172.20.0.7`
5. Nginx (reverse proxy) - `172.20.0.4`

**Phase 2: SuperNode Client Certificates**
6. SuperNode-1 (Organization 1) - `172.21.0.10`
7. SuperNode-2 (Organization 2) - `172.21.0.11`
8. SuperNode-3 (Organization 3) - `172.21.0.12`
9. SuperNode-4 (Organization 4) - `172.21.0.13`
10. SuperNode-5 (Organization 5) - `172.21.0.14`

**Features**:
- Progress tracking with counters
- Automatic prerequisite validation
- Interactive confirmation (unless `--force` is used)
- Automatic verification after generation (unless `--skip-verification`)
- Error logging to `/tmp/cert_gen_<service>.log` in force mode
- Execution time tracking
- Comprehensive summary report

---

### 4. `validate_phase1.sh`

**Purpose**: Comprehensive Phase 1 validation with optional markdown report

**Usage**:
```bash
./validate_phase1.sh [OPTIONS]
```

**Options**:
- `--report <filename>` - Generate markdown report (default: `phase1_validation_report.md`)
- `--no-report` - Don't generate a report file
- `-h, --help` - Show help message

**Examples**:
```bash
# Validate and generate default report
./validate_phase1.sh

# Validate without report
./validate_phase1.sh --no-report

# Custom report filename
./validate_phase1.sh --report custom_report.md
```

**Validation Sections**:

#### Section 1.1: Project Structure Setup
- Root directories (ca, config, volumes, docker, scripts, logs)
- CA subdirectories (pki)
- Volume directories for all services
- Certificate volume directories for all services
- Configuration directories (nginx, keycloak, jupyterhub, etc.)
- Network definitions (optional check)

#### Section 1.2: Certificate Authority Setup
- easy-rsa installation (system and local)
- PKI initialization
- CA variables configuration
- Root CA certificate generation and validity
- CA private key security (600 permissions)
- CA certificate distribution to service volumes

#### Section 1.3: Service Certificate Generation
- Certificate generation script existence
- Certificate verification script existence
- Individual service certificate validation for all 10 services
- Certificate expiry checking
- SAN presence verification
- Certificate chain validation
- File permission verification

**Exit Codes**:
- `0` - Phase 1 complete and validated
- `1` - Phase 1 incomplete or validation failed

**Output**:
- Console output with colored status indicators
- Optional markdown report with comprehensive results
- Summary statistics (total checks, passed, failed, warnings)

---

## Quick Start Guide

### Initial Setup

1. **Ensure Prerequisites**:
   ```bash
   # Install easy-rsa if not already installed
   sudo apt-get update
   sudo apt-get install -y easy-rsa openssl
   ```

2. **Initialize Certificate Authority**:
   ```bash
   cd ../ca
   cp -r /usr/share/easy-rsa/* .
   ./easyrsa init-pki

   # Create vars file (see phase1_implementation_plan.md)
   nano pki/vars

   # Build CA
   ./easyrsa build-ca nopass
   ```

3. **Generate All Certificates**:
   ```bash
   cd ../scripts
   ./generate_all_certs.sh
   ```

4. **Validate Phase 1**:
   ```bash
   ./validate_phase1.sh
   ```

### Individual Certificate Generation

If you need to generate or regenerate a specific certificate:

```bash
./generate_service_cert.sh <service> "<SANs>"
```

### Verification Only

To verify existing certificates without regeneration:

```bash
./verify_certificates.sh
```

---

## Network Configuration Reference

### IP Ranges
- **FL Services Network**: `172.20.0.0/16` - Main services
- **FL Clients Network**: `172.21.0.0/16` - SuperNode clients
- **FL Monitoring Network**: `172.22.0.0/16` - Monitoring stack

### Service-Specific SANs

All certificates include:
- Docker service name (e.g., `DNS:superlink`)
- Full domain name (e.g., `DNS:superlink.fl-lab.local`)
- Localhost access (for core services)
- Static IP address(es)

**SuperLink**:
```
DNS:superlink,DNS:superlink.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.10
```

**PostgreSQL**:
```
DNS:postgres,DNS:postgres.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.5
```

**Keycloak**:
```
DNS:keycloak,DNS:keycloak.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.6
```

**JupyterHub**:
```
DNS:jupyterhub,DNS:jupyterhub.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.7
```

**Nginx**:
```
DNS:nginx,DNS:nginx.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.4
```

**SuperNode-1**:
```
DNS:supernode-1,DNS:supernode-1.fl-lab.local,IP:172.21.0.10
```

**SuperNode-2 through SuperNode-5**:
Similar pattern with incrementing IP addresses (172.21.0.11 through 172.21.0.14)

---

## File Structure

After running all scripts, the directory structure will be:

```
flower_secure_simulation/
├── ca/
│   ├── easyrsa
│   └── pki/
│       ├── ca.crt                    # Root CA certificate
│       ├── private/
│       │   ├── ca.key               # CA private key (600 permissions)
│       │   ├── superlink.key
│       │   ├── postgres.key
│       │   └── ...
│       └── issued/
│           ├── superlink.crt
│           ├── postgres.crt
│           └── ...
├── volumes/
│   └── certificates/
│       ├── superlink/
│       │   ├── ca.crt
│       │   ├── superlink.crt        # 644 permissions
│       │   └── superlink.key        # 600 permissions
│       ├── postgres/
│       │   ├── ca.crt
│       │   ├── postgres.crt
│       │   └── postgres.key
│       └── ... (8 more services)
└── scripts/
    ├── generate_service_cert.sh
    ├── verify_certificates.sh
    ├── generate_all_certs.sh
    ├── validate_phase1.sh
    └── README.md (this file)
```

---

## Security Considerations

### File Permissions

Scripts automatically set correct permissions:
- **Certificates (`.crt`)**: `644` (readable by all, writable by owner)
- **Private Keys (`.key`)**: `600` (readable/writable by owner only)
- **CA Private Key**: `600` (NEVER share this file)

### Certificate Expiry

- **CA Certificate**: Valid for 10 years (3650 days)
- **Service Certificates**: Valid for 825 days (~2.3 years)
- Scripts warn if certificates expire within 90 days
- Scripts fail if certificates expire within 30 days

### Best Practices

1. **Never commit private keys to version control**
   - Add `ca/pki/private/` to `.gitignore`
   - Add `volumes/certificates/*/*.key` to `.gitignore`

2. **Secure CA private key**
   - Keep `ca/pki/private/ca.key` with 600 permissions
   - Back up securely in encrypted storage
   - Never transmit over insecure channels

3. **Regular certificate rotation**
   - Monitor certificate expiry dates
   - Rotate certificates well before expiration
   - Use `verify_certificates.sh` for monitoring

4. **Certificate revocation**
   - Use `./easyrsa revoke <service-name>` if compromised
   - Regenerate certificates using `generate_service_cert.sh`

5. **Backup strategy**
   - Regularly backup `ca/pki/` directory
   - Store backups in secure, encrypted location
   - Test restore procedures periodically

---

## Troubleshooting

### Issue: "CA certificate not found"

**Solution**:
```bash
cd ../ca
./easyrsa build-ca nopass
```

### Issue: "Permission denied" when generating certificates

**Solution**:
```bash
# Ensure scripts are executable
chmod +x *.sh

# Check CA private key permissions
chmod 600 ../ca/pki/private/ca.key
```

### Issue: Certificate already exists

**Solution**:
The script will prompt to regenerate. Choose "yes" to revoke and regenerate, or use `--force` flag with `generate_all_certs.sh`.

### Issue: Certificate verification fails

**Possible causes and solutions**:

1. **Expired certificate**: Regenerate using `generate_service_cert.sh`
2. **Invalid SAN entries**: Check SAN format in certificate using:
   ```bash
   openssl x509 -in <cert>.crt -noout -text | grep -A1 "Subject Alternative Name"
   ```
3. **Chain validation failure**: Ensure CA certificate is not expired/corrupted

### Issue: Scripts can't find easy-rsa

**Solution**:
```bash
# Install easy-rsa
sudo apt-get install easy-rsa

# Copy to project CA directory
cd ../ca
cp -r /usr/share/easy-rsa/* .
```

---

## Script Enhancement Ideas

The scripts include several enhancements beyond the basic requirements:

1. **Error Handling**: Comprehensive error checking with `set -euo pipefail`
2. **Colored Output**: Visual distinction for success/error/warning messages
3. **Input Validation**: Validates service names and SAN format
4. **Prerequisites Checking**: Verifies all dependencies before execution
5. **Progress Tracking**: Shows current progress for batch operations
6. **Detailed Logging**: Error logs in force mode for debugging
7. **Certificate Details**: Displays subject, issuer, expiry, and SANs
8. **Permission Management**: Automatic permission setting for security
9. **Interactive Mode**: User confirmation before destructive operations
10. **Report Generation**: Markdown reports for documentation
11. **Chain Verification**: Validates certificate chains against CA
12. **Execution Timing**: Tracks and displays execution time
13. **Help Documentation**: Comprehensive help messages with examples
14. **Syntax Validation**: Bash syntax checking capability

---

## References

- **Implementation Plan**: `../implementation_guide/phase1_implementation_plan.md`
- **OPS Manual Section 4.1.2.2**: Local Certificate Authority setup
- **OPS Manual Section 4.1.1**: Directory Structure conventions
- **OPS Manual Section 3.3.1**: Network Protocols and Ports

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the implementation plan: `phase1_implementation_plan.md`
3. Run validation script: `./validate_phase1.sh`
4. Check script logs in `/tmp/cert_gen_<service>.log` (force mode)

---

**Script Version**: 1.0.0
**Last Updated**: 2025-10-25
**Compatibility**: Ubuntu 24.04 LTS, bash 5.x, OpenSSL 3.x, easy-rsa 3.x
