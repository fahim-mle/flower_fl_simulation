#!/bin/bash
# Script: validate_phase1.sh
# Purpose: Comprehensive Phase 1 validation for Federated Learning infrastructure
# Author: Federated Learning Lab DevOps
# Usage: ./validate_phase1.sh [--report <filename>]
#
# This script validates all Phase 1 checklist items:
#   - Section 1.1: Project Structure Setup
#   - Section 1.2: Certificate Authority Setup
#   - Section 1.3: Service Certificate Generation
#
# Options:
#   --report <filename>    Generate markdown report (default: phase1_validation_report.md)
#   --no-report           Don't generate a report file
#   -h, --help            Show help message
#
# Exit codes:
#   0 - Phase 1 complete and validated
#   1 - Phase 1 incomplete or validation failed

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Options
GENERATE_REPORT=true
REPORT_FILE="${PROJECT_ROOT}/phase1_validation_report.md"

# Statistics
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Arrays to store check results
declare -a SECTION_11_RESULTS=()
declare -a SECTION_12_RESULTS=()
declare -a SECTION_13_RESULTS=()

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
#   $3 - Section array name (optional)
#######################################
print_check() {
    local status=$1
    local message=$2
    local section_array=${3:-}

    ((TOTAL_CHECKS++))

    local symbol
    local color
    case $status in
        pass)
            symbol="✓"
            color="$GREEN"
            ((PASSED_CHECKS++))
            ;;
        fail)
            symbol="✗"
            color="$RED"
            ((FAILED_CHECKS++))
            ;;
        warn)
            symbol="⚠"
            color="$YELLOW"
            ((WARNING_CHECKS++))
            ;;
    esac

    print_message "$color" "  $symbol $message"

    # Store result for report generation
    if [ -n "$section_array" ]; then
        eval "${section_array}+=(\"$status|$message\")"
    fi
}

