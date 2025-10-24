#!/bin/bash

# National Federated Learning Infrastructure - Certificate Authority Setup Script
# Version: 1.0
# Date: 2025-07-01

set -euo pipefail

# Configuration variables
CA_DIR="/opt/national-fl-ca"
EASYRSA_VERSION="3.1.7"
ORG_NAME="National FL Infrastructure"
ORG_UNIT="Federated Learning"
COUNTRY="AU"
STATE="Queensland"
CITY="Brisbane"
EMAIL="admin@nationalfl.org.au"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    apt-get update
    apt-get install -y \
        easy-rsa \
        openssl \
        curl \
        wget \
        unzip \
        jq \
        git
}

# Create CA directory structure
create_ca_structure() {
    log "Creating CA directory structure..."
    mkdir -p "${CA_DIR}"
    mkdir -p "${CA_DIR}/certs"
    mkdir -p "${CA_DIR}/private"
    mkdir -p "${CA_DIR}/requests"
    mkdir -p "${CA_DIR}/scripts"
    mkdir -p "${CA_DIR}/config"

    # Set appropriate permissions
    chmod 700 "${CA_DIR}/private"
    chmod 755 "${CA_DIR}"
    chmod 755 "${CA_DIR}/certs"
    chmod 755 "${CA_DIR}/requests"
    chmod 755 "${CA_DIR}/scripts"
    chmod 755 "${CA_DIR}/config"
}

