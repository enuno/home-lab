# Vibe Coding Standards - Home Lab Infrastructure

This document explains the comprehensive vibe coding files and standards established for your home lab infrastructure development projects.

## 📋 Table of Contents

- [Overview](#overview)
- [File Inventory](#file-inventory)
- [Quick Start](#quick-start)
- [AI Assistant Configuration](#ai-assistant-configuration)
- [Code Quality Tools](#code-quality-tools)
- [Development Workflow](#development-workflow)
- [Tool-Specific Guides](#tool-specific-guides)
- [Maintenance](#maintenance)

## 🎯 Overview

This project implements production-grade development standards optimized for home lab rapid experimentation. The configuration files establish:

- **Consistent coding standards** across all tools and languages
- **AI assistant context** for better code generation
- **Automated quality checks** via pre-commit hooks and linters
- **Production patterns** for HA, load balancing, and caching
- **Version management** using latest stable releases

### Core Philosophy

```
Security: Permissive for experimentation
Patterns: Production-grade architecture
Versions: Latest stable, no deprecated features
Approach: Infrastructure as Code with version control
```

## 📁 File Inventory

### AI Assistant Configuration

| File | Purpose | Tool |
|------|---------|------|
| `.clinerules/` | Markdown rules for Cline AI assistant | [Cline](https://github.com/cline/cline) |
| `.cursor/rules/homelab.mdc` | MDC rules for Cursor IDE | [Cursor](https://cursor.sh) |
| `.aider.conf.yml` | YAML config for Aider pair programmer | [Aider](https://aider.chat) |
| `Claude.md` | Project context for Claude AI | Claude Projects |
| `GEMINI_RULES.md` | Guidelines for Google Gemini | [Gemini](https://gemini.google.com) |

### Code Quality & Linting

| File | Purpose | Tool |
|------|---------|------|
| `.prettierrc` | JavaScript/TypeScript/JSON formatting | [Prettier](https://prettier.io) |
| `.eslintrc.js` | JavaScript/TypeScript linting | [ESLint](https://eslint.org) |
| `.yamllint` | YAML file linting | [yamllint](https://yamllint.readthedocs.io) |
| `.tflint.hcl` | Terraform linting and validation | [TFLint](https://github.com/terraform-linters/tflint) |
| `pyproject.toml` | Python tooling (Black, Ruff, MyPy, Pytest) | Multiple |

### Infrastructure & Automation

| File | Purpose | Tool |
|------|---------|------|
| `ansible.cfg` | Ansible configuration | [Ansible](https://www.ansible.com) |
| `Makefile` | Common task automation | Make |
| `.pre-commit-config.yaml` | Automated pre-commit checks | [pre-commit](https://pre-commit.com) |

### Editor & Environment

| File | Purpose | Tool |
|------|---------|------|
| `.editorconfig` | Cross-editor consistency | [EditorConfig](https://editorconfig.org) |
| `.gitignore` | Git ignore patterns | Git |
| `.dockerignore` | Docker build exclusions | Docker |

## 🚀 Quick Start

### 1. Install Required Tools

```bash
# Python tools
pip install --upgrade pip
pip install ansible==12.1.0 ansible-core==2.19.3
pip install black ruff mypy pytest pre-commit
pip install ansible-lint yamllint bandit

# Node.js tools (if using JavaScript)
npm install -g prettier eslint

# Infrastructure tools
# Install Terraform 1.13.3: https://www.terraform.io/downloads
# Install kubectl 1.34.x: https://kubernetes.io/docs/tasks/tools/
# Install Docker: https://docs.docker.com/get-docker/
```

### 2. Initialize Pre-commit Hooks

```bash
# Install pre-commit hooks
pre-commit install

# Run once to set up
pre-commit run --all-files
```

### 3. Verify Setup

```bash
# Check tool versions
make version

# Check all tools installed
make check-tools

# Run all linters
make lint
```

### 4. Configure AI Assistants

#### Cline (VS Code Extension)
- Files automatically loaded from `.clinerules/` directory
- Toggle rules via UI in Cline sidebar
- Use `/newrule` command to create additional rules

#### Cursor IDE
- Rules in `.cursor/rules/` automatically detected
- Access via Cursor Settings > Rules
- Can have multiple rule files for different contexts

#### Aider
```bash
# Config automatically loaded from .aider.conf.yml
aider --help  # Verify configuration

# Start coding session
aider src/main.py
```

#### Claude Projects
- Create new project in Claude
- Upload `Claude.md` as project documentation
- Reference in conversations for context

#### Google Gemini
- Reference `GEMINI_RULES.md` in conversations
- Copy relevant sections for specific tasks

## 🤖 AI Assistant Configuration

### Current Tool Versions (October 2025)

```yaml
Terraform: 1.13.3
Ansible Core: 2.19.3
Ansible Community: 12.1.0
Kubernetes: 1.34.x
Python: 3.11+
Docker: Latest stable
```

### AI Context Best Practices

1. **Start with context**: Reference project goals and constraints
2. **Specify environment**: Dev/staging/prod, resource constraints
3. **Version requirements**: Always mention current versions
4. **Pattern preferences**: HA, load balancing, caching needs
5. **Security level**: Home lab permissive vs. production strict

### Example AI Prompts

```markdown
**Good Prompt:**
"Create a Terraform module for deploying a highly available PostgreSQL
cluster on AWS using the latest Terraform 1.13 syntax. Include:
- Multi-AZ deployment with automatic failover
- Patroni for HA coordination
- HAProxy for load balancing
- Proper resource tagging
- Production-grade monitoring hooks"

**Less Effective:**
"Make a postgres cluster"
```

## 🔧 Code Quality Tools

### Automatic Formatting

```bash
# Format all code
make format

# Format specific types
make format-terraform
make format-python
```

### Linting

```bash
# Run all linters
make lint

# Run specific linters
make lint-terraform
make lint-ansible
make lint-k8s
make lint-docker
make lint-python
```

### Pre-commit Hooks

Pre-commit hooks run automatically on `git commit`:

- Trailing whitespace removal
- End-of-file fixer
- YAML/JSON validation
- Python formatting (Black, Ruff)
- Terraform formatting
- Ansible linting
- Security scanning (detect-secrets)
- And more...

**Bypass hooks temporarily** (use sparingly):
```bash
git commit --no-verify -m "WIP: debugging"
```

## 🔄 Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/new-infrastructure
```

### 2. Write Code with AI Assistant

Use appropriate AI assistant with project context:
- Cline: Interactive coding in VS Code
- Cursor: IDE with AI autocomplete
- Aider: Command-line pair programming
- Claude: Planning and architecture
- Gemini: Code review and optimization

### 3. Automated Quality Checks

```bash
# Pre-commit hooks run automatically
git add .
git commit -m "feat: add new infrastructure component"

# Or run checks manually
make lint
make test
```

### 4. Test Changes

```bash
# Terraform
make tf-init ENVIRONMENT=dev
make tf-plan ENVIRONMENT=dev
make tf-apply ENVIRONMENT=dev

# Ansible
make ansible-check
make ansible-run

# Kubernetes
make k8s-validate
make k8s-apply ENVIRONMENT=dev
```

### 5. Create Pull Request

- Pre-commit hooks ensure code quality
- CI/CD runs additional checks
- AI-generated code follows established patterns

## 🛠️ Tool-Specific Guides

### Terraform

**Best Practices:**
- Use `for_each` over `count`
- Pin provider versions with `~>`
- Implement lifecycle rules
- Tag all resources
- Use remote state

**Commands:**
```bash
make tf-init ENVIRONMENT=prod
make tf-plan ENVIRONMENT=prod
make tf-apply ENVIRONMENT=prod
make tf-validate
make tf-docs
```

### Ansible

**Best Practices:**
- Use FQCN for all modules
- Implement idempotency
- Use blocks for error handling
- Tag tasks appropriately
- Vault sensitive data

**Quick Start:**
```bash
cd ansible/

# Set up vault password
echo "your-secure-password" > .vault_password
chmod 600 .vault_password

# Test connectivity
ansible -i inventory/k3s-cluster.ini k3s_cluster -m ping

# Deploy K3s cluster
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml
```

**Common Commands:**
```bash
# Run with tags
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags master,worker

# Check mode (dry run)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --check

# Limit to specific hosts
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --limit k3s-workers

# Verbose output
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml -vv
```

**📖 For detailed Ansible documentation, see [ansible/README.md](ansible/README.md)**

Topics covered in the Ansible README:
- Complete Ansible Vault setup and usage
- Running playbooks with tags and limits
- Available playbooks and roles
- Troubleshooting guide
- Post-deployment verification
- Best practices and maintenance

### Kubernetes

**Best Practices:**
- Define resource limits
- Implement health checks
- Use specific image tags
- Namespace isolation
- ConfigMaps for configuration

**Commands:**
```bash
make k8s-validate
make k8s-apply ENVIRONMENT=prod
make k8s-status
make k8s-diff
```

### Docker

**Best Practices:**
- Multi-stage builds
- Run as non-root user
- Specific image tags
- Include HEALTHCHECK
- Minimal base images

**Commands:**
```bash
make docker-build
make docker-push
make docker-compose-up
make docker-compose-down
```

## 🔐 Security Considerations

### Secrets Management

**Never commit:**
- API keys, tokens, passwords
- SSL certificates and private keys
- Cloud provider credentials
- SSH private keys
- Vault password files (`.vault_password`)

**Use instead:**
- **Ansible Vault** for Ansible secrets (recommended for this project)
- Environment variables via `.env` files (gitignored)
- Cloud provider secret managers (AWS Secrets Manager, GCP Secret Manager)
- SOPS for encrypted config files
- HashiCorp Vault for advanced secret management

**Ansible Vault Quick Reference:**
```bash
# Create encrypted file
ansible-vault create group_vars/secrets.yml

# Edit encrypted file
ansible-vault edit group_vars/secrets.yml

# View encrypted file
ansible-vault view group_vars/secrets.yml

# Encrypt existing file
ansible-vault encrypt group_vars/plain_secrets.yml

# Decrypt file
ansible-vault decrypt group_vars/secrets.yml

# Change vault password
ansible-vault rekey group_vars/secrets.yml
```

**Vault Password File Setup:**
```bash
# Create vault password file (already configured in ansible.cfg)
echo "your-secure-password" > ansible/.vault_password
chmod 600 ansible/.vault_password

# The file is automatically used by Ansible
# No need to specify --vault-password-file flag
```

**Best Practices for Vault:**
1. Use strong vault passwords (16+ characters, mixed case, numbers, symbols)
2. Store vault password securely (password manager, environment variable)
3. Use separate vault files for different environments (dev, staging, prod)
4. Prefix vault variables with `vault_` for easy identification
5. Reference vault variables in regular group_vars files
6. Never commit `.vault_password` files to version control
7. Rotate vault passwords periodically (use `ansible-vault rekey`)

### Pre-commit Security Checks

- `detect-secrets`: Scan for leaked credentials
- `bandit`: Python security analysis
- `trivy`: Container vulnerability scanning
- `tfsec`: Terraform security scanning

## 📊 Monitoring & Observability

All infrastructure code should include:

1. **Health checks**: Liveness and readiness probes
2. **Metrics**: Prometheus-compatible endpoints
3. **Logging**: Structured logging with correlation IDs
4. **Tracing**: Distributed tracing where applicable
5. **Alerting**: Alert definitions for critical issues

## 🔄 Maintenance

### Update Tool Versions

```bash
# Check for updates
pip list --outdated
npm outdated

# Update Python packages
pip install --upgrade ansible ansible-core black ruff

# Update Node packages
npm update -g

# Update pre-commit hooks
pre-commit autoupdate
```

### Deprecation Tracking

Monitor for deprecated features:

**Terraform:**
- Check release notes for deprecations
- Run `terraform validate` regularly
- Review TFLint warnings

**Ansible:**
- Check for deprecation warnings in playbook runs
- Use `ansible-lint` to catch deprecated syntax
- Review Ansible changelog

**Kubernetes:**
- Monitor API version deprecations
- Use `kubectl convert` for API migrations
- Check deprecation warnings in `kubectl`

### Version Updates

When updating major versions:

1. Read changelog and migration guide
2. Update version constraints in configs
3. Test in dev environment
4. Update documentation
5. Deploy to staging
6. Deploy to production

## 📚 Additional Resources

### Official Documentation

- [Terraform Docs](https://developer.hashicorp.com/terraform)
- [Ansible Docs](https://docs.ansible.com)
- [Kubernetes Docs](https://kubernetes.io/docs)
- [Docker Docs](https://docs.docker.com)

### Community Resources

- [r/homelab](https://reddit.com/r/homelab)
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [Awesome Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted)
- [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)

### AI Assistant Documentation

- [Cline Documentation](https://docs.cline.bot)
- [Cursor Documentation](https://docs.cursor.com)
- [Aider Documentation](https://aider.chat/docs)
- [Claude Projects Guide](https://support.anthropic.com/en/articles/9517075-what-are-projects)

## 🤝 Contributing

When contributing to projects using these standards:

1. Follow established patterns
2. Run linters before committing
3. Update documentation with changes
4. Test in isolated environment first
5. Use conventional commit messages

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:** feat, fix, docs, style, refactor, test, chore

**Example:**
```
feat(terraform): add highly available PostgreSQL module

- Implemented multi-AZ deployment
- Added Patroni for automatic failover
- Configured HAProxy load balancer
- Added comprehensive monitoring

Closes #123
```

## 📞 Support

For questions or issues:

1. Check documentation in `docs/` directory
2. Review runbooks in `docs/runbooks/`
3. Consult AI assistants with project context
4. Search community forums
5. Create issue with detailed information

---

**Remember:** These standards balance production-grade patterns with home lab flexibility. Prioritize learning and experimentation while maintaining code quality and documentation.
