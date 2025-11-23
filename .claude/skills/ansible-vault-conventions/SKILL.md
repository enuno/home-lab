---
name: "ansible-vault-conventions"
description: "Ansible Vault file naming, encryption, and template conventions for managing secrets. Covers vault_ prefix patterns, entire-file encryption patterns, template file requirements, .gitignore rules, and setup workflows for consistent secret management across environments."
allowed-tools: ["Read", "Edit", "Write", "Bash"]
version: "1.0.0"
author: "Home Lab Infrastructure Team"
---

# Ansible Vault Conventions

## When to Use This Skill

Claude automatically applies this skill when you:
- Create new Ansible vault files or encrypted secrets
- Ask about "vault file naming conventions"
- Need to "encrypt Ansible secrets"
- Want to "create vault templates"
- Set up "ansible-vault encrypted files"
- Ask "how to organize secrets" in Ansible
- Work with `group_vars/*_vault.yml` or `host_vars/*_vault.yml`

## Core Principles

This project follows strict conventions for Ansible Vault encrypted files to maintain clarity, consistency, and security across environments.

### The Two Vault Patterns

#### Pattern 1: Select Sensitive Variables (Standard)

**When to use**: Vault file contains **select sensitive variables** among other configuration.

**Convention**: Prefix sensitive variables with `vault_` for easy identification.

**Example file**: `group_vars/pihole_vault.yml`

```yaml
# group_vars/pihole_vault.yml (encrypted with ansible-vault)
vault_pihole_admin_password: "secret123"
vault_pihole_api_key: "key456"
vault_tailscale_auth_key: "tskey-789"
```

**Usage in playbooks**:

```yaml
- name: Configure Pi-hole admin password
  ansible.builtin.command:
    cmd: "pihole -a -p {{ vault_pihole_admin_password }}"
  no_log: true
```

**Why this works**:
- Clear indication that variable comes from encrypted vault
- Easy to identify sensitive data in playbook code
- Prevents accidental logging of secrets
- Consistent pattern across all playbooks

#### Pattern 2: Entire Config File Encrypted (Exception)

**When to use**: The **entire service configuration** is encrypted as a single file.

**Convention**: NO `vault_` prefix needed (the entire file is the secret).

**Example files**: `tor_exit_nodes_vault.yml`, `wireguard_config_vault.yml`

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

**Usage in playbooks**:

```yaml
- name: Deploy Tor exit nodes
  ansible.builtin.template:
    src: torrc.j2
    dest: /etc/tor/torrc
  vars:
    exit_nodes: "{{ tor_exit_nodes }}"
```

## Template File Requirements

**CRITICAL RULE**: Every ansible-vault encrypted file MUST have a corresponding `.template` file.

### Why Templates Matter

1. **Documentation**: Shows structure and required variables
2. **Onboarding**: New team members can quickly set up their environment
3. **Version Control**: Track changes to vault structure without exposing secrets
4. **Multi-Environment**: Easy to replicate structure across dev/staging/prod

### Template Structure

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

### Template Best Practices

1. **Include encryption command**: Show exact command to encrypt
2. **Comment each variable**: Explain purpose and where it's used
3. **Use placeholder values**: "changeme", "your-key-here", etc.
4. **Document format**: Show expected format (URLs, keys, passwords)
5. **Link to docs**: Reference where to obtain API keys/credentials

## File Management Rules

### .gitignore Configuration

**Encrypted files** (NEVER commit these):

```gitignore
# Ansible Vault encrypted files (contain actual secrets)
group_vars/*_vault.yml
host_vars/*_vault.yml
ansible/.vault_password
```

**Template files** (ALWAYS commit these):

```bash
# Templates are committed to git
group_vars/*_vault.yml.template
host_vars/*_vault.yml.template
```

### File Organization

```
ansible/
├── group_vars/
│   ├── all/
│   │   ├── vars.yml              # Non-sensitive variables (committed)
│   │   ├── vault.yml             # Encrypted secrets (gitignored)
│   │   └── vault.yml.template    # Template (committed)
│   ├── pihole_vault.yml          # Encrypted (gitignored)
│   ├── pihole_vault.yml.template # Template (committed)
│   └── k3s_vault.yml             # Encrypted (gitignored)
│       k3s_vault.yml.template    # Template (committed)
├── host_vars/
│   └── server01/
│       ├── vars.yml              # Non-sensitive (committed)
│       ├── vault.yml             # Encrypted (gitignored)
│       └── vault.yml.template    # Template (committed)
└── .vault_password               # Vault password file (gitignored)
```