#######################################
# Print section header
# Arguments:
#   $1 - Section title
#######################################
print_section_header() {
    echo ""
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$BLUE" "$1"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

#######################################
# Check if directory exists
# Arguments:
#   $1 - Directory path
#   $2 - Description
#   $3 - Section array name
#######################################
check_directory() {
    local dir_path=$1
    local description=$2
    local section_array=$3

    if [ -d "$dir_path" ]; then
        print_check "pass" "$description exists: $dir_path" "$section_array"
        return 0
    else
        print_check "fail" "$description missing: $dir_path" "$section_array"
        return 1
    fi
}

#######################################
# Check if file exists
# Arguments:
#   $1 - File path
#   $2 - Description
#   $3 - Section array name
#######################################
check_file() {
    local file_path=$1
    local description=$2
    local section_array=$3

    if [ -f "$file_path" ]; then
        print_check "pass" "$description exists: $file_path" "$section_array"
        return 0
    else
        print_check "fail" "$description missing: $file_path" "$section_array"
        return 1
    fi
}

#######################################
# Validate Section 1.1: Project Structure
#######################################
validate_section_11() {
    print_section_header "Section 1.1: Project Structure Setup"

    local status=0

    # Check root directories
    check_directory "${PROJECT_ROOT}/ca" "CA directory" "SECTION_11_RESULTS" || status=1
    check_directory "${PROJECT_ROOT}/config" "Config directory" "SECTION_11_RESULTS" || status=1
    check_directory "${PROJECT_ROOT}/volumes" "Volumes directory" "SECTION_11_RESULTS" || status=1
    check_directory "${PROJECT_ROOT}/docker" "Docker directory" "SECTION_11_RESULTS" || status=1
    check_directory "${PROJECT_ROOT}/scripts" "Scripts directory" "SECTION_11_RESULTS" || status=1
    check_directory "${PROJECT_ROOT}/logs" "Logs directory" "SECTION_11_RESULTS" || status=1

    # Check CA subdirectories
    check_directory "${PROJECT_ROOT}/ca/pki" "PKI directory" "SECTION_11_RESULTS" || status=1

    # Check volume subdirectories
    local volume_dirs=(
        "postgres"
        "keycloak"
        "jupyterhub"
        "nginx"
        "prometheus"
        "grafana"
    )

    for dir in "${volume_dirs[@]}"; do
        check_directory "${PROJECT_ROOT}/volumes/${dir}" "Volume directory: ${dir}" "SECTION_11_RESULTS" || status=1
    done

    # Check certificate volume directories
    local cert_services=(
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

    for service in "${cert_services[@]}"; do
        check_directory "${PROJECT_ROOT}/volumes/certificates/${service}" \
            "Certificate directory: ${service}" "SECTION_11_RESULTS" || status=1
    done

    # Check configuration subdirectories
    local config_dirs=(
        "nginx"
        "nginx/sites-available"
        "nginx/sites-enabled"
        "nginx/ssl"
        "keycloak"
        "jupyterhub"
        "prometheus"
        "grafana"
        "superlink"
        "supernode"
    )

    for dir in "${config_dirs[@]}"; do
        check_directory "${PROJECT_ROOT}/config/${dir}" "Config directory: ${dir}" "SECTION_11_RESULTS" || status=1
    done

    # Check for network definitions (optional)
    if [ -f "${PROJECT_ROOT}/docker/networks.yml" ]; then
        print_check "pass" "Network definitions exist" "SECTION_11_RESULTS"
    else
        print_check "warn" "Network definitions not found (optional)" "SECTION_11_RESULTS"
    fi

    return $status
}

#######################################
# Validate Section 1.2: Certificate Authority
#######################################
validate_section_12() {
    print_section_header "Section 1.2: Certificate Authority Setup"

    local status=0

    # Check easy-rsa installation
    if command -v easyrsa > /dev/null 2>&1; then
        print_check "pass" "easy-rsa is installed" "SECTION_12_RESULTS"
    else
        print_check "warn" "easy-rsa not found in PATH (may be local)" "SECTION_12_RESULTS"
    fi

    # Check for local easyrsa
    if [ -x "${PROJECT_ROOT}/ca/easyrsa" ]; then
        print_check "pass" "Local easyrsa executable exists" "SECTION_12_RESULTS"
    else
        print_check "fail" "Local easyrsa executable not found" "SECTION_12_RESULTS"
        status=1
    fi

    # Check PKI initialization
    check_directory "${PROJECT_ROOT}/ca/pki" "PKI directory initialized" "SECTION_12_RESULTS" || status=1

    # Check for vars file
    if [ -f "${PROJECT_ROOT}/ca/pki/vars" ]; then
        print_check "pass" "CA variables configured (pki/vars)" "SECTION_12_RESULTS"

        # Validate vars content
        if grep -q "EASYRSA_REQ_COUNTRY" "${PROJECT_ROOT}/ca/pki/vars" 2>/dev/null; then
            print_check "pass" "CA vars contains organization details" "SECTION_12_RESULTS"
        else
            print_check "warn" "CA vars may be incomplete" "SECTION_12_RESULTS"
        fi
    else
        print_check "fail" "CA variables file missing (pki/vars)" "SECTION_12_RESULTS"
        status=1
    fi

    # Check CA certificate
    if check_file "${PROJECT_ROOT}/ca/pki/ca.crt" "Root CA certificate" "SECTION_12_RESULTS"; then
        # Verify CA certificate is valid
        if openssl x509 -in "${PROJECT_ROOT}/ca/pki/ca.crt" -noout -checkend 0 > /dev/null 2>&1; then
            print_check "pass" "Root CA certificate is valid" "SECTION_12_RESULTS"

            # Check CA certificate details
            local ca_subject
            ca_subject=$(openssl x509 -in "${PROJECT_ROOT}/ca/pki/ca.crt" -noout -subject 2>/dev/null)
            print_message "$CYAN" "    $ca_subject"

            # Check expiry
            local expiry_date
            expiry_date=$(openssl x509 -in "${PROJECT_ROOT}/ca/pki/ca.crt" -noout -enddate | sed 's/notAfter=//')
            print_message "$CYAN" "    Valid Until: $expiry_date"
        else
            print_check "fail" "Root CA certificate is invalid or expired" "SECTION_12_RESULTS"
            status=1
        fi
    else
        status=1
    fi

    # Check CA private key
    if check_file "${PROJECT_ROOT}/ca/pki/private/ca.key" "CA private key" "SECTION_12_RESULTS"; then
        # Check key permissions
        local key_perms
        key_perms=$(stat -c "%a" "${PROJECT_ROOT}/ca/pki/private/ca.key" 2>/dev/null || stat -f "%OLp" "${PROJECT_ROOT}/ca/pki/private/ca.key" 2>/dev/null)

        if [ "$key_perms" = "600" ]; then
            print_check "pass" "CA private key has secure permissions (600)" "SECTION_12_RESULTS"
        else
            print_check "warn" "CA private key permissions: $key_perms (should be 600)" "SECTION_12_RESULTS"
        fi
    else
        status=1
    fi

    # Check CA certificate distribution to volumes
    local distributed_count=0
    local expected_count=10  # 10 services

    for service in superlink postgres keycloak jupyterhub nginx supernode-{1..5}; do
        if [ -f "${PROJECT_ROOT}/volumes/certificates/${service}/ca.crt" ]; then
            ((distributed_count++))
        fi
    done

    if [ "$distributed_count" -eq "$expected_count" ]; then
        print_check "pass" "CA certificate distributed to all service volumes ($distributed_count/$expected_count)" "SECTION_12_RESULTS"
    elif [ "$distributed_count" -gt 0 ]; then
        print_check "warn" "CA certificate partially distributed ($distributed_count/$expected_count)" "SECTION_12_RESULTS"
    else
        print_check "fail" "CA certificate not distributed to service volumes" "SECTION_12_RESULTS"
        status=1
    fi

    return $status
}

#######################################
# Validate a single service certificate
# Arguments:
#   $1 - Service name
#######################################
validate_service_certificate() {
    local service_name=$1
    local cert_path="${PROJECT_ROOT}/volumes/certificates/${service_name}/${service_name}.crt"
    local key_path="${PROJECT_ROOT}/volumes/certificates/${service_name}/${service_name}.key"
    local ca_path="${PROJECT_ROOT}/volumes/certificates/${service_name}/ca.crt"
    local status=0

    # Check certificate exists
    if [ ! -f "$cert_path" ]; then
        print_check "fail" "${service_name}: Certificate missing" "SECTION_13_RESULTS"
        return 1
    fi

    # Check private key exists
    if [ ! -f "$key_path" ]; then
        print_check "fail" "${service_name}: Private key missing" "SECTION_13_RESULTS"
        return 1
    fi

    # Check CA cert exists
    if [ ! -f "$ca_path" ]; then
        print_check "fail" "${service_name}: CA certificate missing" "SECTION_13_RESULTS"
        return 1
    fi

    # All files exist
    print_check "pass" "${service_name}: All certificate files exist" "SECTION_13_RESULTS"

    # Check certificate validity
    if ! openssl x509 -in "$cert_path" -noout -checkend 0 > /dev/null 2>&1; then
        print_check "fail" "${service_name}: Certificate is invalid or expired" "SECTION_13_RESULTS"
        return 1
    fi

    # Check certificate expiry (warn if < 90 days)
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate | sed 's/notAfter=//')
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null)
    local current_epoch
    current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [ "$days_until_expiry" -lt 30 ]; then
        print_check "fail" "${service_name}: Certificate expires in $days_until_expiry days" "SECTION_13_RESULTS"
        return 1
    elif [ "$days_until_expiry" -lt 90 ]; then
        print_check "warn" "${service_name}: Certificate expires in $days_until_expiry days" "SECTION_13_RESULTS"
    else
        print_check "pass" "${service_name}: Certificate valid for $days_until_expiry days" "SECTION_13_RESULTS"
    fi

    # Check for SANs
    if openssl x509 -in "$cert_path" -noout -text 2>/dev/null | grep -q "Subject Alternative Name"; then
        print_check "pass" "${service_name}: Subject Alternative Names present" "SECTION_13_RESULTS"
    else
        print_check "fail" "${service_name}: Subject Alternative Names missing" "SECTION_13_RESULTS"
        status=1
    fi

    # Check certificate chain
    if openssl verify -CAfile "$ca_path" "$cert_path" > /dev/null 2>&1; then
        print_check "pass" "${service_name}: Certificate chain is valid" "SECTION_13_RESULTS"
    else
        print_check "fail" "${service_name}: Certificate chain verification failed" "SECTION_13_RESULTS"
        status=1
    fi

    # Check permissions
    local cert_perms
    cert_perms=$(stat -c "%a" "$cert_path" 2>/dev/null || stat -f "%OLp" "$cert_path" 2>/dev/null)
    local key_perms
    key_perms=$(stat -c "%a" "$key_path" 2>/dev/null || stat -f "%OLp" "$key_path" 2>/dev/null)

    if [ "$cert_perms" != "644" ]; then
        print_check "warn" "${service_name}: Certificate permissions $cert_perms (expected 644)" "SECTION_13_RESULTS"
    fi

    if [ "$key_perms" != "600" ]; then
        print_check "fail" "${service_name}: Private key permissions $key_perms (expected 600)" "SECTION_13_RESULTS"
        status=1
    else
        print_check "pass" "${service_name}: Private key has secure permissions (600)" "SECTION_13_RESULTS"
    fi

    return $status
}

