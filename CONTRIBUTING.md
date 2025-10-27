# CONTRIBUTING.md — Contributing to Home Lab Infrastructure

## Welcome! 🎉

Thank you for your interest in contributing to this home lab infrastructure project! This guide will help you understand our standards, workflows, and expectations.

## Project Philosophy

This home lab intentionally balances:
- 🎓 **Learning & Experimentation**: Try new technologies, learn from failures
- 🏭 **Production Patterns**: HA, monitoring, security like real infrastructure
- 💰 **Cost Effectiveness**: Optimize for limited resources and budget
- ⚡ **Rapid Iteration**: Fast feedback loops, safe to experiment

**Code Quality Target:** Staging/Pre-Production level
- Secure, functional, and readable
- Not overly strict or enterprise-level bureaucratic
- Warnings acceptable, critical errors must be fixed

## Getting Started

### Prerequisites

**Required Tools:**
```bash
# Core infrastructure tools
terraform  # >= 1.13.3
ansible    # >= 2.19.3
python     # >= 3.11
kubectl    # >= 1.34.x

# Code quality tools
pre-commit
ansible-lint
yamllint
terraform-docs
tflint
tfsec
black
ruff
shellcheck
```

**Install Pre-commit Hooks:**
```bash
# Install pre-commit framework
pip install pre-commit

# Install project hooks
pre-commit install

# (Optional) Install commit-msg hook for conventional commits
pre-commit install --hook-type commit-msg

# Test installation
pre-commit run --all-files
```

### Initial Setup

1. **Fork and Clone Repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/home-lab.git
   cd home-lab
   ```

2. **Create Feature Branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

3. **Set Up Development Environment:**
   ```bash
   # Install Python dependencies
   pip install -r requirements.txt

   # Install Ansible collections
   ansible-galaxy collection install -r requirements.yml

   # Verify tool versions
   make version  # If Makefile exists
   ```

## Code Quality Standards

### Quality Gates

**🔴 Must Pass (Blocking):**
- ❌ No secrets in commits (detect-secrets enforced)
- ❌ Ansible syntax validation
- ❌ Terraform fmt and validate
- ❌ YAML syntax valid
- ❌ Critical security vulnerabilities (HIGH/CRITICAL from tfsec/checkov)
- ❌ No broken functionality in critical paths

**🟡 Should Pass (Warnings OK):**
- ⚠️ Ansible-lint style suggestions
- ⚠️ Terraform tflint best practices
- ⚠️ Documentation completeness
- ⚠️ Performance optimization opportunities
- ⚠️ Minor security improvements (MEDIUM/LOW)

**🟢 Can Skip for WIP:**
- ✅ Use `git commit --no-verify` for work-in-progress
- ✅ Add `WIP:` prefix to commit message
- ✅ Fix all issues before creating pull request

### Pre-commit Hooks

Our pre-commit configuration includes:

**General Quality:**
- Trailing whitespace removal
- End-of-file fixer
- YAML syntax validation
- Large file detection
- Merge conflict detection

**Security:**
- `detect-secrets`: Scan for committed secrets

**Ansible:**
- `ansible-lint`: Moderate profile (not overly strict)
- `yamllint`: Relaxed rules for experimentation

**Terraform:**
- `terraform_fmt`: Automatic formatting
- `terraform_validate`: Syntax validation
- `terraform_docs`: Auto-generate documentation
- `terraform_tflint`: Best practices (warnings, not errors)
- `terraform_tfsec`: Security scanning (HIGH/CRITICAL only)
- `terraform_checkov`: Compliance (HIGH/CRITICAL only)

**Python:**
- `black`: Code formatting (line-length=100)
- `ruff`: Linting (moderate rule set)

**Shell:**
- `shellcheck`: Bash script linting

**Docker:**
- `hadolint`: Dockerfile linting (relaxed rules)

**Markdown:**
- `markdownlint`: Documentation quality

### Running Quality Checks Manually

```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Run specific hook
pre-commit run ansible-lint --all-files
pre-commit run terraform_fmt --all-files

# Ansible validation
ansible-playbook playbook.yml --syntax-check
ansible-playbook playbook.yml --check --diff
ansible-lint playbook.yml

# Terraform validation
terraform fmt -check -recursive
terraform validate
tfsec . --minimum-severity HIGH
checkov -d . --framework terraform

# YAML validation
yamllint .

# Python linting
black --check .
ruff check .
```

## Development Workflow

### 1. Plan Your Changes

- **Check existing issues** for related work
- **Create an issue** to discuss significant changes
- **Review documentation** to understand current architecture

### 2. Make Your Changes

**Ansible Playbooks:**
```yaml
---
# Always use FQCN (Fully Qualified Collection Names)
- name: Install nginx
  ansible.builtin.package:
    name: nginx
    state: present
  tags: [install, nginx]

# Include error handling
- name: Deploy configuration
  block:
    - name: Copy config file
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        validate: 'nginx -t -c %s'
      notify: Reload nginx
  rescue:
    - name: Log error
      ansible.builtin.debug:
        msg: "Configuration deployment failed, rolling back"
  tags: [config]
```

**Terraform Modules:**
```hcl
# Include version constraints
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

# Tag all resources
resource "proxmox_vm_qemu" "web" {
  # ... configuration ...

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "HomeLabAnm"
  }

  # HA lifecycle rules
  lifecycle {
    create_before_destroy = true
  }
}

