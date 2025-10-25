#!/bin/bash
# Script: generate_service_cert.sh
# Purpose: Generate service certificates for Federated Learning infrastructure
# Author: Federated Learning Lab DevOps
# Usage: ./generate_service_cert.sh <service-name> <san-entries>
#
# Example:
#   ./generate_service_cert.sh superlink "DNS:superlink,DNS:superlink.fl-lab.local,IP:127.0.0.1"
#
# This script:
#   1. Generates a certificate and private key using easy-rsa
#   2. Includes Subject Alternative Names (SANs) for Docker DNS resolution
#   3. Copies certificates to the service's volume directory
#   4. Sets proper permissions (644 for certs, 600 for keys)
#
# Prerequisites:
#   - easy-rsa installed and initialized in ../ca/
#   - Certificate Authority (CA) already built
#   - Target service volume directory exists in ../volumes/certificates/

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_DIR="${PROJECT_ROOT}/ca"
VOLUMES_DIR="${PROJECT_ROOT}/volumes/certificates"

#######################################
# Print colored message to stderr
# Arguments:
#   $1 - Color code
#   $2 - Message
#######################################
print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}" >&2
}

#######################################
# Print error message and exit
# Arguments:
#   $1 - Error message
#######################################
error_exit() {
    print_message "$RED" "ERROR: $1"
    exit 1
}

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
Usage: $(basename "$0") <service-name> <san-entries>

Generate a certificate for a Federated Learning service with Subject Alternative Names.

Arguments:
  service-name    Name of the service (e.g., superlink, postgres, keycloak)
  san-entries     Comma-separated SANs (e.g., "DNS:superlink,IP:127.0.0.1")

Examples:
  $(basename "$0") superlink "DNS:superlink,DNS:superlink.fl-lab.local,IP:127.0.0.1"
  $(basename "$0") postgres "DNS:postgres,DNS:postgres.fl-lab.local,IP:172.20.0.5"

Options:
  -h, --help      Show this help message

Environment:
  PROJECT_ROOT    $PROJECT_ROOT
  CA_DIR          $CA_DIR
  VOLUMES_DIR     $VOLUMES_DIR
EOF
    exit 0
}

#######################################
# Validate prerequisites
#######################################
validate_prerequisites() {
    print_message "$BLUE" "=== Validating Prerequisites ==="

    # Check if CA directory exists
    if [ ! -d "$CA_DIR" ]; then
        error_exit "CA directory not found: $CA_DIR"
    fi

    # Check if easyrsa exists
    if [ ! -x "$CA_DIR/easyrsa" ]; then
        error_exit "easyrsa executable not found in: $CA_DIR"
    fi

    # Check if CA certificate exists
    if [ ! -f "$CA_DIR/pki/ca.crt" ]; then
        error_exit "CA certificate not found. Please run './easyrsa build-ca' first"
    fi

    # Check if volumes directory exists
    if [ ! -d "$VOLUMES_DIR" ]; then
        error_exit "Volumes directory not found: $VOLUMES_DIR"
    fi

    print_message "$GREEN" "✓ Prerequisites validated successfully"
}

#######################################
# Create service certificate directory
# Arguments:
#   $1 - Service name
#######################################
create_cert_directory() {
    local service_name=$1
    local cert_dir="${VOLUMES_DIR}/${service_name}"

    if [ ! -d "$cert_dir" ]; then
        print_message "$YELLOW" "Creating certificate directory: $cert_dir"
        mkdir -p "$cert_dir" || error_exit "Failed to create directory: $cert_dir"
    fi

    print_message "$GREEN" "✓ Certificate directory ready: $cert_dir"
}

#######################################
# Generate certificate using easy-rsa
# Arguments:
#   $1 - Service name
#   $2 - SAN entries
#######################################
generate_certificate() {
    local service_name=$1
    local san_entries=$2

    print_message "$BLUE" "=== Generating Certificate for: $service_name ==="
    print_message "$BLUE" "Subject Alternative Names: $san_entries"

    # Change to CA directory
    cd "$CA_DIR" || error_exit "Failed to change to CA directory"

    # Check if certificate already exists
    if [ -f "pki/issued/${service_name}.crt" ]; then
        print_message "$YELLOW" "⚠ Certificate already exists for $service_name"
        read -p "Do you want to regenerate it? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            print_message "$YELLOW" "Skipping certificate generation"
            return 0
        fi

        # Revoke existing certificate
        print_message "$YELLOW" "Revoking existing certificate..."
        ./easyrsa revoke "$service_name" || print_message "$YELLOW" "⚠ Revocation warning (non-critical)"
    fi

    # Generate certificate with SANs
    print_message "$BLUE" "Generating server certificate with private key..."
    if ./easyrsa --subject-alt-name="$san_entries" --batch build-server-full "$service_name" nopass; then
        print_message "$GREEN" "✓ Certificate generated successfully"
    else
        error_exit "Failed to generate certificate for $service_name"
    fi

    # Verify certificate was created
    if [ ! -f "pki/issued/${service_name}.crt" ] || [ ! -f "pki/private/${service_name}.key" ]; then
        error_exit "Certificate files not found after generation"
    fi
}

