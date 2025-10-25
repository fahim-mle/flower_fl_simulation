#!/bin/bash
# Script: generate_all_certs.sh
# Purpose: Batch generate all service certificates for Federated Learning infrastructure
# Author: Federated Learning Lab DevOps
# Usage: ./generate_all_certs.sh [--skip-verification]
#
# This script generates certificates for all FL services in the correct order:
#   1. SuperLink (FL coordination service)
#   2. PostgreSQL (database backend)
#   3. Keycloak (identity and access management)
#   4. JupyterHub (user interface)
#   5. Nginx (reverse proxy)
#   6. SuperNode-1 through SuperNode-5 (FL client nodes)
#
# Options:
#   --skip-verification    Skip certificate verification at the end
#   --force               Force regeneration of all certificates (skip prompts)
#   -h, --help            Show help message
#
# Exit codes:
#   0 - All certificates generated successfully
#   1 - One or more certificate generations failed

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Script paths
GENERATE_SCRIPT="${SCRIPT_DIR}/generate_service_cert.sh"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify_certificates.sh"

# Options
SKIP_VERIFICATION=false
FORCE_REGENERATION=false

# Statistics
TOTAL_SERVICES=0
SUCCESS_COUNT=0
FAILED_COUNT=0
FAILED_SERVICES=()

#######################################
# Print colored message
# Arguments:
#   $1 - Color code
#   $2 - Message
#######################################
print_message() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

#######################################
# Print section header
# Arguments:
#   $1 - Header text
#######################################
print_header() {
    echo ""
    print_message "$BLUE" "════════════════════════════════════════"
    print_message "$BLUE" "$1"
    print_message "$BLUE" "════════════════════════════════════════"
    echo ""
}

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Batch generate certificates for all Federated Learning services.

This script will generate certificates for:
  - SuperLink (FL coordination)
  - PostgreSQL (database)
  - Keycloak (identity management)
  - JupyterHub (user interface)
  - Nginx (reverse proxy)
  - SuperNode-1 to SuperNode-5 (FL client nodes)

Options:
  --skip-verification    Skip certificate verification at the end
  --force               Force regeneration without prompts
  -h, --help            Show this help message

Examples:
  $(basename "$0")                     # Generate all certificates
  $(basename "$0") --skip-verification # Generate without verification
  $(basename "$0") --force             # Force regeneration

Environment:
  PROJECT_ROOT: $PROJECT_ROOT
  SCRIPT_DIR:   $SCRIPT_DIR

Note: This script requires generate_service_cert.sh in the same directory.
EOF
    exit 0
}

#######################################
# Validate prerequisites
#######################################
validate_prerequisites() {
    print_message "$CYAN" "Validating prerequisites..."

    # Check if generate_service_cert.sh exists and is executable
    if [ ! -f "$GENERATE_SCRIPT" ]; then
        print_message "$RED" "✗ Certificate generation script not found: $GENERATE_SCRIPT"
        exit 1
    fi

    if [ ! -x "$GENERATE_SCRIPT" ]; then
        print_message "$YELLOW" "⚠ Making generate_service_cert.sh executable..."
        chmod +x "$GENERATE_SCRIPT"
    fi

    # Check if verify_certificates.sh exists (optional)
    if [ ! "$SKIP_VERIFICATION" = true ] && [ ! -f "$VERIFY_SCRIPT" ]; then
        print_message "$YELLOW" "⚠ Verification script not found: $VERIFY_SCRIPT"
        print_message "$YELLOW" "⚠ Will skip verification at the end"
        SKIP_VERIFICATION=true
    fi

    # Check if CA is initialized
    if [ ! -f "${PROJECT_ROOT}/ca/pki/ca.crt" ]; then
        print_message "$RED" "✗ Certificate Authority not initialized"
        print_message "$RED" "  Please run the CA setup first:"
        print_message "$RED" "  cd ${PROJECT_ROOT}/ca && ./easyrsa build-ca"
        exit 1
    fi

    print_message "$GREEN" "✓ Prerequisites validated"
}