## Creating New Vault Files

### Step-by-Step Workflow

#### 1. Create Template First

```bash
# Create template with documentation
cat > group_vars/myservice_vault.yml.template << 'EOF'
# group_vars/myservice_vault.yml.template
# Service: MyService configuration secrets
# Encrypted: Yes (use ansible-vault)
#
# Setup:
# 1. Copy this file: cp group_vars/myservice_vault.yml.template group_vars/myservice_vault.yml
# 2. Fill in actual secrets
# 3. Encrypt: ansible-vault encrypt group_vars/myservice_vault.yml

# MyService API key (get from https://myservice.com/api)
vault_myservice_api_key: "api-key-here"

# MyService database password
vault_myservice_db_password: "password-here"

# MyService admin email
vault_myservice_admin_email: "admin@example.com"
EOF
```

#### 2. Copy and Customize

```bash
# Copy template to create vault file
cp group_vars/myservice_vault.yml.template group_vars/myservice_vault.yml

# Edit with actual secrets
vim group_vars/myservice_vault.yml
```

#### 3. Encrypt the File

```bash
# Encrypt using vault password file
ansible-vault encrypt group_vars/myservice_vault.yml \
  --vault-password-file ansible/.vault_password

# Or encrypt with prompted password
ansible-vault encrypt group_vars/myservice_vault.yml
```

#### 4. Verify Gitignore

```bash
# Verify encrypted file is gitignored
git status

# Should NOT show myservice_vault.yml
# Should show myservice_vault.yml.template (if new)
```

#### 5. Commit Template Only

```bash
# Add and commit only the template
git add group_vars/myservice_vault.yml.template
git commit -m "feat(ansible): add myservice vault template"
```

## Working with Vault Files

### Viewing Encrypted Files

```bash
# View encrypted file content
ansible-vault view group_vars/pihole_vault.yml \
  --vault-password-file ansible/.vault_password
```

### Editing Encrypted Files

```bash
# Edit in-place (decrypts, opens editor, re-encrypts)
ansible-vault edit group_vars/pihole_vault.yml \
  --vault-password-file ansible/.vault_password
```

### Changing Vault Password

```bash
# Re-key vault file with new password
ansible-vault rekey group_vars/pihole_vault.yml \
  --vault-password-file ansible/.vault_password \
  --new-vault-password-file ansible/.vault_password_new
```

### Decrypting (Temporarily)

```bash
# Decrypt for migration or inspection
ansible-vault decrypt group_vars/pihole_vault.yml \
  --vault-password-file ansible/.vault_password

# IMPORTANT: Re-encrypt immediately after use
ansible-vault encrypt group_vars/pihole_vault.yml \
  --vault-password-file ansible/.vault_password
```

## Using Vault Variables in Playbooks

### Loading Vault Files

```yaml
---
- name: Deploy Pi-hole with secrets
  hosts: pihole
  become: yes

  vars_files:
    - group_vars/pihole_vault.yml  # Loads encrypted variables

  tasks:
    - name: Configure Pi-hole admin password
      ansible.builtin.command:
        cmd: "pihole -a -p {{ vault_pihole_admin_password }}"
      no_log: true  # CRITICAL: Prevent secret from appearing in logs
```

### Referencing Vault Variables

```yaml
# Pattern 1: Select variables with vault_ prefix
tasks:
  - name: Set API key
    ansible.builtin.lineinfile:
      path: /etc/myservice/config.ini
      regexp: '^api_key='
      line: "api_key={{ vault_myservice_api_key }}"
    no_log: true

# Pattern 2: Entire config file (no vault_ prefix)
tasks:
  - name: Deploy Tor configuration
    ansible.builtin.template:
      src: torrc.j2
      dest: /etc/tor/torrc
    vars:
      nodes: "{{ tor_exit_nodes }}"  # tor_exit_nodes from vault file
```

### Masking Sensitive Output

**ALWAYS use `no_log: true` when handling secrets**:

