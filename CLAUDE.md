# Claude.md — Home Lab Infrastructure Automation Project Context

## Project Overview
This home lab project implements production-grade infrastructure automation while maintaining flexibility for rapid experimentation and learning. The repository manages a complete infrastructure stack using Infrastructure as Code (IaC) principles with Terraform, Ansible, and Kubernetes.

**Primary Goals:**
- Build highly available home lab infrastructure with enterprise patterns
- Migrate from Ansible Vault to Bitwarden Secrets Manager for centralized secrets management
- Implement staging/pre-production quality code standards (not overly strict, but reliable)
- Create reusable modules and roles for community sharing
- Document everything for knowledge sharing and reproducibility

**Current Status:**
- Active migration from Ansible Vault to Bitwarden Secrets Manager
- Multi-node Kubernetes cluster (K3s) with HA configuration
- GitOps workflows with Flux/ArgoCD
- Comprehensive monitoring with Prometheus, Grafana, and logging stack

## Current Tool Versions (October 2025)
When generating code or providing recommendations, use these specific versions:

```yaml
Infrastructure Tools:
  terraform: "1.13.3"
  ansible_core: "2.19.3"
  ansible_community: "12.1.0"
  kubernetes: "1.34.x"
  helm: "3.x"

Programming Languages:
  python: "3.11+"
  node: "20.x LTS"

Secrets Management:
  bitwarden_sdk: "latest"
  bitwarden_ansible_collection: "bitwarden.secrets"

Code Quality:
  pre_commit: "latest"
  ansible_lint: "latest"
  terraform_lint: "latest"
  yamllint: "latest"
  black: "latest"
  ruff: "latest"
```

## Architecture Overview

### Infrastructure Layers
1. **Hardware Layer**: 3+ node cluster (1 master, 2+ workers) on Proxmox VE or bare metal
2. **Network Layer**: VLANs, firewall rules, load balancers, DNS services
3. **Compute Layer**: Kubernetes cluster with HA control plane
4. **Storage Layer**: NFS/iSCSI for persistent volumes, automated backups
5. **Application Layer**: Containerized services, GitOps deployment
6. **Observability Layer**: Metrics, logs, traces, alerting

### High Availability Design Patterns
- **Multi-master Kubernetes**: 3+ control plane nodes with etcd clustering
- **Load Balancing**: HAProxy/Traefik for ingress traffic distribution
- **Database HA**: PostgreSQL with Patroni for automatic failover
- **Storage Replication**: Distributed storage with multi-node replication
- **Network Redundancy**: Multiple network paths and failover routes

### Secrets Management Architecture
**Legacy (Current State):**
- Ansible Vault for encrypted files in `group_vars/*/vault.yml`
- Vault password file at `ansible/.vault_password` (gitignored)
- Variables prefixed with `vault_` for identification

**Target State (In Migration):**
- Bitwarden Secrets Manager for centralized secret storage
- Machine accounts for automation contexts (dev, staging, prod)
- Projects organized by environment and service type
- Lookup pattern: `{{ lookup('bitwarden.secrets.lookup', 'SECRET_ID') }}`
- BWS_ACCESS_TOKEN environment variable for authentication

## Code Quality Standards (Staging/Pre-Prod Level)

### Quality Philosophy
This home lab balances production-grade patterns with practical flexibility:
- ✅ **Security**: Medium-high (secure but not paranoid)
- ✅ **Functionality**: High (must work reliably)
- ✅ **Readability**: High (clear, well-documented code)
- ✅ **Testing**: Moderate (practical tests, not exhaustive)
- ✅ **Strictness**: Moderate (warnings acceptable, critical errors fail)
- ✅ **Experimentation**: Encouraged (can bypass checks for WIP with documentation)

### Must-Pass Quality Gates
- ❌ **No secrets in commits** (detect-secrets hook enforces)
- ❌ **Valid Ansible syntax** (ansible-lint catches errors)
- ❌ **Valid Terraform syntax** (terraform fmt, terraform validate)
- ❌ **Valid YAML syntax** (yamllint with relaxed rules)
- ❌ **Critical security issues** (tfsec, checkov on high/critical findings)