#######################################
# Copy certificates to service volume
# Arguments:
#   $1 - Service name
#######################################
copy_certificates() {
    local service_name=$1
    local cert_dir="${VOLUMES_DIR}/${service_name}"

    print_message "$BLUE" "=== Copying Certificates to Volume ==="

    # Copy certificate
    if cp "${CA_DIR}/pki/issued/${service_name}.crt" "${cert_dir}/${service_name}.crt"; then
        print_message "$GREEN" "✓ Copied certificate: ${service_name}.crt"
    else
        error_exit "Failed to copy certificate"
    fi

    # Copy private key
    if cp "${CA_DIR}/pki/private/${service_name}.key" "${cert_dir}/${service_name}.key"; then
        print_message "$GREEN" "✓ Copied private key: ${service_name}.key"
    else
        error_exit "Failed to copy private key"
    fi

    # Copy CA certificate
    if cp "${CA_DIR}/pki/ca.crt" "${cert_dir}/ca.crt"; then
        print_message "$GREEN" "✓ Copied CA certificate: ca.crt"
    else
        error_exit "Failed to copy CA certificate"
    fi
}

#######################################
# Set proper file permissions
# Arguments:
#   $1 - Service name
#######################################
set_permissions() {
    local service_name=$1
    local cert_dir="${VOLUMES_DIR}/${service_name}"

    print_message "$BLUE" "=== Setting File Permissions ==="

    # Set certificate permissions (readable by all)
    chmod 644 "${cert_dir}/${service_name}.crt" || error_exit "Failed to set certificate permissions"
    print_message "$GREEN" "✓ Certificate permissions: 644 (readable)"

    # Set private key permissions (owner read-only)
    chmod 600 "${cert_dir}/${service_name}.key" || error_exit "Failed to set key permissions"
    print_message "$GREEN" "✓ Private key permissions: 600 (secure)"

    # Set CA certificate permissions (readable by all)
    chmod 644 "${cert_dir}/ca.crt" || error_exit "Failed to set CA certificate permissions"
    print_message "$GREEN" "✓ CA certificate permissions: 644 (readable)"
}

#######################################
# Verify generated certificates
# Arguments:
#   $1 - Service name
#######################################
verify_certificate() {
    local service_name=$1
    local cert_path="${VOLUMES_DIR}/${service_name}/${service_name}.crt"

    print_message "$BLUE" "=== Verifying Certificate ==="

    # Check certificate validity
    if openssl x509 -in "$cert_path" -noout -checkend 0 > /dev/null 2>&1; then
        print_message "$GREEN" "✓ Certificate is valid"
    else
        error_exit "Certificate validation failed"
    fi

    # Display certificate information
    print_message "$BLUE" "Certificate Details:"
    echo "  Subject: $(openssl x509 -in "$cert_path" -noout -subject | sed 's/subject=//')"
    echo "  Issuer: $(openssl x509 -in "$cert_path" -noout -issuer | sed 's/issuer=//')"
    echo "  Valid From: $(openssl x509 -in "$cert_path" -noout -startdate | sed 's/notBefore=//')"
    echo "  Valid Until: $(openssl x509 -in "$cert_path" -noout -enddate | sed 's/notAfter=//')"

    # Display SANs
    print_message "$BLUE" "Subject Alternative Names:"
    openssl x509 -in "$cert_path" -noout -text | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[ \t]*/  /'
}

#######################################
# Main execution
#######################################
main() {
    # Parse arguments
    if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
    fi

    if [ "$#" -ne 2 ]; then
        error_exit "Invalid number of arguments. Use -h for help."
    fi

    local service_name=$1
    local san_entries=$2

    # Validate service name (alphanumeric and hyphens only)
    if ! [[ "$service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error_exit "Invalid service name. Use only alphanumeric characters, hyphens, and underscores."
    fi

    # Validate SAN entries format
    if ! [[ "$san_entries" =~ ^(DNS:|IP:) ]]; then
        error_exit "Invalid SAN format. Must start with DNS: or IP: (e.g., 'DNS:example.com,IP:127.0.0.1')"
    fi

    print_message "$GREEN" "================================"
    print_message "$GREEN" "Certificate Generation Script"
    print_message "$GREEN" "Service: $service_name"
    print_message "$GREEN" "================================"
    echo ""

    # Execute workflow
    validate_prerequisites
    echo ""

    create_cert_directory "$service_name"
    echo ""

    generate_certificate "$service_name" "$san_entries"
    echo ""

    copy_certificates "$service_name"
    echo ""

    set_permissions "$service_name"
    echo ""

    verify_certificate "$service_name"
    echo ""

    print_message "$GREEN" "================================"
    print_message "$GREEN" "✓ Certificate Generation Complete"
    print_message "$GREEN" "================================"
    print_message "$GREEN" "Location: ${VOLUMES_DIR}/${service_name}/"
    print_message "$GREEN" "Files:"
    print_message "$GREEN" "  - ${service_name}.crt (certificate)"
    print_message "$GREEN" "  - ${service_name}.key (private key)"
    print_message "$GREEN" "  - ca.crt (CA certificate)"
    echo ""
}

# Run main function
main "$@"
