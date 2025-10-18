# Quick Reference Guide

A cheat sheet for common developer tasks and file locations.

## File Locations Quick Lookup

### Application Code

| What | Where |
|------|-------|
| Main FL app (simulation) | `fl-simulation-app/fl_simulation_app/` |
| Quick start app (Docker) | `quickstart-docker/quickstart_docker/` |
| Model definition | `fl-simulation-app/fl_simulation_app/task.py` |
| Client logic | `fl-simulation-app/fl_simulation_app/client_app.py` |
| Server aggregation | `fl-simulation-app/fl_simulation_app/server_app.py` |

### Configuration & Setup

| What | Where |
|------|-------|
| Project dependencies | `fl-simulation-app/pyproject.toml` |
| Keycloak config | `configs/keycloak/` |
| Monitoring config | `configs/monitoring/` |
| VPN config | `configs/vpn/` |
| CA certificates | `certificates/ca/` |
| Server certificates | `certificates/server/` |
| Client certificates | `certificates/clients/` |

### Testing

| What | Where |
|------|-------|
| Unit tests | `tests/unit/` |
| Integration tests | `tests/integration/` |
| Security tests | `tests/security/` |

### Documentation

| What | Where |
|------|-------|
| Project overview | `docs/README.md` |
| Folder structure | `docs/FOLDER_ARCHITECTURE.md` |
| Project tree | `docs/PROJECT_TREE.txt` |
| Setup guides | `docs/setup/` |
| How-to guides | `docs/guides/` |
| FL concepts | `docs/concepts/` |
| Architecture docs | `docs/architecture/` |
| Project status | `docs/project-status/` |
| Planning docs | `docs/planning/` |

### Scripts

| What | Where |
|------|-------|
| Deployment scripts | `scripts/deploy/` |
| Setup scripts | `scripts/setup/` |
| Test scripts | `scripts/tests/` |

### Monitoring

| What | Where |
|------|-------|
| Prometheus config | `monitoring/prometheus/` |
| Grafana dashboards | `monitoring/grafana/dashboards/` |

---

## Common Tasks Cheat Sheet

### Setting Up Development Environment

```bash
# Clone repository (if needed)
cd /home/ghost/workspace/internship_project/flower_fl_simulation

# Activate virtual environment
source .fl_venv/bin/activate

# Install dependencies
cd fl-simulation-app
pip install -e .
```

### Running the Application

```bash
# Simulation mode (fast local testing)
cd fl-simulation-app
flwr run .

# Deployment mode (requires infrastructure)
cd fl-simulation-app
flwr run . --deployment

# Docker quickstart
cd quickstart-docker
flwr run .
```

### Running Tests

```bash
# All tests
pytest tests/

# Unit tests only
pytest tests/unit/

# Integration tests
pytest tests/integration/

# Security tests
pytest tests/security/

# With coverage
pytest --cov=. tests/

# Verbose output
pytest -v tests/
```

### Working with Git

```bash
# Check status
git status

# See current branch
git branch

# Create new branch for feature
git checkout -b feature/your-feature-name

# Add and commit changes
git add .
git commit -m "Your descriptive message"

# Push to remote
git push origin feature/your-feature-name
```

### Certificate Management

```bash
# Generate CA certificate
cd certificates/ca
# (See docs/setup/certificates-README.md for details)

# Generate server certificate
cd ../server
# (See docs/setup/certificates-README.md for details)

# Generate client certificate
cd ../clients
# (See docs/setup/certificates-README.md for details)
```

### Docker Operations

```bash
# Build Dockerfile
cd quickstart-docker
docker build -f superexec.Dockerfile -t fl-quickstart .

# Run container
docker run -it fl-quickstart

# View logs
docker logs <container_id>

# List containers
docker ps -a
```

### Code Changes Workflow

```bash
# 1. Create feature branch
git checkout -b feature/your-feature

# 2. Make changes to code
# - Update application in fl-simulation-app/
# - Add tests in tests/
# - Update docs in docs/

# 3. Run tests locally
pytest tests/ --cov=.

# 4. Commit changes
git add .
git commit -m "Descriptive message"

# 5. Push and create PR
git push origin feature/your-feature
# Then create PR on GitHub
```

### Documentation Changes Workflow

