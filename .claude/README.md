# Claude Code Custom Agents and Commands for Home Lab Infrastructure

> **Custom AI agents and slash commands for Terraform, Ansible, and home lab infrastructure development**

[![Home Lab](https://img.shields.io/badge/Home-Lab-blue.svg)]()
[![Terraform](https://img.shields.io/badge/Terraform-1.13.3-purple.svg)]()
[![Ansible](https://img.shields.io/badge/Ansible-2.19.3-red.svg)]()
[![Claude](https://img.shields.io/badge/Claude-Code-orange.svg)]()

---

## 📚 Overview

This directory contains custom Claude Code agents and commands specifically designed for home lab infrastructure development, including:

- **Terraform** infrastructure as code
- **Ansible** automation and configuration management
- **Kubernetes** manifest deployment
- **Bitwarden Secrets Manager** migration from Ansible Vault
- **Infrastructure validation** and quality assurance

All agents and commands follow best practices from [claude-command-and-control](../docs/claude/) and are tailored to this project's specific needs documented in `CLAUDE.md` and `DEVELOPMENT_PLAN.md`.

---

## 🤖 Custom Agents

Custom agents are specialized AI configurations for focused infrastructure tasks.

### Terraform-Architect

**Role**: Terraform Infrastructure Architect
**File**: [`agents/terraform-architect.md`](agents/terraform-architect.md)

**Capabilities**:
- Design Terraform module architecture
- Create infrastructure resources (compute, network, storage)
- Implement HA patterns (multi-AZ, load balancing, failover)
- Manage Terraform state and workspaces
- Security best practices (least privilege, encryption)
- Cost optimization for home lab constraints

**Use When**:
- Planning new infrastructure components
- Creating Terraform modules
- Designing high-availability architecture
- Optimizing resource usage
- Reviewing infrastructure security

**Example**:
```
Please design a Terraform module for a highly available K3s cluster
with 3 master nodes and 2 worker nodes on Proxmox.
```

---

### Ansible-DevOps

**Role**: Ansible Automation Engineer
**File**: [`agents/ansible-devops.md`](agents/ansible-devops.md)

**Capabilities**:
- Create idempotent Ansible playbooks
- Design reusable Ansible roles
- Implement Bitwarden Secrets Manager integration
- Assist with Ansible Vault to Bitwarden migration
- Manage multi-environment deployments (dev/staging/prod)
- Test playbooks with Molecule

**Use When**:
- Writing new Ansible playbooks
- Creating Ansible roles
- Migrating secrets to Bitwarden
- Configuring services across multiple hosts
- Implementing configuration management

**Example**:
```
Create an Ansible playbook to deploy Pi-hole with Bitwarden secrets
integration, following our project conventions.
```

---

### Infra-Validator

**Role**: Infrastructure Validation Specialist
**File**: [`agents/infra-validator.md`](agents/infra-validator.md)

**Capabilities**:
- Validate Terraform code (format, syntax, lint, security)
- Check Ansible playbooks (syntax, lint, YAML)
- Validate Kubernetes manifests
- Security scanning (tfsec, bandit)
- Generate comprehensive validation reports
- Enforce quality gates

**Use When**:
- Before committing code
- Before creating pull requests
- Validating infrastructure changes
- Security auditing
- Ensuring code quality standards

**Example**:
```
Validate all Terraform modules and Ansible playbooks, then generate
a comprehensive quality report.
```

---

## ⚡ Custom Commands

Custom slash commands automate common infrastructure workflows.

### /tf-validate

**Purpose**: Comprehensive Terraform validation
**File**: [`commands/tf-validate.md`](commands/tf-validate.md)

**What it Does**:
1. Format checking (`terraform fmt`)
2. Syntax validation (`terraform validate`)
3. Linting (`tflint`)
4. Security scanning (`tfsec`)
5. Documentation generation (`terraform-docs`)
6. Generate validation report

**Usage**:
```
/tf-validate
```

**Requirements**:
- terraform >= 1.13.3
- tflint (recommended)
- tfsec (recommended)
- terraform-docs (recommended)

**Output**:
- Console summary
- `TERRAFORM_VALIDATION_REPORT.md`
- `tfsec-report.json`

---

### /ansible-validate

**Purpose**: Comprehensive Ansible validation
**File**: [`commands/ansible-validate.md`](commands/ansible-validate.md)

**What it Does**:
1. Syntax checking (all playbooks)
2. YAML linting (`yamllint`)
3. Ansible linting (`ansible-lint`)
4. Inventory validation
5. Vault security checks
6. Bitwarden integration verification
7. Generate validation report

**Usage**:
```
/ansible-validate
```

**Requirements**:
- ansible-core >= 2.19.3
- ansible-lint (recommended)
- yamllint (recommended)
- bitwarden.secrets collection

**Output**:
- Console summary
- `ANSIBLE_VALIDATION_REPORT.md`

---

### /vault-migrate

**Purpose**: Ansible Vault to Bitwarden migration assistant
**File**: [`commands/vault-migrate.md`](commands/vault-migrate.md)

**What it Does**:
1. Assess current migration status
2. Inventory vault secrets
3. Export secrets for Bitwarden import
4. Update playbooks with Bitwarden lookups
5. Test Bitwarden secret retrieval
6. Remove vault fallback (after validation)
7. Archive vault files

**Usage**:
```
/vault-migrate
```

**Interactive Menu**:
- Inventory vault secrets
- Update playbooks
- Test Bitwarden lookups
- Track migration progress

**Context**:
- Follows 16-week migration plan from `DEVELOPMENT_PLAN.md`
- Supports parallel operation (Bitwarden + Vault fallback)
- Validates before deprecating Vault

---

### /infra-deploy

**Purpose**: Orchestrated infrastructure deployment
**File**: [`commands/infra-deploy.md`](commands/infra-deploy.md)

**What it Does**:
1. Pre-deployment validation
2. Environment selection (dev/staging/prod)
3. Terraform planning and apply
4. Ansible configuration deployment
5. Kubernetes manifest application
6. Post-deployment verification
7. Generate deployment report

**Usage**:
```
/infra-deploy
```

**Deployment Types**:
1. Full Stack (Terraform + Ansible + K8s)
2. Infrastructure Only (Terraform)
3. Configuration Only (Ansible)
4. Kubernetes Manifests Only
5. Single Service
6. Validation Dry-Run

**Safety Features**:
- Validation gates block failed deploys
- Manual approval required per phase
- Dry-run before actual execution
- Post-deployment health checks
- Complete audit trail

---

## 🚀 Quick Start Guide

### 1. Verify Installation

```bash
# Check if agents and commands are in place
ls -la .claude/agents/
ls -la .claude/commands/

# Agents should include:
# - terraform-architect.md
# - ansible-devops.md
# - infra-validator.md

# Commands should include:
# - tf-validate.md
# - ansible-validate.md
# - vault-migrate.md
# - infra-deploy.md
```

### 2. Install Required Tools

```bash
# Terraform
brew install terraform  # macOS
# Or download from https://www.terraform.io/downloads

# Ansible
pip install ansible==12.1.0 ansible-core==2.19.3

# Validation tools
brew install tflint tfsec terraform-docs  # macOS
pip install ansible-lint yamllint

# Bitwarden CLI (for vault migration)
# Follow: https://bitwarden.com/help/secrets-manager-cli/

# Bitwarden Ansible collection
ansible-galaxy collection install bitwarden.secrets
```

### 3. Typical Development Workflow

```bash
# Start coding session
/start-session

# Make infrastructure changes...
# (Edit Terraform files, Ansible playbooks)

# Validate changes
/tf-validate
/ansible-validate

# If migrating secrets
/vault-migrate

# Deploy infrastructure
/infra-deploy

# Close session
/close-session
```

---

## 📖 Usage Examples

### Example 1: New Terraform Module

```markdown
**User**: Create a Terraform module for deploying HAProxy load balancers

**Agent** (terraform-architect):
I'll design a Terraform module for highly available HAProxy load balancers.

[Agent creates module structure, implements resources, adds HA configuration]

**User**: /tf-validate

[Validation runs, reports success]

**User**: /infra-deploy
# Select: Infrastructure Only (Terraform)
# Select: staging environment
# Review and approve
```

### Example 2: New Ansible Playbook

```markdown
**User**: Write an Ansible playbook to deploy Rancher with Bitwarden secrets

**Agent** (ansible-devops):
I'll create a playbook following our Bitwarden integration patterns.

[Agent creates playbook with Bitwarden lookups, handlers, validation]

**User**: /ansible-validate

[Validation checks syntax, linting, secrets]

**User**: /infra-deploy
# Select: Configuration Only (Ansible)
# Select: dev environment
# Review and approve
```

### Example 3: Vault Migration

```markdown
**User**: /vault-migrate

[Interactive menu appears]

**User**: Select: 2. Export vault secrets for Bitwarden import

[Decrypts vault files, generates inventory]

**User**: Select: 3. Update playbook to use Bitwarden lookup

[Guides through playbook update process]

**User**: /ansible-validate

[Verifies Bitwarden integration]

**User**: Select: 4. Test Bitwarden lookup

[Tests secret retrieval and playbook execution]
```

### Example 4: Full Stack Deployment

```markdown
**User**: /infra-deploy

[Menu: Select Full Stack deployment]
[Menu: Select prod environment]

[Phase 1: Validation - All checks pass]
[Phase 2: Terraform - Plan reviewed and approved]
[Phase 3: Ansible - Check mode reviewed and approved]
[Phase 4: Kubernetes - Manifests reviewed and approved]
[Phase 5: Verification - All health checks pass]

[Deployment report generated]
```

---

## 🔧 Configuration

### Agent Configuration

Agents are defined in `.claude/agents/` and automatically loaded by Claude Code. No additional configuration needed.

**Customization**:
- Edit agent files to adjust capabilities
- Modify `allowed-tools` to change permissions
- Update workflow patterns for project-specific needs

### Command Configuration

Commands are defined in `.claude/commands/` and available as `/command-name`.

**Customization**:
- Edit command files to modify workflow
- Adjust `allowed-tools` for security
- Update validation criteria

### Project-Specific Context

Agents and commands automatically load context from:
- `CLAUDE.md` - Project standards and tool versions
- `DEVELOPMENT_PLAN.md` - Migration plans and phases
- `README.md` - Repository structure and guidelines
- `AGENTS.md` - Agent integration standards

---

## 🛡️ Security Considerations

### Secrets Management

**Never commit**:
- `.vault_password` files
- Decrypted vault files
- `BWS_ACCESS_TOKEN` values
- Plaintext passwords or API keys

**Always**:
- Use `no_log: true` for secret-handling tasks
- Encrypt vault files with `ansible-vault encrypt`
- Use Bitwarden lookups for new secrets
- Create `.template` files for vault structure

### Tool Permissions

Commands have restricted `allowed-tools`:
- Validation commands: READ-ONLY access
- Deployment commands: Approval gates for writes
- Migration commands: Secure temp file handling

### Quality Gates

Must-pass before deployment:
- ✅ Valid syntax (Terraform, Ansible)
- ✅ No critical security issues
- ✅ No secrets in commits

---

## 📊 Quality Standards

This project follows **staging/pre-production** quality level:

### Must-Pass (Blocking)
- ❌ No secrets in commits
- ❌ Valid Terraform/Ansible syntax
- ❌ Valid YAML syntax
- ❌ Critical security issues resolved

### Should-Pass (Warnings OK)
- ⚠️ Linting suggestions
- ⚠️ Documentation gaps (fix before merge)
- ⚠️ Performance optimizations

### Can Skip for WIP
- Use `git commit --no-verify` for work-in-progress
- Document why in commit message
- Fix before final merge

---

## 🔄 Integration with CI/CD

These agents and commands integrate with GitHub Actions:

```yaml
# Example: .github/workflows/validate.yml
name: Validate Infrastructure

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Terraform Validation
        run: |
          # Equivalent to /tf-validate
          terraform fmt -check -recursive
          terraform validate
          tflint --recursive
          tfsec .

      - name: Ansible Validation
        run: |
          # Equivalent to /ansible-validate
          ansible-playbook playbooks/*.yml --syntax-check
          ansible-lint
          yamllint .
```

---

## 🆘 Troubleshooting

### Common Issues

**"Command not found"**
- Ensure files are in `.claude/commands/`
- Check file has `.md` extension
- Restart Claude Code

**"Permission denied"**
- Check `allowed-tools` in command frontmatter
- Review security restrictions

**"Validation failed"**
- Run `/tf-validate` or `/ansible-validate` for details
- Fix issues before deploying
- Check pre-commit hooks

**"Bitwarden authentication failed"**
- Set `BWS_ACCESS_TOKEN` environment variable
- Verify machine account token is valid
- Check Bitwarden collection installed

---

## 📚 Additional Resources

### Documentation
- [CLAUDE.md](../CLAUDE.md) - Project context and standards
- [DEVELOPMENT_PLAN.md](../DEVELOPMENT_PLAN.md) - Bitwarden migration plan
- [README.md](../README.md) - Repository overview
- [docs/claude/](../docs/claude/) - Command and Control manual

### Tools
- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [Ansible Documentation](https://docs.ansible.com)
- [Bitwarden Secrets Manager](https://bitwarden.com/help/secrets-manager/)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)

### Community
- [r/homelab](https://reddit.com/r/homelab)
- [r/selfhosted](https://reddit.com/r/selfhosted)

---

## 🤝 Contributing

When contributing to agents and commands:

1. Follow [claude-command-and-control](../docs/claude/) standards
2. Test thoroughly in development environment
3. Update documentation
4. Use conventional commit messages
5. Create PR with clear description

---

## 📝 Change Log

### Version 1.0.0 (2025-11-21)
- Initial creation of custom agents:
  - terraform-architect
  - ansible-devops
  - infra-validator
- Initial creation of custom commands:
  - /tf-validate
  - /ansible-validate
  - /vault-migrate
  - /infra-deploy
- Documentation and usage examples

---

## 📞 Support

For questions or issues:

1. Check this README
2. Review agent/command files directly
3. Consult [docs/claude/](../docs/claude/) manual
4. Check project `CLAUDE.md` for context

---

**Version**: 1.0.0
**Last Updated**: 2025-11-21
**Maintained By**: Home Lab Infrastructure Team
**Status**: ✅ Production Ready

---

**Built with ❤️ using Claude Code for home lab infrastructure automation**