```yaml
- name: Create database user
  postgresql_user:
    name: appuser
    password: "{{ vault_db_password }}"
  no_log: true  # Prevents password from appearing in Ansible output

- name: Debug non-sensitive info
  ansible.builtin.debug:
    msg: "Database user: appuser"
  # no_log not needed for non-sensitive data
```

## Migration to Bitwarden Secrets Manager

**Current State**: This project is migrating from Ansible Vault to Bitwarden Secrets Manager.

### Parallel Operation During Migration

During the transition, both systems operate in parallel:

```yaml
# Legacy vault variable (being phased out)
- name: Use vault variable
  ansible.builtin.debug:
    msg: "{{ vault_database_password }}"
  no_log: true

# New Bitwarden lookup (target state)
- name: Use Bitwarden secret
  ansible.builtin.debug:
    msg: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
  no_log: true
```

### Migration Checklist

When migrating a vault file to Bitwarden:

- [ ] Export secrets from vault file (keep encrypted backup)
- [ ] Import to Bitwarden with proper project assignment
- [ ] Update playbook to use Bitwarden lookup
- [ ] Test playbook with new lookup method
- [ ] Keep vault file as backup during testing
- [ ] Archive vault file after successful migration
- [ ] Update template with Bitwarden lookup examples
- [ ] Document migration in commit message

## Troubleshooting

### Common Issues

**Problem**: "ERROR! Attempting to decrypt but no vault secrets found"

```bash
# Solution: Verify vault password file location
ansible-playbook site.yml --vault-password-file ansible/.vault_password
```

**Problem**: "Vault file not ignored by git"

```bash
# Solution: Check .gitignore pattern
cat .gitignore | grep vault

# Should show:
# group_vars/*_vault.yml
# host_vars/*_vault.yml
```

**Problem**: "Can't remember which variables are in which vault file"

```bash
# Solution: Check the template file
cat group_vars/pihole_vault.yml.template

# Or view encrypted file
ansible-vault view group_vars/pihole_vault.yml
```

## Security Best Practices

### Vault Password Management

```bash
# Store vault password securely
# Option 1: File (local development)
echo "your-secure-password" > ansible/.vault_password
chmod 600 ansible/.vault_password

# Option 2: Environment variable (CI/CD)
export ANSIBLE_VAULT_PASSWORD=your-secure-password
ansible-playbook site.yml

# Option 3: Keyring (macOS/Linux)
# Store in system keychain, retrieve when needed
```

### Pre-commit Hooks

Prevent accidental secret commits:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

### Audit Trail

```bash
# Track vault file changes (without exposing content)
git log --oneline group_vars/pihole_vault.yml.template

# Review who last modified vault file
ls -la group_vars/pihole_vault.yml
```

## Quick Reference

### Command Cheat Sheet

```bash
# Create encrypted file
ansible-vault create group_vars/new_vault.yml

# View encrypted file
ansible-vault view group_vars/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# Encrypt existing file
ansible-vault encrypt group_vars/vault.yml

# Decrypt file
ansible-vault decrypt group_vars/vault.yml

# Change password
ansible-vault rekey group_vars/vault.yml

# Run playbook with vault
ansible-playbook site.yml --vault-password-file ansible/.vault_password

# Run playbook with prompted password
ansible-playbook site.yml --ask-vault-pass
```

### Variable Naming Decision Tree

```
Is the entire file a secret?
├─ YES → No vault_ prefix
│         Example: tor_exit_nodes_vault.yml
│         Variables: tor_exit_nodes (direct)
│
└─ NO → Use vault_ prefix for sensitive vars
          Example: pihole_vault.yml
          Variables: vault_pihole_admin_password
```

## Summary

**Key Conventions**:
- ✅ Use `vault_` prefix for select sensitive variables
- ✅ No prefix when entire config file is the secret
- ✅ Always create `.template` file alongside vault file
- ✅ Encrypted files in `.gitignore`, templates committed
- ✅ Document secrets in templates with helpful comments
- ✅ Use `no_log: true` on all secret-handling tasks
- ✅ Keep vault password file secure and gitignored
- ✅ Test vault access before running playbooks in production

This skill ensures consistent, secure, and well-documented secret management across all Ansible automation in the home lab.