```bash
# 1. Create or edit documentation file
vi docs/guides/new-guide.md

# 2. Update main docs index
vi docs/README.md
# Add link to new documentation

# 3. Commit changes
git add docs/
git commit -m "docs: Add new guide"

# 4. Push
git push origin feature/branch-name
```

---

## Key Files to Know

### Must-Read for New Developers

1. **docs/FOLDER_ARCHITECTURE.md** - Full project structure guide
2. **docs/README.md** - Documentation index
3. **docs/concepts/federated_learning_brief.md** - FL overview
4. **docs/setup/DOCKER_SETUP_COMPLETE.md** - Infrastructure setup
5. **docs/guides/flower_quickstart_docker.md** - Quick start
6. **fl-simulation-app/README.md** - Main app documentation

### Configuration Files

1. **fl-simulation-app/pyproject.toml** - Main app dependencies
2. **quickstart-docker/pyproject.toml** - Quickstart app dependencies
3. **configs/keycloak/\*** - Authentication
4. **configs/monitoring/\*** - Observability

### Important References

1. **.gitignore** - Files not tracked by git
2. **certificates/.gitignore** - Prevents secret commits
3. **docs/project-status/TASKS_AND_BRANCHES.md** - Current work breakdown

---

## Directory Shortcuts

Add these to your shell aliases for faster navigation:

```bash
# In ~/.bashrc or ~/.zshrc

alias fl="cd /home/ghost/workspace/internship_project/flower_fl_simulation"
alias flapp="cd /home/ghost/workspace/internship_project/flower_fl_simulation/fl-simulation-app"
alias fldocs="cd /home/ghost/workspace/internship_project/flower_fl_simulation/docs"
alias fltest="cd /home/ghost/workspace/internship_project/flower_fl_simulation && pytest tests/"
```

---

## Common Git Branches

Reference from `docs/project-status/TASKS_AND_BRANCHES.md`

| Branch Purpose | Naming Pattern | Example |
|---|---|---|
| Feature development | `feature/description` | `feature/mtls-support` |
| Bug fixes | `bugfix/description` | `bugfix/certificate-validation` |
| Documentation | `docs/description` | `docs/setup-guide` |
| Infrastructure | `infra/description` | `infra/docker-setup` |
| Security | `security/description` | `security/tls-configuration` |

Always branch from `master` unless otherwise specified.

---

## Getting Help

### Documentation First

1. Check relevant guide in `docs/guides/`
2. Search in `docs/README.md` for related topics
3. Look at `docs/concepts/` for understanding FL

### Debugging

1. Check `docs/TROUBLESHOOTING.md` (if it exists)
2. Review test files in `tests/` for examples
3. Check component README files
4. Look for similar code patterns in the codebase

### Configuration Issues

1. Review `configs/` for examples
2. Check `docs/setup/` for setup procedures
3. Review environment variables in documentation
4. Look for `.example` or template files

### Certificate Issues

1. See `docs/setup/certificates-README.md`
2. Check certificate files in `certificates/`
3. Verify `.gitignore` rules aren't hiding files

---

## Important Reminders

**DO:**
- Update documentation when changing code
- Write tests for new features
- Use descriptive commit messages
- Check `.gitignore` before committing
- Test locally before pushing

**DON'T:**
- Commit private keys or secrets
- Modify `.gitignore` to expose secrets
- Skip test writing for new features
- Push directly to `master` branch
- Commit large binary files without LFS

---

## Quick File Checklist

Before committing, verify:

- [ ] All tests pass: `pytest tests/`
- [ ] Code follows project style
- [ ] Documentation is updated: `docs/README.md`
- [ ] No secrets in commit: `git diff --cached | grep -i password`
- [ ] `.gitignore` entries are present for generated files
- [ ] Commit message is descriptive
- [ ] Related files are included (code + tests + docs)

---

## Version Information

- **Updated:** October 18, 2025
- **Flower Framework:** Check `fl-simulation-app/pyproject.toml`
- **Python Version:** 3.12 (see `.fl_venv/`)
- **Project Type:** Federated Learning Infrastructure

---

## Additional Resources

- [Flower Documentation](https://flower.ai/docs/)
- [Federated Learning Concepts](docs/concepts/)
- [Project Status](docs/project-status/PROJECT_STATUS_SUMMARY.md)
- [Complete Folder Guide](docs/FOLDER_ARCHITECTURE.md)
