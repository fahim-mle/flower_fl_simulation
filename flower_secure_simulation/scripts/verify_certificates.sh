#!/bin/bash
# Script: verify_certificates.sh
# Purpose: Verify all service certificates for Federated Learning infrastructure
# Author: Federated Learning Lab DevOps
# Usage: ./verify_certificates.sh
#
# This script validates:
#   - Certificate file existence
#   - Private key file existence
#   - CA certificate existence
#   - Certificate expiry dates
#   - Subject Alternative Names (SANs)
#   - Certificate chain validity
#   - File permissions
#
# Exit codes:
#   0 - All certificates valid
#   1 - One or more certificates invalid or missing

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CA_DIR="${PROJECT_ROOT}/ca"
VOLUMES_DIR="${PROJECT_ROOT}/volumes/certificates"

# Services to verify
SERVICES=(
    "superlink"
    "postgres"
    "keycloak"
    "jupyterhub"
    "nginx"
    "supernode-1"
    "supernode-2"
    "supernode-3"
    "supernode-4"
    "supernode-5"
)

# Counters for statistics
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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
# Print check result
# Arguments:
#   $1 - Status (pass/fail/warn)
#   $2 - Message
#######################################
print_check() {
    local status=$1
    shift
    local message=$*

    ((TOTAL_CHECKS++))

    case $status in
        pass)
            print_message "$GREEN" "  ✓ $message"
            ((PASSED_CHECKS++))
            ;;
        fail)
            print_message "$RED" "  ✗ $message"
            ((FAILED_CHECKS++))
            ;;
        warn)
            print_message "$YELLOW" "  ⚠ $message"
            ((WARNING_CHECKS++))
            ;;
    esac
}

#######################################
# Check if file exists
# Arguments:
#   $1 - File path
#   $2 - Description
# Returns:
#   0 if exists, 1 otherwise
#######################################
check_file_exists() {
    local file_path=$1
    local description=$2

    if [ -f "$file_path" ]; then
        print_check "pass" "$description exists"
        return 0
    else
        print_check "fail" "$description missing: $file_path"
        return 1
    fi
}

#######################################
# Check file permissions
# Arguments:
#   $1 - File path
#   $2 - Expected permissions (e.g., 644, 600)
#   $3 - Description
#######################################
check_permissions() {
    local file_path=$1
    local expected_perms=$2
    local description=$3

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    local actual_perms
    actual_perms=$(stat -c "%a" "$file_path" 2>/dev/null || stat -f "%OLp" "$file_path" 2>/dev/null)

    if [ "$actual_perms" = "$expected_perms" ]; then
        print_check "pass" "$description has correct permissions ($expected_perms)"
    else
        print_check "warn" "$description has permissions $actual_perms (expected $expected_perms)"
    fi
}

#######################################
# Check certificate expiry
# Arguments:
#   $1 - Certificate path
# Returns:
#   0 if valid, 1 if expired/expiring soon
#######################################
check_certificate_expiry() {
    local cert_path=$1

    if [ ! -f "$cert_path" ]; then
        return 1
    fi

    # Check if certificate is currently valid
    if ! openssl x509 -in "$cert_path" -noout -checkend 0 > /dev/null 2>&1; then
        print_check "fail" "Certificate is expired or invalid"
        return 1
    fi

    # Get expiry date
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate | sed 's/notAfter=//')

    # Calculate days until expiry
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch
    current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [ "$days_until_expiry" -lt 30 ]; then
        print_check "warn" "Certificate expires in $days_until_expiry days ($expiry_date)"
        return 1
    elif [ "$days_until_expiry" -lt 90 ]; then
        print_check "warn" "Certificate expires in $days_until_expiry days ($expiry_date)"
    else
        print_check "pass" "Certificate valid for $days_until_expiry days (until $expiry_date)"
    fi

    return 0
}