#######################################
# Generate certificate for a service
# Arguments:
#   $1 - Service name
#   $2 - SAN entries
# Returns:
#   0 on success, 1 on failure
#######################################
generate_service_certificate() {
    local service_name=$1
    local san_entries=$2

    ((TOTAL_SERVICES++))

    print_message "$CYAN" "[$SUCCESS_COUNT/$TOTAL_SERVICES] Generating certificate for: $service_name"

    # Call the certificate generation script
    if [ "$FORCE_REGENERATION" = true ]; then
        # Auto-answer "yes" to regeneration prompts
        if echo "yes" | "$GENERATE_SCRIPT" "$service_name" "$san_entries" > /tmp/cert_gen_${service_name}.log 2>&1; then
            print_message "$GREEN" "✓ Successfully generated certificate for $service_name"
            ((SUCCESS_COUNT++))
            return 0
        else
            print_message "$RED" "✗ Failed to generate certificate for $service_name"
            print_message "$RED" "  See log: /tmp/cert_gen_${service_name}.log"
            ((FAILED_COUNT++))
            FAILED_SERVICES+=("$service_name")
            return 1
        fi
    else
        # Interactive mode
        if "$GENERATE_SCRIPT" "$service_name" "$san_entries"; then
            print_message "$GREEN" "✓ Successfully generated certificate for $service_name"
            ((SUCCESS_COUNT++))
            return 0
        else
            print_message "$RED" "✗ Failed to generate certificate for $service_name"
            ((FAILED_COUNT++))
            FAILED_SERVICES+=("$service_name")
            return 1
        fi
    fi
}

#######################################
# Generate all service certificates
#######################################
generate_all_certificates() {
    local overall_status=0

    print_header "Phase 1: Core Infrastructure Services"

    # 1. SuperLink - FL coordination service (ports 9091-9093)
    print_message "$MAGENTA" "1/10: SuperLink (Federated Learning Coordinator)"
    if ! generate_service_certificate "superlink" \
        "DNS:superlink,DNS:superlink.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.10"; then
        overall_status=1
    fi
    echo ""

    # 2. PostgreSQL - Database backend (port 5432)
    print_message "$MAGENTA" "2/10: PostgreSQL (Database Backend)"
    if ! generate_service_certificate "postgres" \
        "DNS:postgres,DNS:postgres.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.5"; then
        overall_status=1
    fi
    echo ""

    # 3. Keycloak - Identity and Access Management (port 8443)
    print_message "$MAGENTA" "3/10: Keycloak (Identity & Access Management)"
    if ! generate_service_certificate "keycloak" \
        "DNS:keycloak,DNS:keycloak.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.6"; then
        overall_status=1
    fi
    echo ""

    # 4. JupyterHub - User interface (port 8000)
    print_message "$MAGENTA" "4/10: JupyterHub (User Interface)"
    if ! generate_service_certificate "jupyterhub" \
        "DNS:jupyterhub,DNS:jupyterhub.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.7"; then
        overall_status=1
    fi
    echo ""

    # 5. Nginx - Reverse proxy SSL termination (port 443)
    print_message "$MAGENTA" "5/10: Nginx (Reverse Proxy)"
    if ! generate_service_certificate "nginx" \
        "DNS:nginx,DNS:nginx.fl-lab.local,DNS:localhost,IP:127.0.0.1,IP:172.20.0.4"; then
        overall_status=1
    fi
    echo ""

    print_header "Phase 2: SuperNode Client Certificates"

    # 6-10. SuperNode client certificates (5 organizations)
    local supernode_configs=(
        "supernode-1:DNS:supernode-1,DNS:supernode-1.fl-lab.local,IP:172.21.0.10:Organization 1"
        "supernode-2:DNS:supernode-2,DNS:supernode-2.fl-lab.local,IP:172.21.0.11:Organization 2"
        "supernode-3:DNS:supernode-3,DNS:supernode-3.fl-lab.local,IP:172.21.0.12:Organization 3"
        "supernode-4:DNS:supernode-4,DNS:supernode-4.fl-lab.local,IP:172.21.0.13:Organization 4"
        "supernode-5:DNS:supernode-5,DNS:supernode-5.fl-lab.local,IP:172.21.0.14:Organization 5"
    )

    local index=6
    for config in "${supernode_configs[@]}"; do
        IFS=':' read -r name san org <<< "$config"
        print_message "$MAGENTA" "$index/10: $name ($org)"
        if ! generate_service_certificate "$name" "$san"; then
            overall_status=1
        fi
        echo ""
        ((index++))
    done

    return $overall_status
}