# Initialize easy-rsa
initialize_easyrsa() {
    log "Initializing easy-rsa..."

    # Copy easy-rsa templates
    cp -r /usr/share/easy-rsa/* "${CA_DIR}/"

    # Create vars file
    cat > "${CA_DIR}/vars" << EOF
set_var EASYRSA_REQ_COUNTRY     "${COUNTRY}"
set_var EASYRSA_REQ_PROVINCE    "${STATE}"
set_var EASYRSA_REQ_CITY        "${CITY}"
set_var EASYRSA_REQ_ORG         "${ORG_NAME}"
set_var EASYRSA_REQ_ORG_UNIT    "${ORG_UNIT}"
set_var EASYRSA_REQ_EMAIL       "${EMAIL}"
set_var EASYRSA_REQ_CN          "National FL Infrastructure CA"
set_var EASYRSA_KEY_SIZE        2048
set_var EASYRSA_CA_EXPIRE       3650
set_var EASYRSA_CERT_EXPIRE     825
set_var EASYRSA_DIGEST          "sha512"
EOF

    cd "${CA_DIR}"

    # Initialize PKI
    ./easyrsa init-pki

    log "Easy-rsa initialized successfully"
}

# Build Certificate Authority
build_ca() {
    log "Building Certificate Authority..."

    cd "${CA_DIR}"

    # Build CA (nopass for automation - consider manual for production)
    echo "yes" | ./easyrsa build-ca nopass

    # Copy CA certificate to certs directory
    cp "${CA_DIR}/pki/ca.crt" "${CA_DIR}/certs/"

    log "Certificate Authority built successfully"
    log_info "CA certificate located at: ${CA_DIR}/pki/ca.crt"
}

# Generate server certificates
generate_server_certs() {
    log "Generating server certificates..."

    cd "${CA_DIR}"

    # Server certificate configurations
    declare -A SERVER_CERTS=(
        ["vpn-server"]="vpn.nationalfl.org.au,10.0.1.80,10.10.0.1"
        ["superlink"]="superlink.nationalfl.org.au,10.0.1.50"
        ["keycloak"]="keycloak.nationalfl.org.au,10.0.1.20"
        ["jupyterhub"]="jupyterhub.nationalfl.org.au,10.0.1.40"
        ["grafana"]="grafana.nationalfl.org.au,10.0.1.60"
        ["prometheus"]="prometheus.nationalfl.org.au,10.0.1.70"
        ["postgresql"]="postgresql.nationalfl.org.au,10.0.1.30"
    )

    for server_name in "${!SERVER_CERTS[@]}"; do
        log "Generating certificate for ${server_name}"

        # Create certificate request
        ./easyrsa gen-req "${server_name}" nopass

        # Sign certificate with server type
        echo "yes" | ./easyrsa sign-req server "${server_name}"

        # Copy certificates and keys
        cp "${CA_DIR}/pki/issued/${server_name}.crt" "${CA_DIR}/certs/"
        cp "${CA_DIR}/pki/private/${server_name}.key" "${CA_DIR}/private/"

        # Create certificate bundle
        cat "${CA_DIR}/pki/issued/${server_name}.crt" "${CA_DIR}/pki/ca.crt" > "${CA_DIR}/certs/${server_name}-bundle.crt"

        log_info "Certificate for ${server_name} generated successfully"
    done
}

# Generate client certificates for organizations
generate_client_certs() {
    log "Generating client certificates for organizations..."

    cd "${CA_DIR}"

    # Example organization certificates
    declare -A ORG_CERTS=(
        ["org1-supernode"]="Organization 1 SuperNode"
        ["org2-supernode"]="Organization 2 SuperNode"
        ["org3-supernode"]="Organization 3 SuperNode"
    )

    for client_name in "${!ORG_CERTS[@]}"; do
        log "Generating client certificate for ${client_name}"

        # Create certificate request
        ./easyrsa gen-req "${client_name}" nopass

        # Sign certificate with client type
        echo "yes" | ./easyrsa sign-req client "${client_name}"

        # Copy certificates and keys
        cp "${CA_DIR}/pki/issued/${client_name}.crt" "${CA_DIR}/certs/"
        cp "${CA_DIR}/pki/private/${client_name}.key" "${CA_DIR}/private/"

        # Create certificate bundle
        cat "${CA_DIR}/pki/issued/${client_name}.crt" "${CA_DIR}/pki/ca.crt" > "${CA_DIR}/certs/${client_name}-bundle.crt"

        log_info "Client certificate for ${client_name} generated successfully"
    done
}

# Generate OpenVPN client certificates
generate_vpn_certs() {
    log "Generating OpenVPN client certificates..."

    cd "${CA_DIR}"

    # Generate Diffie-Hellman parameters
    ./easyrsa gen-dh

    # Generate HMAC signature
    openvpn --genkey --secret "${CA_DIR}/certs/ta.key"

    # Copy DH parameters
    cp "${CA_DIR}/pki/dh.pem" "${CA_DIR}/certs/"

    log "OpenVPN parameters generated successfully"
}

# Create certificate distribution packages
create_distribution_packages() {
    log "Creating certificate distribution packages..."

    # Server packages
    mkdir -p "${CA_DIR}/distribute/servers"

    declare -A SERVER_CERTS=(
        ["vpn-server"]="vpn.nationalfl.org.au"
        ["superlink"]="superlink.nationalfl.org.au"
        ["keycloak"]="keycloak.nationalfl.org.au"
        ["jupyterhub"]="jupyterhub.nationalfl.org.au"
        ["grafana"]="grafana.nationalfl.org.au"
        ["prometheus"]="prometheus.nationalfl.org.au"
        ["postgresql"]="postgresql.nationalfl.org.au"
    )

    for server_name in "${!SERVER_CERTS[@]}"; do
        pkg_dir="${CA_DIR}/distribute/servers/${server_name}"
        mkdir -p "${pkg_dir}"

        cp "${CA_DIR}/certs/${server_name}.crt" "${pkg_dir}/"
        cp "${CA_DIR}/private/${server_name}.key" "${pkg_dir}/"
        cp "${CA_DIR}/certs/${server_name}-bundle.crt" "${pkg_dir}/"
        cp "${CA_DIR}/pki/ca.crt" "${pkg_dir}/"

        # Create installation script
        cat > "${pkg_dir}/install.sh" << EOF
#!/bin/bash
# Certificate installation script for ${SERVER_CERTS[$server_name]}

CERT_DIR="/etc/ssl/certs/national-fl"
KEY_DIR="/etc/ssl/private/national-fl"

# Create directories
sudo mkdir -p "\${CERT_DIR}"
sudo mkdir -p "\${KEY_DIR}"

# Copy certificates
sudo cp *.crt "\${CERT_DIR}/"
sudo cp *.key "\${KEY_DIR}/"

# Set permissions
sudo chmod 644 "\${CERT_DIR}"/*.crt
sudo chmod 600 "\${KEY_DIR}"/*.key

echo "Certificates installed for ${SERVER_CERTS[$server_name]}"
EOF

        chmod +x "${pkg_dir}/install.sh"

        # Create package
        tar -czf "${CA_DIR}/distribute/${server_name}-certs.tar.gz" -C "${CA_DIR}/distribute/servers" "${server_name}"

        log_info "Package created for ${server_name}: ${CA_DIR}/distribute/${server_name}-certs.tar.gz"
    done

    # Client packages
    mkdir -p "${CA_DIR}/distribute/clients"

    declare -A ORG_CERTS=(
        ["org1-supernode"]="Organization 1"
        ["org2-supernode"]="Organization 2"
        ["org3-supernode"]="Organization 3"
    )

    for client_name in "${!ORG_CERTS[@]}"; do
        pkg_dir="${CA_DIR}/distribute/clients/${client_name}"
        mkdir -p "${pkg_dir}"

        cp "${CA_DIR}/certs/${client_name}.crt" "${pkg_dir}/"
        cp "${CA_DIR}/private/${client_name}.key" "${pkg_dir}/"
        cp "${CA_DIR}/certs/${client_name}-bundle.crt" "${pkg_dir}/"
        cp "${CA_DIR}/pki/ca.crt" "${pkg_dir}/"

        # Create installation script
        cat > "${pkg_dir}/install.sh" << EOF
#!/bin/bash
# Certificate installation script for ${client_name}

CERT_DIR="/etc/ssl/certs/national-fl"
KEY_DIR="/etc/ssl/private/national-fl"

# Create directories
sudo mkdir -p "\${CERT_DIR}"
sudo mkdir -p "\${KEY_DIR}"

# Copy certificates
sudo cp *.crt "\${CERT_DIR}/"
sudo cp *.key "\${KEY_DIR}/"

# Set permissions
sudo chmod 644 "\${CERT_DIR}"/*.crt
sudo chmod 600 "\${KEY_DIR}"/*.key

echo "Certificates installed for ${client_name}"
EOF

        chmod +x "${pkg_dir}/install.sh"

        # Create package
        tar -czf "${CA_DIR}/distribute/${client_name}-certs.tar.gz" -C "${CA_DIR}/distribute/clients" "${client_name}"

        log_info "Package created for ${client_name}: ${CA_DIR}/distribute/${client_name}-certs.tar.gz"
    done

    # OpenVPN package
    mkdir -p "${CA_DIR}/distribute/openvpn"
    cp "${CA_DIR}/certs/ca.crt" "${CA_DIR}/distribute/openvpn/"
    cp "${CA_DIR}/certs/ta.key" "${CA_DIR}/distribute/openvpn/"
    cp "${CA_DIR}/certs/dh.pem" "${CA_DIR}/distribute/openvpn/"

    tar -czf "${CA_DIR}/distribute/openvpn-server-certs.tar.gz" -C "${CA_DIR}/distribute" "openvpn"

    log_info "OpenVPN package created: ${CA_DIR}/distribute/openvpn-server-certs.tar.gz"
}

# Create certificate management scripts
create_management_scripts() {
    log "Creating certificate management scripts..."

    # Certificate renewal script
    cat > "${CA_DIR}/scripts/renew-cert.sh" << 'EOF'
#!/bin/bash
# Certificate renewal script

CA_DIR="/opt/national-fl-ca"
CERT_NAME="$1"

if [[ -z "$CERT_NAME" ]]; then
    echo "Usage: $0 <certificate-name>"
    exit 1
fi

cd "$CA_DIR"

# Revoke old certificate
./easyrsa revoke "$CERT_NAME"

# Generate new certificate
./easyrsa gen-req "$CERT_NAME" nopass
./easyrsa sign-req server "$CERT_NAME"

# Update distribution package
echo "Certificate $CERT_NAME renewed successfully"
EOF

    chmod +x "${CA_DIR}/scripts/renew-cert.sh"

    # Certificate revocation script
    cat > "${CA_DIR}/scripts/revoke-cert.sh" << 'EOF'
#!/bin/bash
# Certificate revocation script

CA_DIR="/opt/national-fl-ca"
CERT_NAME="$1"

if [[ -z "$CERT_NAME" ]]; then
    echo "Usage: $0 <certificate-name>"
    exit 1
fi

cd "$CA_DIR"

# Revoke certificate
echo "yes" | ./easyrsa revoke "$CERT_NAME"

# Generate CRL
./easyrsa gen-crl

echo "Certificate $CERT_NAME revoked successfully"
EOF

    chmod +x "${CA_DIR}/scripts/revoke-cert.sh"

    # Certificate listing script
    cat > "${CA_DIR}/scripts/list-certs.sh" << 'EOF'
#!/bin/bash
# Certificate listing script

CA_DIR="/opt/national-fl-ca"

cd "$CA_DIR"

echo "=== Issued Certificates ==="
ls -la pki/issued/

echo ""
echo "=== Private Keys ==="
ls -la pki/private/

echo ""
echo "=== Certificate Revocation List ==="
if [[ -f "pki/crl.pem" ]]; then
    openssl crl -in pki/crl.pem -text -noout
else
    echo "No CRL found"
fi
EOF

    chmod +x "${CA_DIR}/scripts/list-certs.sh"
}

# Create documentation
create_documentation() {
    log "Creating documentation..."

    cat > "${CA_DIR}/README.md" << EOF
# National Federated Learning Infrastructure - Certificate Authority

## Overview
This Certificate Authority (CA) provides the public key infrastructure (PKI) for the National Federated Learning Infrastructure.

## Directory Structure

- \`pki/\`: Easy-rsa PKI directory
- \`certs/\`: Issued certificates
- \`private/\`: Private keys (restricted access)
- \`requests/\`: Certificate signing requests
- \`scripts/\`: Management scripts
- \`distribute/\`: Certificate distribution packages

## Certificate Types

### Server Certificates
- VPN Server: VPN authentication
- Superlink: Flower Superlink service
- Keycloak: Authentication service
- JupyterHub: JupyterHub service
- Grafana: Monitoring service
- Prometheus: Metrics collection
- PostgreSQL: Database service

### Client Certificates
- Organization SuperNodes: Client authentication for federated learning participants

## Management Scripts

- \`scripts/renew-cert.sh <cert-name>\`: Renew a certificate
- \`scripts/revoke-cert.sh <cert-name>\`: Revoke a certificate
- \`scripts/list-certs.sh\`: List all certificates

## Security Notes

- Private keys are stored in \`private/\` with restricted permissions
- CA certificate is located at \`pki/ca.crt\`
- Certificate revocation list is maintained at \`pki/crl.pem\`
- All certificates use 4096-bit RSA keys with SHA-512 signatures

## Certificate Lifecycle

- CA certificate: 10 years
- Server certificates: 825 days (~2.25 years)
- Client certificates: 825 days (~2.25 years)

## Distribution

Certificate packages are created in \`distribute/\` directory:
- Server packages: \`distribute/servers/\`
- Client packages: \`distribute/clients/\`
- OpenVPN package: \`distribute/openvpn-server-certs.tar.gz\`

Each package includes:
- Certificate file (.crt)
- Private key (.key)
- Certificate bundle (cert + CA)
- CA certificate
- Installation script

## Generated On

$(date)

## Configuration

- Organization: ${ORG_NAME}
- Organizational Unit: ${ORG_UNIT}
- Country: ${COUNTRY}
- State: ${STATE}
- City: ${CITY}
- Email: ${EMAIL}
EOF
}

# Main execution
main() {
    log "Starting Certificate Authority setup for National Federated Learning Infrastructure"

    check_root
    install_dependencies
    create_ca_structure
    initialize_easyrsa
    build_ca
    generate_server_certs
    generate_client_certs
    generate_vpn_certs
    create_distribution_packages
    create_management_scripts
    create_documentation

    log "Certificate Authority setup completed successfully!"
    log_info "CA directory: ${CA_DIR}"
    log_info "CA certificate: ${CA_DIR}/pki/ca.crt"
    log_info "Distribution packages: ${CA_DIR}/distribute/"
    log_warning "Ensure secure backup of ${CA_DIR}/private/ directory"
    log_warning "Restrict access to private keys to authorized personnel only"
}

# Run main function
main "$@"
