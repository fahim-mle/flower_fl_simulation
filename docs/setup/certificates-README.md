# Certificates Directory

This directory contains TLS/SSL certificates for secure Flower Federated Learning communication.

**⚠️ SECURITY WARNING:** Certificate private keys are highly sensitive and should NEVER be committed to version control.

## Directory Structure

```
certificates/
├── ca/                 # Certificate Authority files
│   ├── ca.crt         # CA certificate (can be shared)
│   └── ca.key         # CA private key (NEVER share or commit!)
├── server/            # SuperLink server certificates
│   ├── server.crt     # Server certificate
│   ├── server.key     # Server private key (NEVER share or commit!)
│   └── server.csr     # Certificate signing request
└── clients/           # SuperNode client certificates
    ├── client1.crt    # Client 1 certificate
    ├── client1.key    # Client 1 private key (NEVER share or commit!)
    ├── client2.crt    # Client 2 certificate
    └── client2.key    # Client 2 private key (NEVER share or commit!)
```

## Certificate Generation (Week 4)

Certificates will be generated using EasyRSA in Week 4. See:
- `docs/guides/certificate-management.md` (to be created)
- `scripts/setup/generate_certificates.sh` (to be created)

## Usage

Certificates are mounted into Docker containers for mTLS communication:

```bash
# SuperLink with server certificate
docker run ... \
    -v $(pwd)/certificates:/certificates \
    --ssl-ca-certfile=/certificates/ca/ca.crt \
    --ssl-certfile=/certificates/server/server.crt \
    --ssl-keyfile=/certificates/server/server.key

# SuperNode with client certificate
docker run ... \
    -v $(pwd)/certificates:/certificates \
    --ssl-ca-certfile=/certificates/ca/ca.crt \
    --ssl-certfile=/certificates/clients/client1.crt \
    --ssl-keyfile=/certificates/clients/client1.key
```

## Security Best Practices

1. **Never commit private keys** (.key files) to git
2. **Protect CA private key** - it can sign any certificate
3. **Use strong key sizes** - RSA 4096 or ECC P-384
4. **Set proper file permissions** - 400 for private keys
5. **Rotate certificates regularly** - at least annually
6. **Use separate CAs** - consider separate CA for FL vs VPN
7. **Monitor expiration dates** - set up alerts

## Current Status

- [ ] EasyRSA installed
- [ ] CA initialized
- [ ] CA certificate generated
- [ ] Server certificates generated
- [ ] Client certificates generated
- [ ] Certificates tested with Flower

**Status:** Not started (Week 4 task)