#######################################
# Run certificate verification
#######################################
run_verification() {
    if [ "$SKIP_VERIFICATION" = true ]; then
        print_message "$YELLOW" "⚠ Skipping certificate verification (--skip-verification flag)"
        return 0
    fi

    print_header "Certificate Verification"

    if [ ! -x "$VERIFY_SCRIPT" ]; then
        print_message "$YELLOW" "⚠ Making verification script executable..."
        chmod +x "$VERIFY_SCRIPT"
    fi

    print_message "$CYAN" "Running certificate verification..."
    echo ""

    if "$VERIFY_SCRIPT"; then
        print_message "$GREEN" "✓ Certificate verification passed"
        return 0
    else
        print_message "$RED" "✗ Certificate verification failed"
        return 1
    fi
}

#######################################
# Display summary
#######################################
display_summary() {
    print_header "Certificate Generation Summary"

    print_message "$CYAN" "Total Services: $TOTAL_SERVICES"
    print_message "$GREEN" "Successful: $SUCCESS_COUNT"
    print_message "$RED" "Failed: $FAILED_COUNT"

    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo ""
        print_message "$RED" "Failed services:"
        for service in "${FAILED_SERVICES[@]}"; do
            print_message "$RED" "  - $service"
        done
        echo ""
        print_message "$RED" "✗ Certificate generation completed with errors"
        return 1
    else
        echo ""
        print_message "$GREEN" "✓ All certificates generated successfully!"
        print_message "$GREEN" ""
        print_message "$GREEN" "Next steps:"
        print_message "$GREEN" "  1. Review certificates: ls -la ${PROJECT_ROOT}/volumes/certificates/"
        print_message "$GREEN" "  2. Verify certificates: ${VERIFY_SCRIPT}"
        print_message "$GREEN" "  3. Validate Phase 1: ${SCRIPT_DIR}/validate_phase1.sh"
        return 0
    fi
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --skip-verification)
                SKIP_VERIFICATION=true
                shift
                ;;
            --force)
                FORCE_REGENERATION=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_message "$RED" "Unknown option: $1"
                print_message "$YELLOW" "Use -h or --help for usage information"
                exit 1
                ;;
        esac
    done
}

#######################################
# Display banner
#######################################
display_banner() {
    print_message "$GREEN" "════════════════════════════════════════"
    print_message "$GREEN" "  Batch Certificate Generation Script"
    print_message "$GREEN" "  Federated Learning Infrastructure"
    print_message "$GREEN" "════════════════════════════════════════"
    echo ""
    print_message "$CYAN" "This script will generate certificates for:"
    print_message "$CYAN" "  • 5 Core infrastructure services"
    print_message "$CYAN" "  • 5 SuperNode client nodes"
    echo ""
    print_message "$CYAN" "Project Root: $PROJECT_ROOT"
    print_message "$CYAN" "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    if [ "$FORCE_REGENERATION" = true ]; then
        print_message "$YELLOW" "⚠ Force mode enabled - will regenerate existing certificates"
        echo ""
    fi

    if [ "$SKIP_VERIFICATION" = true ]; then
        print_message "$YELLOW" "⚠ Verification will be skipped"
        echo ""
    fi
}

#######################################
# Confirm before proceeding
#######################################
confirm_proceed() {
    if [ "$FORCE_REGENERATION" = true ]; then
        # Skip confirmation in force mode
        return 0
    fi

    read -p "Proceed with certificate generation? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_message "$YELLOW" "Certificate generation cancelled"
        exit 0
    fi
}

#######################################
# Main execution
#######################################
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Display banner
    display_banner

    # Validate prerequisites
    validate_prerequisites
    echo ""

    # Confirm before proceeding
    confirm_proceed

    # Record start time
    local start_time
    start_time=$(date +%s)

    # Generate all certificates
    local generation_status=0
    if ! generate_all_certificates; then
        generation_status=1
    fi

    # Run verification
    local verification_status=0
    if ! run_verification; then
        verification_status=1
    fi

    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Display summary
    echo ""
    if ! display_summary; then
        generation_status=1
    fi

    echo ""
    print_message "$CYAN" "Total execution time: ${duration} seconds"
    echo ""

    # Exit with appropriate code
    if [ "$generation_status" -ne 0 ] || [ "$verification_status" -ne 0 ]; then
        exit 1
    fi

    exit 0
}

# Run main function
main "$@"