### Should-Pass (Warnings OK)
- ⚠️ Ansible-lint style suggestions
- ⚠️ Terraform tflint recommendations
- ⚠️ Minor security improvements
- ⚠️ Documentation gaps (fix before PR merge)
- ⚠️ Performance optimizations

### Can Skip for WIP
- Use `git commit --no-verify` for work-in-progress commits
- Document why in commit message
- Fix issues before final merge to main branch

## Common Development Tasks

### Ansible Playbook Patterns

**Standard Playbook Structure:**
```yaml
---
- name: Descriptive task name
  hosts: target_group
  become: true
  vars_files:
    - group_vars/all/vars.yml

  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

  tasks:
    - name: Use Bitwarden secret (new pattern)
      ansible.builtin.debug:
        msg: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
      no_log: true

    - name: Use vault variable (legacy pattern - being migrated)
      ansible.builtin.debug:
        msg: "{{ vault_database_password }}"
      no_log: true

  handlers:
    - name: Restart service
      ansible.builtin.systemd:
        name: myservice
        state: restarted
```

**Best Practices for This Project:**
- Always use FQCN (Fully Qualified Collection Names): `ansible.builtin.copy` not `copy`
- Use `check_mode` support: `check_mode: yes` for dry runs
- Implement idempotency: tasks should be safe to run multiple times
- Tag tasks appropriately: `--tags` for selective execution
- Use blocks for error handling and conditional logic
- Mask sensitive output: `no_log: true` on secret-handling tasks

### Ansible Vault Conventions

This project follows specific conventions for Ansible Vault encrypted files to maintain clarity and consistency:

**Variable Naming Convention:**

1. **Select Sensitive Variables (Standard Pattern):**
   - When a vault file contains **select sensitive variables** among other configuration
   - Prefix sensitive variables with `vault_` for easy identification in playbooks
   - Example file: `group_vars/pihole_vault.yml`
   ```yaml
   # group_vars/pihole_vault.yml (encrypted)
   vault_pihole_admin_password: "secret123"
   vault_pihole_api_key: "key456"
   vault_tailscale_auth_key: "tskey-789"
   ```
   - Usage in playbooks clearly indicates these are vault-encrypted secrets:
   ```yaml
   - name: Configure Pi-hole admin password
     ansible.builtin.command:
       cmd: "pihole -a -p {{ vault_pihole_admin_password }}"
     no_log: true
   ```

2. **Entire Config File Encrypted (Exception Pattern):**
   - When the **entire service configuration** is encrypted as a single file
   - NO `vault_` prefix needed (the entire file is the secret)
   - Example: `tor_exit_nodes_vault.yml`, `wireguard_config_vault.yml`
   ```yaml
   # group_vars/tor_exit_nodes_vault.yml (entire file encrypted)
   tor_exit_nodes:
     - ip: "10.0.1.100"
       nickname: "ExitNode1"
       contact: "admin@example.com"
     - ip: "10.0.1.101"
       nickname: "ExitNode2"
       contact: "admin@example.com"
   ```

**Template File Requirements:**

Every ansible-vault encrypted file MUST have a corresponding `.template` file:

1. **Purpose**: Templates serve as documentation and starting point for new environments
2. **Location**: Same directory as encrypted file, with `.template` extension
3. **Content**: Structure with placeholder values, comments explaining each variable
4. **Not Encrypted**: Templates are committed to git in plain text

**Example Template:**
```yaml
# group_vars/pihole_vault.yml.template
# Copy this file to pihole_vault.yml and encrypt with:
# ansible-vault encrypt group_vars/pihole_vault.yml

# Pi-hole admin dashboard password
vault_pihole_admin_password: "changeme"

# Pi-hole API key for external integrations
vault_pihole_api_key: "your-api-key-here"

# Tailscale authentication key for VPN access
vault_tailscale_auth_key: "tskey-auth-xxxxx"
```

**File Management Rules:**

1. **Encrypted Files (.gitignore):**
   - All `*_vault.yml` files in `group_vars/` and `host_vars/` are gitignored
   - Pattern: `group_vars/*_vault.yml` and `host_vars/*_vault.yml`
   - Ensures secrets never committed to repository

2. **Template Files (Committed):**
   - All `*.template` files ARE committed to git
   - Provide structure and documentation for team members
   - Pattern: `group_vars/*_vault.yml.template`

