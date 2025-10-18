# Flower FL Certificate Management

This directory contains all TLS/SSL certificates for the Flower Federated Learning infrastructure.

## Directory Structure

```
certificates/
├── ca/                    # Certificate Authority
│   ├── ca.crt            # CA public certificate (safe to commit)
│   ├── ca.key            # CA private key (NEVER COMMIT)
│   └── ca.srl            # Serial number tracker
│
├── server/               # SuperLink server certificates
│   ├── server.crt        # Server certificate
│   ├── server.csr        # Certificate signing request
│   ├── server.key        # Server private key (NEVER COMMIT)
│   └── server.conf       # OpenSSL configuration
│
├── clients/              # SuperNode client certificates
│   ├── client1.crt       # Client 1 certificate
│   ├── client1.csr       # Client 1 CSR
│   ├── client1.key       # Client 1 private key (NEVER COMMIT)
│   ├── client2.crt       # Client 2 certificate
│   ├── client2.csr       # Client 2 CSR
│   └── client2.key       # Client 2 private key (NEVER COMMIT)
│
└── .gitignore            # Protects private keys from being committed
```

## Certificate Details

### Certificate Authority (CA)
- **Type:** RSA 4096-bit self-signed
- **Validity:** 10 years (3650 days)
- **Organization:** QCIF - Federated Learning
- **Common Name:** Flower FL Root CA
- **Purpose:** Sign all server and client certificates

### Server Certificate (SuperLink)
- **Type:** RSA 4096-bit
- **Validity:** 1 year (365 days)
- **Common Name:** superlink.fl.local
- **Subject Alternative Names (SAN):**
  - DNS: superlink.fl.local
  - DNS: superlink
  - DNS: localhost
  - IP: ::1
  - IP: 127.0.0.1
  - IP: 0.0.0.0
- **Purpose:** TLS encryption for SuperLink server

### Client Certificates (SuperNodes)
- **Type:** RSA 2048-bit
- **Validity:** 1 year (365 days)
- **Common Names:**
  - supernode-1.fl.local (client1)
  - supernode-2.fl.local (client2)
- **Purpose:** Client authentication (mTLS)

## Certificate Generation

### Generate All Certificates

Run these scripts in order:

```bash
# 1. Generate Certificate Authority
./scripts/setup/generate_ca.sh

# 2. Generate server certificate
./scripts/setup/generate_server_cert.sh

# 3. Generate client certificates
./scripts/setup/generate_client_cert.sh 1
./scripts/setup/generate_client_cert.sh 2
```

### Add Additional Client Certificates

```bash
# Generate certificate for SuperNode N
./scripts/setup/generate_client_cert.sh N
```

## Certificate Verification

### Verify Certificate Chain

```bash
# Verify CA certificate
openssl x509 -in ca/ca.crt -text -noout

# Verify server certificate is signed by CA
openssl verify -CAfile ca/ca.crt server/server.crt

# Verify client certificate is signed by CA
openssl verify -CAfile ca/ca.crt clients/client1.crt
```

### Check Certificate Expiration

```bash
# Check CA expiration
openssl x509 -in ca/ca.crt -noout -enddate

# Check server certificate expiration
openssl x509 -in server/server.crt -noout -enddate

# Check client certificate expiration
openssl x509 -in clients/client1.crt -noout -enddate
```

### Verify Subject Alternative Names (SAN)

```bash
# Check SAN entries in server certificate
openssl x509 -in server/server.crt -text -noout | grep -A 5 "Subject Alternative Name"
```

## Certificate Rotation

Certificates should be rotated before they expire. Set calendar reminders 30 days before expiration.

### Rotate Server Certificate

```bash
# 1. Backup current certificate
cp server/server.crt server/server.crt.backup
cp server/server.key server/server.key.backup

# 2. Generate new server certificate
./scripts/setup/generate_server_cert.sh

# 3. Update file permissions
chmod 644 server/server.key

# 4. Restart SuperLink
docker compose -f docker-compose.tls.yml restart superlink
```

### Rotate Client Certificate

```bash
# 1. Backup current certificate
cp clients/client1.crt clients/client1.crt.backup
cp clients/client1.key clients/client1.key.backup

# 2. Generate new client certificate
./scripts/setup/generate_client_cert.sh 1

# 3. Update file permissions
chmod 644 clients/client1.key

# 4. Restart SuperNode
docker compose -f docker-compose.tls.yml restart supernode-0
```

## Security Best Practices

### Private Key Protection

1. **Never commit private keys to version control**
   - All `.key` files are in `.gitignore`
   - Verify: `git check-ignore *.key`

2. **Secure file permissions** (for production)
   - CA key: `chmod 400 ca/ca.key`
   - Server key: `chmod 400 server/server.key`
   - Client keys: `chmod 400 clients/*.key`

   Note: For Docker development, keys are set to `644` to allow container access.

3. **Store CA key offline**
   - After initial setup, move CA key to secure offline storage
   - Only needed for signing new certificates

### Certificate Distribution

- Distribute client certificates via secure channels (encrypted email, VPN, etc.)
- Never share private keys over unsecured channels
- Document which organization received which client certificate

### Monitoring and Alerts

Set up monitoring for:
- Certificate expiration (alert 30 days before)
- Failed TLS handshakes
- Unauthorized connection attempts
- Certificate revocation events

## Troubleshooting

### Common Issues

#### 1. "Permission denied" on private keys

```bash
# For Docker containers, set readable permissions
chmod 644 server/server.key
```

#### 2. "No match found for server name"

Ensure the server certificate includes the correct SAN entries for the hostname used in Docker Compose:

```bash
openssl x509 -in server/server.crt -text -noout | grep -A 5 "Subject Alternative Name"
# Should include: DNS:superlink
```

#### 3. "Certificate verification failed"

Check the certificate chain:

```bash
openssl verify -CAfile ca/ca.crt server/server.crt
openssl verify -CAfile ca/ca.crt clients/client1.crt
```

#### 4. "Certificate expired"

Generate new certificates:

```bash
# Check expiration
openssl x509 -in server/server.crt -noout -enddate

# Regenerate if expired
./scripts/setup/generate_server_cert.sh
```

## References

- [Flower TLS Documentation](https://flower.ai/docs/framework/how-to-enable-tls-connections.html)
- [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/)
- [X.509 Certificate Standards (RFC 5280)](https://www.rfc-editor.org/rfc/rfc5280)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

## Certificate Inventory

Last generated: 2025-10-18

| Certificate | Type | Expires | Status |
|------------|------|---------|--------|
| CA | Root CA | 2035-10-16 | Active |
| server.crt | Server | 2026-10-18 | Active |
| client1.crt | Client | 2026-10-18 | Active |
| client2.crt | Client | 2026-10-18 | Active |

Set calendar reminder for: **2026-09-18** (30 days before server cert expiration)
