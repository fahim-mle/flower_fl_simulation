#!/bin/bash

# National Federated Learning Infrastructure - Phase 1 Validation Script
# Version: 1.0
# Date: 2025-07-01

set -euo pipefail

# Configuration variables
CA_DIR="/opt/national-fl-ca"
DOMAIN="nationalfl.org.au"

# Network configurations
INTERNAL_NETWORK_NAME="internal-network"
VPN_NETWORK_NAME="vpn-network"
PUBLIC_SG_NAME="public-security-group"
INTERNAL_SG_NAME="internal-security-group"
VPN_SG_NAME="vpn-security-group"
ROUTER_NAME="fl-router"

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

# Validation results
VALIDATION_PASSED=0
VALIDATION_FAILED=0

# Track validation results
validation_result() {
    local test_name=$1
    local result=$2
    local message=${3:-""}

    if [[ "$result" == "PASS" ]]; then
        log_info "✓ PASS: ${test_name}"
        ((VALIDATION_PASSED++))
    else
        log_error "✗ FAIL: ${test_name}"
        if [[ -n "$message" ]]; then
            log_error "  ${message}"
        fi
        ((VALIDATION_FAILED++))
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if file exists and is readable
file_exists() {
    [[ -f "$1" && -r "$1" ]]
}

# Check if directory exists
directory_exists() {
    [[ -d "$1" ]]
}

# Validate Certificate Authority setup
validate_certificate_authority() {
    log "Validating Certificate Authority setup..."

    # Check CA directory structure
    if directory_exists "${CA_DIR}"; then
        validation_result "CA Directory exists" "PASS"
    else
        validation_result "CA Directory exists" "FAIL" "CA directory ${CA_DIR} not found"
        # return 1
    fi

    # Check CA certificate
    if file_exists "${CA_DIR}/pki/ca.crt"; then
        validation_result "CA Certificate exists" "PASS"

        # Validate CA certificate
        if openssl x509 -in "${CA_DIR}/pki/ca.crt" -text -noout &> /dev/null; then
            validation_result "CA Certificate is valid" "PASS"
        else
            validation_result "CA Certificate is valid" "FAIL" "CA certificate is invalid or corrupted"
        fi
    else
        validation_result "CA Certificate exists" "FAIL" "CA certificate not found at ${CA_DIR}/pki/ca.crt"
    fi

    # Check server certificates
    local server_certs=("vpn-server" "superlink" "keycloak" "jupyterhub" "grafana" "prometheus" "postgresql")
    for cert in "${server_certs[@]}"; do
        if file_exists "${CA_DIR}/certs/${cert}.crt" && file_exists "${CA_DIR}/private/${cert}.key"; then
            validation_result "Server certificate for ${cert}" "PASS"

            # Validate certificate
            if openssl x509 -in "${CA_DIR}/certs/${cert}.crt" -text -noout &> /dev/null; then
                validation_result "${cert} certificate is valid" "PASS"
            else
                validation_result "${cert} certificate is valid" "FAIL" "${cert} certificate is invalid"
            fi
        else
            validation_result "Server certificate for ${cert}" "FAIL" "Certificate or key not found for ${cert}"
        fi
    done

    # Check client certificates
    local client_certs=("org1-supernode" "org2-supernode" "org3-supernode")
    for cert in "${client_certs[@]}"; do
        if file_exists "${CA_DIR}/certs/${cert}.crt" && file_exists "${CA_DIR}/private/${cert}.key"; then
            validation_result "Client certificate for ${cert}" "PASS"
        else
            validation_result "Client certificate for ${cert}" "FAIL" "Certificate or key not found for ${cert}"
        fi
    done

    # Check OpenVPN parameters
    if file_exists "${CA_DIR}/certs/dh.pem" && file_exists "${CA_DIR}/certs/ta.key"; then
        validation_result "OpenVPN parameters exist" "PASS"
    else
        validation_result "OpenVPN parameters exist" "FAIL" "DH parameters or TA key not found"
    fi

    # Check distribution packages
    if directory_exists "${CA_DIR}/distribute"; then
        validation_result "Distribution packages directory exists" "PASS"

        # Check server packages
        local package_count=$(find "${CA_DIR}/distribute" -name "*-certs.tar.gz" | wc -l)
        if [[ $package_count -ge 7 ]]; then
            validation_result "Server distribution packages created" "PASS" "Found ${package_count} packages"
        else
            validation_result "Server distribution packages created" "FAIL" "Expected at least 7 packages, found ${package_count}"
        fi
    else
        validation_result "Distribution packages directory exists" "FAIL" "Distribution directory not found"
    fi

    # Check management scripts
    local scripts=("renew-cert.sh" "revoke-cert.sh" "list-certs.sh")
    for script in "${scripts[@]}"; do
        if file_exists "${CA_DIR}/scripts/${script}" && [[ -x "${CA_DIR}/scripts/${script}" ]]; then
            validation_result "Management script ${script}" "PASS"
        else
            validation_result "Management script ${script}" "FAIL" "Script not found or not executable"
        fi
    done
}

# Validate network topology setup
validate_network_topology() {
    log "Validating network topology setup..."

    # Check if OpenStack CLI is available
    if command_exists openstack; then
        validation_result "OpenStack CLI available" "PASS"

        # Check if OpenStack is authenticated
        if openstack token issue &> /dev/null; then
            validation_result "OpenStack authenticated" "PASS"

            # Check networks
            local networks=("${INTERNAL_NETWORK_NAME}" "${VPN_NETWORK_NAME}")
            for network in "${networks[@]}"; do
                if openstack network show "${network}" &> /dev/null; then
                    validation_result "Network ${network} exists" "PASS"

                    # Check subnet
                    if openstack subnet show "${network}-subnet" &> /dev/null; then
                        validation_result "Subnet for ${network} exists" "PASS"
                    else
                        validation_result "Subnet for ${network} exists" "FAIL" "Subnet not found for ${network}"
                    fi
                else
                    validation_result "Network ${network} exists" "FAIL" "Network ${network} not found"
                fi
            done

            # Check security groups
            local security_groups=("${PUBLIC_SG_NAME}" "${INTERNAL_SG_NAME}" "${VPN_SG_NAME}")
            for sg in "${security_groups[@]}"; do
                if openstack security group show "${sg}" &> /dev/null; then
                    validation_result "Security group ${sg} exists" "PASS"

                    # Check security group rules
                    local rule_count=$(openstack security group rule list "${sg}" -f value | wc -l)
                    if [[ $rule_count -gt 2 ]]; then  # More than just default egress rules
                        validation_result "Security group ${sg} has rules" "PASS" "Found ${rule_count} rules"
                    else
                        validation_result "Security group ${sg} has rules" "FAIL" "No rules found for ${sg}"
                    fi
                else
                    validation_result "Security group ${sg} exists" "FAIL" "Security group ${sg} not found"
                fi
            done

            # Check router
            if openstack router show "${ROUTER_NAME}" &> /dev/null; then
                validation_result "Router ${ROUTER_NAME} exists" "PASS"

                # Check router interfaces
                local interface_count=$(openstack router show "${ROUTER_NAME}" -f json | jq -r '.interfaces_info | length' 2>/dev/null || echo "0")
                if [[ $interface_count -ge 2 ]]; then
                    validation_result "Router has interfaces" "PASS" "Found ${interface_count} interfaces"
                else
                    validation_result "Router has interfaces" "FAIL" "Router has insufficient interfaces"
                fi
            else
                validation_result "Router ${ROUTER_NAME} exists" "FAIL" "Router not found"
            fi

            # Check floating IPs
            if [[ -f "floating-ips.txt" ]]; then
                local fip_count=$(wc -l < floating-ips.txt)
                if [[ $fip_count -ge 2 ]]; then
                    validation_result "Floating IPs allocated" "PASS" "Found ${fip_count} floating IPs"
                else
                    validation_result "Floating IPs allocated" "FAIL" "Insufficient floating IPs allocated"
                fi
            else
                validation_result "Floating IPs allocated" "FAIL" "Floating IPs file not found"
            fi

        else
            validation_result "OpenStack authenticated" "FAIL" "OpenStack credentials not configured"
        fi
    else
        validation_result "OpenStack CLI available" "FAIL" "OpenStack CLI not installed"
        log_warning "Network topology validation requires OpenStack CLI"
    fi
}

# Validate documentation
validate_documentation() {
    log "Validating documentation..."

    # Check Phase 1 documentation
    if file_exists "docs/phase-1-infrastructure-setup.md"; then
        validation_result "Phase 1 infrastructure documentation exists" "PASS"
    else
        validation_result "Phase 1 infrastructure documentation exists" "FAIL" "Documentation not found"
    fi

    # Check network topology documentation
    if file_exists "docs/network-topology.md"; then
        validation_result "Network topology documentation exists" "PASS"
    else
        validation_result "Network topology documentation exists" "FAIL" "Network documentation not found"
    fi

    # Check CA documentation
    if file_exists "${CA_DIR}/README.md"; then
        validation_result "CA documentation exists" "PASS"
    else
        validation_result "CA documentation exists" "FAIL" "CA README not found"
    fi

    # Check tasklist
    if file_exists "FL_FLWR_OPS_TASKLIST.md"; then
        validation_result "Project tasklist exists" "PASS"
    else
        validation_result "Project tasklist exists" "FAIL" "Tasklist not found"
    fi
}

# Validate security configurations
validate_security() {
    log "Validating security configurations..."

    # Check CA directory permissions
    if [[ -d "${CA_DIR}" ]]; then
        local ca_perms=$(stat -c "%a" "${CA_DIR}" 2>/dev/null || echo "000")
        if [[ "$ca_perms" == "755" ]]; then
            validation_result "CA directory permissions" "PASS" "Permissions: ${ca_perms}"
        else
            validation_result "CA directory permissions" "FAIL" "Expected 755, found ${ca_perms}"
        fi

        # Check private directory permissions
        if [[ -d "${CA_DIR}/private" ]]; then
            local private_perms=$(stat -c "%a" "${CA_DIR}/private" 2>/dev/null || echo "000")
            if [[ "$private_perms" == "700" ]]; then
                validation_result "Private directory permissions" "PASS" "Permissions: ${private_perms}"
            else
                validation_result "Private directory permissions" "FAIL" "Expected 700, found ${private_perms}"
            fi
        fi

        # Check private key permissions
        local key_perms_ok=true
        for key_file in "${CA_DIR}/private"/*.key; do
            if [[ -f "$key_file" ]]; then
                local key_perms=$(stat -c "%a" "$key_file" 2>/dev/null || echo "000")
                if [[ "$key_perms" != "600" ]]; then
                    validation_result "Private key permissions" "FAIL" "Key $(basename "$key_file") has ${key_perms}, expected 600"
                    key_perms_ok=false
                fi
            fi
        done

        if [[ "$key_perms_ok" == true ]]; then
            validation_result "Private key permissions" "PASS" "All private keys have 600 permissions"
        fi
    fi

    # Check script permissions
    local scripts=("${CA_DIR}/scripts"/*.sh)
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                validation_result "Script $(basename "$script") executable" "PASS"
            else
                validation_result "Script $(basename "$script") executable" "FAIL" "Script is not executable"
            fi
        fi
    done
}

# Generate validation report
generate_validation_report() {
    log "Generating validation report..."

    local total_tests=$((VALIDATION_PASSED + VALIDATION_FAILED))
    local pass_rate=0

    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$((VALIDATION_PASSED * 100 / total_tests))
    fi

    cat > validation-report.md << EOF
# Phase 1 Validation Report

## Summary
- **Total Tests**: ${total_tests}
- **Passed**: ${VALIDATION_PASSED}
- **Failed**: ${VALIDATION_FAILED}
- **Pass Rate**: ${pass_rate}%

## Validation Date
$(date)

## Components Validated

### Certificate Authority
- CA directory structure and permissions
- CA certificate validity
- Server certificates generation and validity
- Client certificates generation
- OpenVPN parameters
- Distribution packages
- Management scripts

### Network Topology
- OpenStack CLI availability and authentication
- Network creation and configuration
- Subnet configuration
- Security group creation and rules
- Router configuration
- Floating IP allocation

### Documentation
- Phase 1 infrastructure setup documentation
- Network topology documentation
- CA documentation
- Project tasklist

### Security Configuration
- Directory permissions
- Private key permissions
- Script executability

## Status
EOF

    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        echo "✅ **ALL VALIDATIONS PASSED**" >> validation-report.md
        echo "" >> validation-report.md
        echo "Phase 1 infrastructure setup is complete and ready for Phase 2 deployment." >> validation-report.md
    else
        echo "❌ **SOME VALIDATIONS FAILED**" >> validation-report.md
        echo "" >> validation-report.md
        echo "Please address the failed validations before proceeding to Phase 2." >> validation-report.md
    fi

    cat >> validation-report.md << EOF

## Recommendations
EOF

    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        cat >> validation-report.md << EOF
- Proceed to Phase 2: Server-Side Deployment
- Begin with operating system preparation on all VM instances
- Continue with service deployment in the recommended order
- Maintain documentation throughout the deployment process
EOF
    else
        cat >> validation-report.md << EOF
- Review and fix failed validation items
- Re-run this validation script after fixes
- Ensure all security requirements are met
- Complete documentation before proceeding
EOF
    fi

    log "Validation report generated: validation-report.md"
}

# Main validation function
main() {
    log "Starting Phase 1 validation for National Federated Learning Infrastructure"
    log "Validation date: $(date)"
    log ""

    # Run all validations
    validate_certificate_authority
    echo ""
    validate_network_topology
    echo ""
    validate_documentation
    echo ""
    validate_security
    echo ""

    # Generate report
    generate_validation_report

    # Final summary
    local total_tests=$((VALIDATION_PASSED + VALIDATION_FAILED))
    local pass_rate=0

    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$((VALIDATION_PASSED * 100 / total_tests))
    fi

    log "Validation completed!"
    log_info "Total Tests: ${total_tests}"
    log_info "Passed: ${VALIDATION_PASSED}"
    log_info "Failed: ${VALIDATION_FAILED}"
    log_info "Pass Rate: ${pass_rate}%"

    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        log "🎉 All validations passed! Phase 1 is complete."
        log_info "You can now proceed to Phase 2: Server-Side Deployment"
        return 0
    else
        log_error "❌ ${VALIDATION_FAILED} validation(s) failed."
        log_error "Please review the validation report and fix the issues before proceeding."
        return 1
    fi
}

# Check if running with appropriate privileges
if [[ $EUID -ne 0 ]] && [[ -d "${CA_DIR}" ]]; then
    log_warning "Some validations may require root privileges for CA directory access"
    log_warning "Consider running with sudo for complete validation"
fi

# Run main function
main "$@"