3. **Setup Workflow:**
   ```bash
   # Copy template to create new vault file
   cp group_vars/pihole_vault.yml.template group_vars/pihole_vault.yml

   # Edit with actual secrets
   vim group_vars/pihole_vault.yml

   # Encrypt the file
   ansible-vault encrypt group_vars/pihole_vault.yml

   # Verify it's gitignored
   git status  # Should not show pihole_vault.yml
   ```

**When Creating New Playbooks:**

1. Determine if secrets needed:
   - **Yes → Create vault file with template**
   - **No → Use regular group_vars file**

2. If vault file needed:
   ```bash
   # Create template first
   cat > group_vars/myservice_vault.yml.template << 'EOF'
   # group_vars/myservice_vault.yml.template
   vault_myservice_api_key: "api-key-here"
   vault_myservice_password: "password-here"
   EOF

   # Copy and customize
   cp group_vars/myservice_vault.yml.template group_vars/myservice_vault.yml

   # Add actual secrets, then encrypt
   ansible-vault encrypt group_vars/myservice_vault.yml

   # Commit only the template
   git add group_vars/myservice_vault.yml.template
   git commit -m "feat(ansible): add myservice vault template"
   ```

3. Reference in playbooks using `vault_` prefix:
   ```yaml
   vars_files:
     - group_vars/myservice_vault.yml

   tasks:
     - name: Use vault secret
       ansible.builtin.debug:
         msg: "{{ vault_myservice_api_key }}"
       no_log: true
   ```

**Summary:**
- ✅ Use `vault_` prefix for select sensitive variables
- ✅ No prefix when entire config file is the secret
- ✅ Always create `.template` file alongside vault file
- ✅ Encrypted files in `.gitignore`, templates committed
- ✅ Document secrets in templates with helpful comments

### Terraform Module Patterns

**Standard Module Structure:**
```hcl
# modules/vm/main.tf
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

resource "proxmox_vm_qemu" "this" {
  for_each = var.vms

  name        = each.value.name
  target_node = each.value.node
  clone       = var.template_name

  cores   = each.value.cores
  memory  = each.value.memory

  # HA configuration
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [network]
  }

  # Tagging for organization
  tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
```

**Best Practices for This Project:**
- Use `for_each` over `count` for resource management
- Pin provider versions with `~>` for minor version upgrades
- Implement lifecycle rules for HA and safety
- Tag all resources for organization and cost tracking
- Use remote state (S3, Terraform Cloud) for team collaboration
- Document modules with `terraform-docs` (auto-generated in README.md)

### Kubernetes Manifest Patterns

**Standard Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: production
  labels:
    app: myapp
    environment: prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: registry.local/myapp:v1.2.3  # Specific tag, not 'latest'
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        env:
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
```

## Security Context

### Secrets Management Migration (Active)
**Current State:** Ansible Vault files scattered across `group_vars/` and `host_vars/`

**Migration Process:**
1. Inventory all vault files and categorize secrets
2. Set up Bitwarden organization with projects (dev, staging, prod)
3. Create machine accounts for automation
4. Export secrets from vault files (keeping encrypted backups)
5. Import secrets to Bitwarden with proper project assignment
6. Update playbooks to use Bitwarden lookup plugin
7. Test thoroughly in dev before promoting to prod
8. Maintain parallel operation during transition
9. Archive vault files after successful migration

**Authentication:**
- Development: Manual Bitwarden login, `bw unlock`
- CI/CD: `BWS_ACCESS_TOKEN` environment variable injected securely
- Machine accounts: Separate tokens per environment/purpose

### General Security Practices
- **Never commit secrets**: pre-commit hook `detect-secrets` enforces
- **Use SSH keys**: Passwordless authentication for all automation
- **Network segmentation**: VLANs separate management, services, DMZ
- **Principle of least privilege**: Minimal permissions for all accounts
- **Regular updates**: Automated security patching (with testing)
- **Audit logging**: All privileged actions logged to central location

## Testing Requirements

### Ansible Testing
```bash
# Syntax check
ansible-playbook playbook.yml --syntax-check

# Dry run (check mode)
ansible-playbook playbook.yml --check

# Diff mode (show changes)
ansible-playbook playbook.yml --check --diff

