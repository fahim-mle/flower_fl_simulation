# Project Folder Architecture Guide

This document provides a comprehensive overview of the Flower Federated Learning Infrastructure project directory structure, explaining the purpose of each folder and how the project is organized.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Root Level Structure](#root-level-structure)
3. [Detailed Directory Guide](#detailed-directory-guide)
4. [File Placement Guidelines](#file-placement-guidelines)
5. [Quick Reference](#quick-reference)

---

## Project Overview

The Flower Federated Learning Infrastructure Evaluation project is a comprehensive federated learning implementation built on the Flower framework. It includes multiple applications, monitoring infrastructure, security certificates, configuration management, and extensive documentation.

**Project Root:** `/home/ghost/workspace/internship_project/flower_fl_simulation/`

---

## Root Level Structure

```
flower_fl_simulation/
├── .claude/                      # AI Agent configurations
├── .git/                         # Git version control
├── .gitignore                    # Git ignore patterns
├── certificates/                 # TLS/mTLS certificates
├── configs/                      # Configuration files
├── docs/                         # All documentation
├── fl-simulation-app/            # Main Flower application (simulation runtime)
├── monitoring/                   # Monitoring infrastructure (Prometheus/Grafana)
├── quickstart-docker/            # Quick start Docker example application
├── scripts/                      # Automation and utility scripts
├── tests/                        # Test suites
├── .fl_venv/                     # Python virtual environment (excluded from versioning)
├── final_model.pt               # Trained PyTorch model artifact
└── README.md                     # (Currently not present - root entry point)
```

---

## Detailed Directory Guide

### 1. `.claude/` - AI Agent Configurations

**Purpose:** Configuration files for Claude AI agents used in the project development process.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/.claude/`

**Structure:**
```
.claude/
├── agents/
│   ├── claude.md                # Main Claude agent
│   ├── devops.md                # DevOps/Infrastructure agent
│   ├── docs.md                  # Documentation specialist agent
│   ├── docker-expert.md         # Docker expertise agent
│   ├── fl-expert.md             # Federated learning expert agent
│   ├── project-orchestrator.md  # Project orchestration agent
│   └── security.md              # Security specialist agent
```

**When to use:**
- Reference for understanding project roles and responsibilities
- Configuration for collaborative development workflows
- Not typically modified by end users

---

### 2. `certificates/` - TLS and mTLS Certificates

**Purpose:** Storage for SSL/TLS certificates required for secure communication between Flower components (SuperLink, SuperNodes, and clients).

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/certificates/`

**Structure:**
```
certificates/
├── .gitignore                   # Prevent accidental certificate commits
├── .gitkeep                     # Placeholder for empty directories
├── ca/                          # Certificate Authority files
│   ├── ca.crt                   # CA certificate
│   └── ca.key                   # CA private key
├── server/                      # Server (SuperLink/SuperNode) certificates
│   ├── server.crt               # Server certificate
│   ├── server.csr               # Certificate signing request
│   └── server.key               # Server private key
└── clients/                     # Client certificates
    ├── client1.crt              # Client certificate
    ├── client1.csr              # Client CSR
    └── client1.key              # Client private key
```

**Key Files:**
- `ca.crt` - CA certificate (public, safe to commit)
- `ca.key` - CA key (PRIVATE, never commit)
- `server.crt`, `server.key` - SuperLink/SuperNode credentials
- `client*.crt`, `client*.key` - Individual client credentials

**Guidelines:**
- Keep `.gitignore` updated to prevent secret leaks
- Use for secure communication in both simulation and deployment modes
- Reference documentation: `docs/setup/certificates-README.md`
- **Never commit private keys to the repository**

---

### 3. `configs/` - Configuration Files

**Purpose:** Centralized configuration storage for different infrastructure components.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/configs/`

**Structure:**
```
configs/
├── .gitkeep                     # Placeholder
├── keycloak/                    # Authentication configuration
│   └── (Keycloak config files)
├── monitoring/                  # Monitoring configuration
│   └── (Prometheus/Grafana configs)
└── vpn/                         # VPN setup configuration
    └── (VPN configuration files)
```

**When to add files:**
- Keycloak authentication settings (keycloak/)
- Prometheus scrape configurations (monitoring/)
- VPN connection profiles (vpn/)
- Environment-specific settings
- Database connection strings (non-sensitive)

**Best Practices:**
- Keep sensitive values in environment variables
- Use `.env` files with `.gitignore` for local secrets
- Document all required configuration parameters
- Provide example/template files (e.g., `config.example.yml`)

---

### 4. `docs/` - Documentation Hub

**Purpose:** Central repository for all project documentation.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/docs/`

**Structure:**
```
docs/
├── README.md                    # Documentation index and quick links
├── FOLDER_ARCHITECTURE.md       # This file - project structure guide
├── architecture/                # System architecture documentation
│   ├── (Architecture diagrams and documentation)
│   └── (Component interaction details)
├── concepts/                    # Federated learning concepts
│   ├── federated_learning_brief.md
│   └── federated_learning_explanation.md
├── guides/                      # How-to guides and tutorials
│   └── flower_quickstart_docker.md
├── planning/                    # Project planning documents
│   ├── plan_and_how_to_accomplish_project.md
│   ├── 01413.5_FL_Internship_Plan_10_Weeks.txt
│   └── FL_FLWR_OPS.txt
├── project-status/              # Current project status
│   ├── PROJECT_STATUS_SUMMARY.md
│   ├── PROJECT_STRUCTURE.md
│   └── TASKS_AND_BRANCHES.md
└── setup/                       # Installation and setup guides
    ├── DOCKER_SETUP_COMPLETE.md
    └── certificates-README.md
```

**Subdirectory Purposes:**

#### `docs/architecture/`
- System design and architecture diagrams
- Component interaction documentation
- Network topology diagrams
- Data flow visualizations

**When to add:** New architecture documentation, component design docs

#### `docs/concepts/`
- Federated learning theory and concepts
- Algorithm explanations
- Protocol specifications

**When to add:** Educational materials, concept explanations

#### `docs/guides/`
- Step-by-step how-to guides
- Tutorial documentation
- Quick start guides
- Integration guides

**When to add:** New guides for users, deployment tutorials

#### `docs/planning/`
- Project plans and roadmaps
- Internship schedule and objectives
- Historical planning documents
- Operational procedures

**When to add:** Long-term planning, milestones, procedures

#### `docs/project-status/`
- Current project progress
- Task breakdown by week/iteration
- Branch and task mapping
- Status summaries

**When to add:** Regular status updates, task tracking

#### `docs/setup/`
- Installation procedures
- Configuration guides
- System requirements
- Troubleshooting for setup

**When to add:** New setup procedures, installation guides

**Documentation Guidelines:**
- Update `docs/README.md` when adding new documents
- Use descriptive, consistent filenames
- Include date or version information where appropriate
- Link related documents
- Provide table of contents for longer documents

---

### 5. `fl-simulation-app/` - Main Flower Application

**Purpose:** Primary federated learning application demonstrating Flower framework capabilities with PyTorch.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/fl-simulation-app/`

**Structure:**
```
fl-simulation-app/
├── README.md                    # App-specific documentation
├── pyproject.toml               # Project dependencies and configuration
├── .gitignore                   # App-level gitignore
├── final_model.pt              # Trained model checkpoint
├── fl_simulation_app/           # Main source code package
│   ├── __init__.py              # Package initialization
│   ├── client_app.py            # Flower ClientApp definition
│   ├── server_app.py            # Flower ServerApp definition
│   └── task.py                  # FL task definition and model
└── goal_and_documentation/      # App-specific documentation
    └── (Additional docs)
```

**Key Files:**

| File | Purpose |
|------|---------|
| `pyproject.toml` | Defines project name, version, dependencies, and Flower runtime configuration (simulation vs. deployment) |
| `client_app.py` | Implements ClientApp logic - what clients do during federated training |
| `server_app.py` | Implements ServerApp logic - server-side aggregation and coordination |
| `task.py` | Defines model architecture, training logic, and evaluation |
| `final_model.pt` | Saved trained model weights from successful FL runs |

**Running the Application:**

```bash
# Simulation mode (recommended for development)
cd fl-simulation-app
flwr run .

# Deployment mode (requires SuperLink/SuperNode setup)
flwr run . --deployment
```

**When to modify:**
- Update model architecture in `task.py`
- Modify training/evaluation logic
- Adjust client-side FL parameters
- Change server aggregation strategy

**Best Practices:**
- Keep model code separate from FL orchestration
- Use configuration for hyperparameters
- Test locally with simulation runtime first
- Document changes to model or training logic

---

### 6. `monitoring/` - Monitoring Infrastructure

**Purpose:** Prometheus and Grafana configuration for monitoring FL system health and performance.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/monitoring/`

**Structure:**
```
monitoring/
├── .gitkeep                     # Placeholder
├── prometheus/                  # Prometheus monitoring
│   ├── .gitkeep
│   └── (Prometheus configuration files)
└── grafana/                     # Grafana dashboards
    ├── .gitkeep
    └── dashboards/              # Grafana dashboard definitions
        └── (Dashboard JSON files)
```

**When to add files:**
- Prometheus configuration and scrape targets
- Grafana dashboard definitions
- Alert rules
- Custom metrics definitions

**Related Files:**
- Configuration references in `configs/monitoring/`

---

### 7. `quickstart-docker/` - Quick Start Docker Example

**Purpose:** Simplified Flower application with Docker setup for quick learning and prototyping.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/quickstart-docker/`

**Structure:**
```
quickstart-docker/
├── README.md                    # Quick start documentation
├── pyproject.toml               # Project configuration
├── .gitignore                   # Docker-specific ignores
├── superexec.Dockerfile         # Container definition
└── quickstart_docker/           # Application source
    ├── __init__.py
    ├── client_app.py            # Client implementation
    ├── server_app.py            # Server implementation
    └── task.py                  # Task and model definition
```

**Purpose:**
- Learning resource for Flower framework
- Docker containerization example
- Simpler alternative to main fl-simulation-app
- Template for Docker-based FL deployments

**When to use:**
- Getting started with Flower
- Testing Docker containerization
- Creating Docker images for deployment

**Dockerfile Location:**
- `superexec.Dockerfile` - Container image definition

**Documentation:**
- See `docs/guides/flower_quickstart_docker.md` for detailed setup

---

### 8. `scripts/` - Automation and Utility Scripts

**Purpose:** Automation scripts for setup, deployment, and testing.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/scripts/`

**Structure:**
```
scripts/
├── .gitkeep                     # Placeholder
├── deploy/                      # Deployment scripts
│   └── (Deployment automation)
├── setup/                       # Setup and initialization scripts
│   └── (Setup automation)
└── tests/                       # Testing automation scripts
    └── (Test execution scripts)
```

**When to add scripts:**
- Automated deployment procedures
- Environment setup scripts
- Certificate generation scripts
- Docker build/push automation
- CI/CD pipeline scripts
- Data preprocessing scripts

**Best Practices:**
- Use descriptive filenames: `setup-certificates.sh`, `deploy-to-k8s.sh`
- Include error handling and validation
- Document script parameters and usage
- Add shebang line: `#!/bin/bash` or `#!/usr/bin/env python3`
- Make executable: `chmod +x script.sh`
- Include help/usage information

**Example:**
```bash
#!/bin/bash
# scripts/setup/generate-certificates.sh
# Description: Generate TLS certificates for Flower federation

set -e  # Exit on error

# Script body here
```

---

### 9. `tests/` - Test Suites

**Purpose:** Comprehensive testing for the federated learning infrastructure.

**Location:** `/home/ghost/workspace/internship_project/flower_fl_simulation/tests/`

**Structure:**
```
tests/
├── .gitkeep                     # Placeholder
├── unit/                        # Unit tests
│   ├── test_client_app.py       # Client app tests
│   ├── test_server_app.py       # Server app tests
│   └── test_task.py             # Task logic tests
├── integration/                 # Integration tests
│   ├── test_fl_workflow.py      # End-to-end FL workflow
│   └── test_docker_setup.py     # Docker integration tests
└── security/                    # Security tests
    ├── test_certificate_validation.py
    ├── test_mtls_communication.py
    └── test_authentication.py
```

**Test Categories:**

| Type | Purpose | Location |
|------|---------|----------|
| Unit Tests | Test individual components in isolation | `tests/unit/` |
| Integration Tests | Test component interactions and workflows | `tests/integration/` |
| Security Tests | Validate security mechanisms and vulnerabilities | `tests/security/` |

**When to add tests:**
- New features require tests
- Bug fixes should include regression tests
- Critical paths need comprehensive coverage
- Security-related changes need security tests

**Running Tests:**
```bash
# Run all tests
pytest tests/

# Run specific test category
pytest tests/unit/
pytest tests/integration/
pytest tests/security/

# Run with coverage
pytest --cov=. tests/
```

---

### 10. `.fl_venv/` - Python Virtual Environment

**Status:** Excluded from git (see `.gitignore`)

**Purpose:** Isolated Python environment containing project dependencies.

**When to recreate:**
- Initial setup
- Dependency changes
- Python version updates

**Recreation:**
```bash
python3 -m venv .fl_venv
source .fl_venv/bin/activate  # On Linux/Mac
# or
.fl_venv\Scripts\activate     # On Windows

pip install -r requirements.txt
# or
pip install -e .
```

---

### 11. Root Level Files

#### `.gitignore`
**Purpose:** Specifies files and directories excluded from version control.

**Key Exclusions:**
- Python cache files (`__pycache__/`, `*.pyc`)
- Virtual environment (`.fl_venv/`)
- IDE files (`.vscode/`, `.idea/`)
- OS files (`.DS_Store`, `Thumbs.db`)
- AI agent configs (`.claude/`)
- Private certificates (via `certificates/.gitignore`)

**Important:**
- Review before committing sensitive files
- Keep updated as project evolves
- Ensure secrets never reach repository

#### `final_model.pt`
**Purpose:** Trained PyTorch model weights from successful federated learning runs.

**Note:** This is a binary artifact. Consider:
- Using a separate artifacts repository for large files
- Implementing Git LFS for binary management
- Documenting model version and training metadata

---

## File Placement Guidelines

### Where to Put Different File Types

#### Python Source Code
**Location:**
- Application code: `fl-simulation-app/fl_simulation_app/` or `quickstart-docker/quickstart_docker/`
- Utility modules: Create `utils/` subdirectory if needed
- Shared code: Create `shared/` or `common/` module

**Structure:**
```
fl_simulation_app/
├── __init__.py
├── client_app.py      # ClientApp
├── server_app.py      # ServerApp
├── task.py            # Model and training
├── utils/             # Helper functions
│   ├── __init__.py
│   ├── data_loading.py
│   └── preprocessing.py
└── models/            # Model definitions
    ├── __init__.py
    └── neural_net.py
```

#### Configuration Files
**Location:** `configs/` or in application root with `.example` template

**Pattern:**
```
configs/
├── default.yml        # Default configuration
├── production.yml     # Production overrides
└── .gitignore         # Hide sensitive values
```

#### Documentation
**Location:** `docs/` with appropriate subdirectory

**Selection:**
- Architecture docs: `docs/architecture/`
- Tutorials: `docs/guides/`
- Setup instructions: `docs/setup/`
- Project status: `docs/project-status/`

#### Scripts
**Location:** `scripts/` with category subdirectory

**Naming:**
```
scripts/
├── setup/
│   ├── install-dependencies.sh
│   └── setup-certificates.sh
├── deploy/
│   ├── deploy-local.sh
│   └── deploy-docker.sh
└── tests/
    └── run-all-tests.sh
```

#### Tests
**Location:** `tests/` with category subdirectory

**File Naming Convention:** `test_*.py`

```
tests/
├── unit/
│   └── test_model_training.py
├── integration/
│   └── test_federated_workflow.py
└── security/
    └── test_certificate_chain.py
```

#### Certificates
**Location:** `certificates/` with role subdirectory

```
certificates/
├── ca/                # Certification Authority
├── server/            # SuperLink/SuperNode
└── clients/           # FL Clients
```

---

## Quick Reference

### Adding a New Feature

1. **Create feature branch:** Based on the branch strategy in `docs/project-status/TASKS_AND_BRANCHES.md`

2. **Place code:**
   - Source: `fl-simulation-app/fl_simulation_app/`
   - Tests: `tests/unit/` or `tests/integration/`
   - Config: `configs/`

3. **Document:**
   - Add docstrings to code
   - Update relevant docs in `docs/`
   - Update `docs/README.md` if needed

4. **Test:**
   - Write unit tests
   - Run full test suite: `pytest tests/`
   - Test in Docker if applicable

5. **Commit:**
   - Clear, descriptive message
   - Reference related issues

### Adding Documentation

1. **Determine category:**
   - Setup guides: `docs/setup/`
   - How-tos: `docs/guides/`
   - Architecture: `docs/architecture/`
   - Concepts: `docs/concepts/`
   - Status: `docs/project-status/`

2. **Create file:** Use descriptive filename with `.md` extension

3. **Update index:** Add link to `docs/README.md`

4. **Format:**
   - Use Markdown formatting
   - Include table of contents for long docs
   - Add code examples
   - Link to related documents

### Adding Configuration

1. **Create directory:** In `configs/` if category doesn't exist

2. **Use naming:** Descriptive name matching purpose

3. **Add example:** Include `.example` or template version

4. **Document:** Add README explaining configuration options

5. **Secure:** Add `.gitignore` rules for sensitive values

---

## Common Tasks and File Locations

| Task | Primary Directory | Related Directories |
|------|------------------|-------------------|
| Modify model | `fl-simulation-app/fl_simulation_app/task.py` | `tests/unit/` |
| Change client logic | `fl-simulation-app/fl_simulation_app/client_app.py` | `docs/guides/` |
| Add certificates | `certificates/` | `docs/setup/certificates-README.md` |
| Configure monitoring | `configs/monitoring/` | `monitoring/` |
| Set up Docker | `quickstart-docker/` | `docs/guides/flower_quickstart_docker.md` |
| Run experiments | Scripts in `scripts/deploy/` | `fl-simulation-app/` |
| Add tests | `tests/unit/` or `tests/integration/` | Application directory |
| Document feature | Appropriate subdirectory in `docs/` | `docs/README.md` |

---

## Development Workflow

### Typical Developer Journey

1. **Understand project structure** (you are here!)
   - Review this guide
   - Read `docs/README.md`
   - Check project status in `docs/project-status/`

2. **Set up environment**
   - Follow `docs/setup/DOCKER_SETUP_COMPLETE.md`
   - Create certificate if needed: `docs/setup/certificates-README.md`

3. **Work on feature/bug**
   - Make changes in appropriate directory
   - Add tests in `tests/`
   - Update docs if needed

4. **Validate**
   - Run tests locally
   - Test in Docker container
   - Check documentation updates

5. **Submit changes**
   - Create pull request with clear description
   - Reference related issues
   - Request review from maintainers

---

## Version Control Guidelines

### What Gets Committed

**YES - Commit These:**
- Source code (.py files)
- Configuration templates/examples
- Documentation (.md files)
- Test files
- Scripts
- `.gitignore` updates

### What Gets Ignored

**NO - Don't Commit These:**
- `__pycache__/` directories
- `.venv/` or `.fl_venv/`
- IDE files (`.vscode/`, `.idea/`)
- Private certificate keys
- `.env` files with secrets
- `*.pyc` compiled files
- OS files (`.DS_Store`, `Thumbs.db`)
- Model checkpoint files (use separate storage)
- Build artifacts

**Already Configured In:** `/home/ghost/workspace/internship_project/flower_fl_simulation/.gitignore`

---

## Next Steps

1. **Explore Key Directories:**
   - Review `docs/README.md` for documentation index
   - Check `docs/setup/DOCKER_SETUP_COMPLETE.md` for infrastructure details
   - Read `fl-simulation-app/README.md` for application overview

2. **Understand Current Status:**
   - Check `docs/project-status/PROJECT_STATUS_SUMMARY.md`
   - Review `docs/project-status/TASKS_AND_BRANCHES.md` for task breakdown

3. **Get Started:**
   - Follow setup guide in `docs/setup/`
   - Run quickstart app: `docs/guides/flower_quickstart_docker.md`
   - Experiment with `fl-simulation-app/`

4. **Learn Federated Learning:**
   - Start with `docs/concepts/federated_learning_brief.md`
   - Deep dive: `docs/concepts/federated_learning_explanation.md`
   - Review Flower documentation: [flower.ai/docs](https://flower.ai/docs/)

---

## Support and Questions

For questions about:
- **Project structure:** See this guide and `docs/README.md`
- **Setup issues:** Check `docs/setup/` and `docs/guides/`
- **FL concepts:** Review `docs/concepts/`
- **Specific components:** Check component README files
- **Git workflow:** See branch mapping in `docs/project-status/TASKS_AND_BRANCHES.md`

---

## Document Version

- **Last Updated:** October 18, 2025
- **Version:** 1.0
- **Status:** Complete
- **Audience:** Developers, operators, contributors