# Document outputs
output "vm_ip" {
  description = "IP address of the web server VM"
  value       = proxmox_vm_qemu.web.default_ipv4_address
}
```

**Kubernetes Manifests:**
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000

      containers:
      - name: app
        image: registry.local/myapp:v1.2.3  # Specific version!

        # Resource limits required
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        # Health probes required
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
```

### 3. Test Your Changes

**Ansible Testing:**
```bash
# Syntax check
ansible-playbook playbook.yml --syntax-check

# Dry run with check mode
ansible-playbook -i inventory/dev playbook.yml --check --diff

# Test in development environment
ansible-playbook -i inventory/dev playbook.yml --tags test

# Lint playbook
ansible-lint playbook.yml
```

**Terraform Testing:**
```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Review plan before apply
terraform plan -out=tfplan

# Security scanning
tfsec .
checkov -d .

# Generate documentation
terraform-docs markdown . > README.md
```

**Kubernetes Testing:**
```bash
# Dry run
kubectl apply --dry-run=server -f manifest.yml

# Validate manifest
kubeval manifest.yml

# Best practices check
kube-score score manifest.yml
```

### 4. Document Your Changes

**Required Documentation:**

1. **Code Comments:**
   ```yaml
   # Explain WHY, not just WHAT
   - name: Disable SELinux
     # Note: Required for legacy app compatibility.
     # Considered alternatives (containers) but complexity
     # too high for home lab. Trade-off accepted.
     ansible.posix.selinux:
       state: disabled
   ```

2. **README Updates:**
   - Update relevant README.md files
   - Add usage examples for new features
   - Document configuration options
   - Include troubleshooting tips

3. **Changelog Entry:**
   - Add entry to CHANGELOG.md (if exists)
   - Follow semantic versioning
   - Group changes: Added, Changed, Fixed, Removed

### 5. Commit Your Changes

**Commit Message Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, not functional)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Example:**
```bash
git commit -m "feat(ansible): add Bitwarden secrets lookup support

- Implement lookup plugin for Bitwarden Secrets Manager
- Update playbooks to use new secret pattern
- Add documentation for migration from Ansible Vault
- Include error handling for missing secrets

Refs #123"
```

### 6. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create pull request on GitHub
# Include:
# - Clear description of changes
# - Link to related issues
# - Testing performed
# - Screenshots if relevant
```

## Pull Request Review Process

### PR Checklist

Before submitting PR, ensure:

- [ ] Pre-commit hooks pass (`pre-commit run --all-files`)
- [ ] Tests pass in development environment
- [ ] Documentation updated (README, comments, changelog)
- [ ] No secrets committed (check with `git diff`)
- [ ] Commit messages follow conventional format
- [ ] PR description clearly explains changes
- [ ] Screenshots/logs included if relevant

### Review Criteria

Reviewers will check:

1. **Functionality**: Does it work as intended?
2. **Security**: No vulnerabilities or hardcoded secrets?
3. **Code Quality**: Readable, maintainable, follows standards?
4. **Testing**: Adequate testing performed?
5. **Documentation**: Changes documented appropriately?
6. **Home Lab Appropriate**: Fits project philosophy and constraints?

### After PR Approval

1. Squash commits if requested
2. Rebase onto main if needed
3. Merge using GitHub UI (squash merge preferred)
4. Delete feature branch after merge

## Testing Guidelines

### Ansible Playbook Testing

**Minimum Required:**
- Syntax validation: `ansible-playbook --syntax-check`
- Check mode dry-run: `ansible-playbook --check --diff`
- Ansible-lint: `ansible-lint playbook.yml`

**Recommended:**
- Test in dev environment before prod
- Use tags for incremental testing
- Molecule for role testing (if applicable)

### Terraform Module Testing

**Minimum Required:**
- Format check: `terraform fmt -check`
- Validation: `terraform validate`
- Plan review: `terraform plan`

**Recommended:**
- Security scan: `tfsec .` and `checkov -d .`
- Documentation: `terraform-docs`
- Test in separate workspace first

### Kubernetes Manifest Testing

**Minimum Required:**
- Dry-run: `kubectl apply --dry-run=server`
- Schema validation: `kubeval`

**Recommended:**
- Security scan: `kubesec scan`
- Best practices: `kube-score score`
- Test in development namespace first

## Common Issues and Solutions

### Pre-commit Hooks Failing

**Issue:** `detect-secrets` finds false positives
```bash
# Update baseline to include false positives
detect-secrets scan --baseline .secrets.baseline
git add .secrets.baseline
```

**Issue:** `ansible-lint` too strict
```bash
# Skip specific rules in playbook
# yamllint disable-line rule:line-length
- name: Long task name that exceeds line length

# Or disable in .ansible-lint config
```

**Issue:** `terraform_tfsec` blocking on medium severity
```bash
# tfsec scans only HIGH/CRITICAL in pre-commit
# Run full scan separately: tfsec .
# Address issues or document exceptions
```

### Bypassing Hooks Temporarily

```bash
# For work-in-progress commits
git commit --no-verify -m "WIP: testing new approach"

# Remember to fix issues before final PR!
```

## Getting Help

- **Documentation**: Check `/docs` directory and README files
- **Issues**: Search existing issues or create new one
- **Discussions**: Use GitHub Discussions for questions
- **Community**: Join Discord/Slack (if available)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (Apache 2.0 or MIT - check LICENSE file).

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Search GitHub issues
3. Create a new issue with `question` label
4. Reach out on community channels

Thank you for contributing to this home lab project! 🚀