#######################################
# Display Subject Alternative Names
# Arguments:
#   $1 - Certificate path
#######################################
display_sans() {
    local cert_path=$1

    if [ ! -f "$cert_path" ]; then
        return 1
    fi

    local san_output
    san_output=$(openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[ \t]*//')

    if [ -n "$san_output" ]; then
        print_check "pass" "Subject Alternative Names found"
        print_message "$CYAN" "    $san_output"
    else
        print_check "warn" "No Subject Alternative Names found"
    fi
}

#######################################
# Verify certificate chain
# Arguments:
#   $1 - Certificate path
#   $2 - CA certificate path
#######################################
verify_certificate_chain() {
    local cert_path=$1
    local ca_path=$2

    if [ ! -f "$cert_path" ] || [ ! -f "$ca_path" ]; then
        return 1
    fi

    if openssl verify -CAfile "$ca_path" "$cert_path" > /dev/null 2>&1; then
        print_check "pass" "Certificate chain is valid"
    else
        print_check "fail" "Certificate chain verification failed"
        return 1
    fi

    return 0
}

#######################################
# Display certificate subject
# Arguments:
#   $1 - Certificate path
#######################################
display_certificate_subject() {
    local cert_path=$1

    if [ ! -f "$cert_path" ]; then
        return 1
    fi

    local subject
    subject=$(openssl x509 -in "$cert_path" -noout -subject | sed 's/subject=//')
    print_message "$CYAN" "    Subject: $subject"
}

#######################################
# Verify a single service
# Arguments:
#   $1 - Service name
# Returns:
#   0 if all checks pass, 1 otherwise
#######################################
verify_service() {
    local service_name=$1
    local cert_dir="${VOLUMES_DIR}/${service_name}"
    local cert_file="${cert_dir}/${service_name}.crt"
    local key_file="${cert_dir}/${service_name}.key"
    local ca_file="${cert_dir}/ca.crt"

    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$BLUE" "Service: $service_name"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local service_status=0

    # Check certificate directory exists
    if [ ! -d "$cert_dir" ]; then
        print_check "fail" "Certificate directory does not exist: $cert_dir"
        echo ""
        return 1
    fi

    # Check certificate file
    if ! check_file_exists "$cert_file" "Certificate"; then
        service_status=1
    else
        # Check certificate permissions
        check_permissions "$cert_file" "644" "Certificate"

        # Check expiry
        if ! check_certificate_expiry "$cert_file"; then
            service_status=1
        fi

        # Display subject
        display_certificate_subject "$cert_file"

        # Display SANs
        display_sans "$cert_file"
    fi

    # Check private key file
    if ! check_file_exists "$key_file" "Private key"; then
        service_status=1
    else
        # Check key permissions (should be 600)
        check_permissions "$key_file" "600" "Private key"

        # Verify key matches certificate
        if [ -f "$cert_file" ]; then
            local cert_modulus
            local key_modulus
            cert_modulus=$(openssl x509 -noout -modulus -in "$cert_file" 2>/dev/null | openssl md5)
            key_modulus=$(openssl rsa -noout -modulus -in "$key_file" 2>/dev/null | openssl md5)

            if [ "$cert_modulus" = "$key_modulus" ]; then
                print_check "pass" "Private key matches certificate"
            else
                print_check "fail" "Private key does not match certificate"
                service_status=1
            fi
        fi
    fi

    # Check CA certificate file
    if ! check_file_exists "$ca_file" "CA certificate"; then
        service_status=1
    else
        # Check CA cert permissions
        check_permissions "$ca_file" "644" "CA certificate"

        # Verify certificate chain
        if [ -f "$cert_file" ]; then
            if ! verify_certificate_chain "$cert_file" "$ca_file"; then
                service_status=1
            fi
        fi
    fi

    echo ""
    return $service_status
}

#######################################
# Display CA information
#######################################
display_ca_info() {
    local ca_cert="${CA_DIR}/pki/ca.crt"

    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$BLUE" "Certificate Authority Information"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -f "$ca_cert" ]; then
        print_check "fail" "CA certificate not found: $ca_cert"
        echo ""
        return 1
    fi

    print_check "pass" "CA certificate exists"

    # Display CA details
    print_message "$CYAN" "  Subject: $(openssl x509 -in "$ca_cert" -noout -subject | sed 's/subject=//')"
    print_message "$CYAN" "  Issuer: $(openssl x509 -in "$ca_cert" -noout -issuer | sed 's/issuer=//')"

    local start_date
    local end_date
    start_date=$(openssl x509 -in "$ca_cert" -noout -startdate | sed 's/notBefore=//')
    end_date=$(openssl x509 -in "$ca_cert" -noout -enddate | sed 's/notAfter=//')

    print_message "$CYAN" "  Valid From: $start_date"
    print_message "$CYAN" "  Valid Until: $end_date"

    # Calculate days until CA expiry
    local expiry_epoch
    expiry_epoch=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
    local current_epoch
    current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [ "$days_until_expiry" -lt 365 ]; then
        print_check "warn" "CA certificate expires in $days_until_expiry days"
    else
        print_check "pass" "CA certificate valid for $days_until_expiry days"
    fi

    echo ""
}

#######################################
# Display summary statistics
#######################################
display_summary() {
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$BLUE" "Verification Summary"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    print_message "$CYAN" "  Total Checks: $TOTAL_CHECKS"
    print_message "$GREEN" "  Passed: $PASSED_CHECKS"
    print_message "$RED" "  Failed: $FAILED_CHECKS"
    print_message "$YELLOW" "  Warnings: $WARNING_CHECKS"

    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        if [ "$WARNING_CHECKS" -eq 0 ]; then
            print_message "$GREEN" "✓ All certificate checks passed successfully!"
        else
            print_message "$YELLOW" "⚠ All critical checks passed, but there are $WARNING_CHECKS warnings"
        fi
        return 0
    else
        print_message "$RED" "✗ Certificate verification failed with $FAILED_CHECKS errors"
        return 1
    fi
}

#######################################
# Main execution
#######################################
main() {
    print_message "$GREEN" "════════════════════════════════════════"
    print_message "$GREEN" "Certificate Verification Report"
    print_message "$GREEN" "Federated Learning Infrastructure"
    print_message "$GREEN" "════════════════════════════════════════"
    echo ""
    print_message "$CYAN" "Project Root: $PROJECT_ROOT"
    print_message "$CYAN" "CA Directory: $CA_DIR"
    print_message "$CYAN" "Certificates: $VOLUMES_DIR"
    print_message "$CYAN" "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Display CA information first
    display_ca_info

    # Track overall status
    local overall_status=0

    # Verify each service
    for service in "${SERVICES[@]}"; do
        if ! verify_service "$service"; then
            overall_status=1
        fi
    done

    # Display summary
    if ! display_summary; then
        overall_status=1
    fi

    exit $overall_status
}

# Run main function
main "$@"
