# Federated Learning Infrastructure Evaluation Project Plan

## Project Overview
This project focuses on evaluating the Flower Federated Learning (FL) framework within the National Infrastructure for Secure Federated Learning (NINA). The intern will set up a local test environment, run sample federated learning workflows, and evaluate security and operational mechanisms such as VPN connections, mTLS certificates, and role-based authentication (Keycloak).

The goal is to provide insights into infrastructure readiness and security risks when scaling to multiple organizations and sensitive health datasets.

## Project Duration
- **Start Date:** 2025-09-30
- **End Date:** 2025-12-06
- **Duration:** 10 weeks (~10 hours per week)

## Key Objectives
1. **Install and configure** a local Flower federated learning environment (server + clients)
2. **Run initial federated learning experiments** using synthetic datasets
3. **Test VPN, certificate management, and authentication mechanisms**
4. **Identify performance and security bottlenecks**
5. **Recommend improvements** for deployment workflows and documentation

## Project Justification
Secure federated learning allows machine learning models to be trained on sensitive medical data without transferring the data outside institutional boundaries. QCIF is deploying a production-grade FL environment, and this internship will:
- Validate deployment steps and documentation
- Identify risks in security and operational procedures
- Provide reproducible local setup instructions for development and testing

## Scope

### In Scope:
- Flower local setup and testing
- VPN and mTLS certificate configuration
- Simulated data experiments
- Documentation review and improvement

### Out of Scope:
- Integration with live medical datasets
- Full production automation
- Organisation-specific security audits

## How to Accomplish the Project

### Phase 1: Setup and Learning (Weeks 1-3)
1. **Week 1: Orientation & Learning**
   - Orientation to QCIF systems and secure FL project
   - Review FL operations manual and documentation
   - Set up accounts and access (SharePoint, 1Password)
   - Initial reading and tutorials on Flower and federated learning concepts

2. **Week 2: Local Environment Setup**
   - Set up local Python environment
   - Install Flower and dependencies
   - Run basic local Python test scripts

3. **Week 3: Local Flower Deployment**
   - Configure Flower server (superlink) locally
   - Deploy at least two Flower clients (supernodes)
   - Run a basic federated learning job with synthetic data

### Phase 2: Security Implementation (Weeks 4-6)
4. **Week 4: Security Foundations**
   - Set up local certificate authority (EasyRSA)
   - Configure mutual TLS between server and clients
   - Document key generation process

5. **Week 5: VPN Setup & Testing**
   - Configure OpenVPN server and client connections
   - Test secure connectivity between federated nodes
   - Validate firewall rules and port access (e.g., 9091-9099)

6. **Week 6: Keycloak Integration**
   - Install Keycloak and configure realms for user access
   - Integrate Flower server with Keycloak for OIDC authentication

### Phase 3: Testing and Evaluation (Weeks 7-8)
7. **Week 7: Scaling & Performance Testing**
   - Add additional simulated clients
   - Document scaling challenges

8. **Week 8: Security Evaluation**
   - Identify gaps in current security controls
   - Draft preliminary recommendations

### Phase 4: Documentation and Finalization (Weeks 9-10)
9. **Week 9: Draft Documentation**
   - Update QCIF documentation on setup and testing
   - Prepare initial report for feedback

10. **Week 10: Finalisation**
    - Finalise report and recommendations
    - Deliver handover presentation
    - Share final scripts and documentation

## Technical Components

### System Model
The system consists of:
- **Researcher**: Trusted user with access to the interface layer
- **Nectar**: Nectar research cloud infrastructure supported by QCIF and ARDC
- **Interface**: The only point through which the researcher transfers project files
- **IAM**: Identity and Access Management services
- **Superlink**: Coordinator during the training process
- **Supernodes**: On-premise execution nodes
- **Datasets**: Secure data at participating organizations

### Network Deployment
- Hybrid cloud deployment with aggregation server (superlink) hosted in Nectar cloud
- Training nodes (supernodes) hosted on client premises
- Interconnectivity via Virtual Private Network (VPN)
- Separate network segments with firewall filtering

### Security Mechanisms
- Multi-layer security approach
- Network segmentation with firewalls
- SSL certificates for authentication
- Transport layer security for data in transit
- Mutual authentication between components
- Role-based access control through Keycloak

## Expected Deliverables
- Working local Flower test setup with documentation
- Scripts and configuration files for automated setup
- Report on security evaluation (VPN, certificates, Keycloak)
- Recommendations for production deployment improvements
- Final presentation and handover to QCIF team

## Success Measures
- Fully functional local Flower test environment with server and multiple clients
- Documented procedures for VPN, certificates, and authentication setup
- Clear recommendations for production rollout
- Final report and presentation accepted by QCIF