# Lint playbook (moderate strictness)
ansible-lint playbook.yml

# Test with Molecule (for roles)
cd roles/myrole && molecule test
```

### Terraform Testing
```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Plan (see changes before apply)
terraform plan -out=tfplan

# Security scanning
tfsec .
checkov -d .

# Documentation generation
terraform-docs markdown . > README.md
```

### Kubernetes Testing
```bash
# Dry run
kubectl apply --dry-run=client -f manifest.yml

# Server-side validation
kubectl apply --dry-run=server -f manifest.yml

# Diff before apply
kubectl diff -f manifest.yml

# Validate with kubeval
kubeval manifest.yml
```

## Home Lab Constraints and Optimizations

### Resource Constraints
- **Limited CPU/RAM**: Optimize resource requests/limits, use spot/burst
- **Storage capacity**: Implement tiered storage, automated cleanup policies
- **Network bandwidth**: Cache frequently accessed content, optimize transfers
- **Power consumption**: Consider power-efficient components, shutdown schedules

### Cost Optimization
- **Use open-source tools**: Prefer OSS over commercial where appropriate
- **Efficient resource allocation**: Right-size VMs and containers
- **Deduplication**: Avoid duplicate data in storage and backups
- **Automation**: Reduce manual time investment through IaC

### Learning Priorities
- **Production patterns**: Implement HA, load balancing, monitoring like real infrastructure
- **Industry tools**: Use same tools as production environments (Ansible, Terraform, K8s)
- **Documentation**: Write everything down for future reference and community sharing
- **Experimentation**: Balance stability with trying new technologies

## AI Assistant Interaction Guidelines

### When Generating Code
1. **Always specify versions**: Use the tool versions listed in this document
2. **Follow project patterns**: Match existing code structure and naming conventions
3. **Include comments**: Explain non-obvious logic and design decisions
4. **Consider HA**: Design for high availability and failure scenarios
5. **Think security**: Never hardcode secrets, use proper secret management
6. **Test compatibility**: Ensure code works with existing infrastructure

### When Providing Recommendations
1. **Be practical**: Consider home lab constraints (resources, budget, time)
2. **Explain trade-offs**: Production vs. home lab approaches
3. **Suggest alternatives**: Provide options with pros/cons
4. **Include examples**: Show concrete implementation code
5. **Link to docs**: Reference official documentation for further learning
6. **Mention migration**: Consider Bitwarden migration impact on suggestions

### When Troubleshooting
1. **Ask clarifying questions**: Gather context before suggesting solutions
2. **Check basics first**: Syntax, connectivity, permissions, versions
3. **Review logs**: Analyze error messages and stack traces
4. **Suggest debugging steps**: Incremental troubleshooting approach
5. **Consider rollback**: If stuck, suggest reverting to known-good state
6. **Document resolution**: Update runbooks with solution for future reference

## Quick Reference Commands

### Pre-commit Hooks
```bash
# Install hooks
pre-commit install

# Run on all files
pre-commit run --all-files

# Run specific hook
pre-commit run ansible-lint --all-files

# Bypass hooks (for WIP commits)
git commit --no-verify -m "WIP: debugging issue"
```

### Ansible
```bash
# Ping all hosts
ansible -i inventory/hosts.ini all -m ping

# Run playbook with check mode
ansible-playbook -i inventory site.yml --check

# Run with tags
ansible-playbook -i inventory site.yml --tags "setup,deploy"

# Vault operations (legacy - being migrated to Bitwarden)
ansible-vault edit group_vars/prod/vault.yml
ansible-vault view group_vars/prod/vault.yml
```

### Terraform
```bash
# Initialize workspace
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Generate documentation
terraform-docs markdown . > README.md
```

### Kubernetes
```bash
# Apply manifest with dry-run
kubectl apply -f manifest.yml --dry-run=server

# Get resource status
kubectl get pods -n production -o wide

# Describe resource
kubectl describe deployment myapp -n production

# View logs
kubectl logs -f deployment/myapp -n production

# Execute in pod
kubectl exec -it pod-name -n production -- /bin/bash
```

This document should guide all AI-assisted development in this home lab project, ensuring consistency, quality, and alignment with project goals.
Import command and agent standards from docs/claude/