#######################################
# Validate Section 1.3: Service Certificates
#######################################
validate_section_13() {
    print_section_header "Section 1.3: Service Certificate Generation"

    local status=0

    # Check certificate generation script
    if [ -x "${PROJECT_ROOT}/scripts/generate_service_cert.sh" ]; then
        print_check "pass" "Certificate generation script exists and is executable" "SECTION_13_RESULTS"
    else
        print_check "fail" "Certificate generation script missing or not executable" "SECTION_13_RESULTS"
        status=1
    fi

    # Check verification script
    if [ -x "${PROJECT_ROOT}/scripts/verify_certificates.sh" ]; then
        print_check "pass" "Certificate verification script exists and is executable" "SECTION_13_RESULTS"
    else
        print_check "warn" "Certificate verification script missing or not executable" "SECTION_13_RESULTS"
    fi

    # Validate each service certificate
    print_message "$CYAN" ""
    print_message "$CYAN" "Validating individual service certificates:"
    print_message "$CYAN" ""

    local services=(
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

    for service in "${services[@]}"; do
        if ! validate_service_certificate "$service"; then
            status=1
        fi
    done

    return $status
}

#######################################
# Generate markdown report
#######################################
generate_report() {
    if [ "$GENERATE_REPORT" = false ]; then
        return 0
    fi

    print_message "$CYAN" "Generating validation report: $REPORT_FILE"

    cat > "$REPORT_FILE" << EOF
# Phase 1 Validation Report

**Project**: Federated Learning Infrastructure
**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Location**: \`$PROJECT_ROOT\`

## Summary

- **Total Checks**: $TOTAL_CHECKS
- **Passed**: $PASSED_CHECKS
- **Failed**: $FAILED_CHECKS
- **Warnings**: $WARNING_CHECKS

**Overall Status**: $([ "$FAILED_CHECKS" -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")

---

## Section 1.1: Project Structure Setup

EOF

    # Add Section 1.1 results
    for result in "${SECTION_11_RESULTS[@]}"; do
        IFS='|' read -r status message <<< "$result"
        case $status in
            pass) echo "- ✅ $message" >> "$REPORT_FILE" ;;
            fail) echo "- ❌ $message" >> "$REPORT_FILE" ;;
            warn) echo "- ⚠️ $message" >> "$REPORT_FILE" ;;
        esac
    done

    cat >> "$REPORT_FILE" << EOF

---

## Section 1.2: Certificate Authority Setup

EOF

    # Add Section 1.2 results
    for result in "${SECTION_12_RESULTS[@]}"; do
        IFS='|' read -r status message <<< "$result"
        case $status in
            pass) echo "- ✅ $message" >> "$REPORT_FILE" ;;
            fail) echo "- ❌ $message" >> "$REPORT_FILE" ;;
            warn) echo "- ⚠️ $message" >> "$REPORT_FILE" ;;
        esac
    done

    cat >> "$REPORT_FILE" << EOF

---

## Section 1.3: Service Certificate Generation

EOF

    # Add Section 1.3 results
    for result in "${SECTION_13_RESULTS[@]}"; do
        IFS='|' read -r status message <<< "$result"
        case $status in
            pass) echo "- ✅ $message" >> "$REPORT_FILE" ;;
            fail) echo "- ❌ $message" >> "$REPORT_FILE" ;;
            warn) echo "- ⚠️ $message" >> "$REPORT_FILE" ;;
        esac
    done

    cat >> "$REPORT_FILE" << EOF

---

## Next Steps

EOF

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        cat >> "$REPORT_FILE" << EOF
Phase 1 is complete! You can proceed to Phase 2:

1. Review the validation results above
2. Address any warnings if necessary
3. Proceed to Phase 2: Network Configuration
4. Run \`validate_phase2.sh\` when Phase 2 is complete

EOF
    else
        cat >> "$REPORT_FILE" << EOF
Phase 1 has $FAILED_CHECKS failed checks. Please address the following:

1. Review the failed checks above
2. Fix the identified issues
3. Re-run this validation script
4. Ensure all checks pass before proceeding to Phase 2

### Common Issues and Solutions

- **Missing directories**: Run the setup scripts from the implementation plan
- **CA not initialized**: Run \`cd ca && ./easyrsa build-ca\`
- **Missing certificates**: Run \`./scripts/generate_all_certs.sh\`
- **Invalid permissions**: Run \`chmod 600\` on private keys, \`chmod 644\` on certificates

EOF
    fi

    cat >> "$REPORT_FILE" << EOF
---

**Report Generated**: $(date '+%Y-%m-%d %H:%M:%S')
**Validation Script**: \`$0\`
EOF

    print_message "$GREEN" "✓ Report generated: $REPORT_FILE"
}

#######################################
# Display summary
#######################################
display_summary() {
    print_section_header "Validation Summary"

    print_message "$CYAN" "Total Checks: $TOTAL_CHECKS"
    print_message "$GREEN" "Passed: $PASSED_CHECKS"
    print_message "$RED" "Failed: $FAILED_CHECKS"
    print_message "$YELLOW" "Warnings: $WARNING_CHECKS"

    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        if [ "$WARNING_CHECKS" -eq 0 ]; then
            print_message "$GREEN" "════════════════════════════════════════"
            print_message "$GREEN" "✓ Phase 1 Validation: PASSED"
            print_message "$GREEN" "════════════════════════════════════════"
            print_message "$GREEN" ""
            print_message "$GREEN" "All Phase 1 requirements are complete!"
            print_message "$GREEN" "You can proceed to Phase 2."
        else
            print_message "$YELLOW" "════════════════════════════════════════"
            print_message "$YELLOW" "⚠ Phase 1 Validation: PASSED (with warnings)"
            print_message "$YELLOW" "════════════════════════════════════════"
            print_message "$YELLOW" ""
            print_message "$YELLOW" "Phase 1 is complete, but there are $WARNING_CHECKS warnings."
            print_message "$YELLOW" "Review warnings before proceeding to Phase 2."
        fi
        return 0
    else
        print_message "$RED" "════════════════════════════════════════"
        print_message "$RED" "✗ Phase 1 Validation: FAILED"
        print_message "$RED" "════════════════════════════════════════"
        print_message "$RED" ""
        print_message "$RED" "Phase 1 has $FAILED_CHECKS failed checks."
        print_message "$RED" "Please address the issues before proceeding."
        return 1
    fi
}

#######################################
# Print usage information
#######################################
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Comprehensive Phase 1 validation for Federated Learning infrastructure.

This script validates:
  - Section 1.1: Project Structure Setup
  - Section 1.2: Certificate Authority Setup
  - Section 1.3: Service Certificate Generation

Options:
  --report <filename>    Generate markdown report (default: phase1_validation_report.md)
  --no-report           Don't generate a report file
  -h, --help            Show this help message

Examples:
  $(basename "$0")                              # Validate and generate report
  $(basename "$0") --no-report                  # Validate without report
  $(basename "$0") --report custom_report.md    # Custom report filename

Exit Codes:
  0 - Phase 1 complete and validated
  1 - Phase 1 incomplete or validation failed

Environment:
  PROJECT_ROOT: $PROJECT_ROOT
  SCRIPT_DIR:   $SCRIPT_DIR
EOF
    exit 0
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --report)
                GENERATE_REPORT=true
                if [ -n "${2:-}" ] && [[ ! "$2" =~ ^-- ]]; then
                    REPORT_FILE="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            --no-report)
                GENERATE_REPORT=false
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
# Main execution
#######################################
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Display banner
    print_message "$GREEN" "════════════════════════════════════════"
    print_message "$GREEN" "  Phase 1 Validation Script"
    print_message "$GREEN" "  Federated Learning Infrastructure"
    print_message "$GREEN" "════════════════════════════════════════"
    echo ""
    print_message "$CYAN" "Project Root: $PROJECT_ROOT"
    print_message "$CYAN" "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Run validations
    local overall_status=0

    if ! validate_section_11; then
        overall_status=1
    fi

    if ! validate_section_12; then
        overall_status=1
    fi

    if ! validate_section_13; then
        overall_status=1
    fi

    # Generate report
    echo ""
    generate_report

    # Display summary
    echo ""
    if ! display_summary; then
        overall_status=1
    fi

    exit $overall_status
}

# Run main function
main "$@"
