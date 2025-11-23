---
name: "ansible-bitwarden-integration"
description: "Create Ansible playbooks using Bitwarden Secrets Manager for secure credential management. Use when implementing new playbooks, migrating from Ansible Vault, setting up CI/CD integration, managing multi-environment secrets, or implementing secure secret lookups. Covers lookup patterns, error handling, Vault fallback, machine accounts, and migration strategies."
allowed-tools: ["Read", "Search", "Edit"]
version: "1.0.0"
author: "Home Lab Infrastructure Team"
---

# Ansible Bitwarden Integration

## When to Use This Skill

Claude automatically applies this skill when you:
- Ask to "create an Ansible playbook with Bitwarden..."
- Request "secure secret management for Ansible"
- Need "to migrate from Ansible Vault to Bitwarden"
- Want "CI/CD integration with secrets"
- Implement "machine account authentication"
- Design "multi-environment secret management"

## Prerequisites

### Installation

```bash
# Install Bitwarden Ansible collection
ansible-galaxy collection install bitwarden.secrets

# Verify installation
ansible-galaxy collection list | grep bitwarden
# Output: bitwarden.secrets  v1.0.1
```

### Authentication Setup

#### Development/Local Execution

```bash
# Option 1: Environment variable (recommended)
export BWS_ACCESS_TOKEN="your-machine-account-token-here"

# Option 2: Secure token file (gitignored)
echo "export BWS_ACCESS_TOKEN='your-token'" > ~/.bws_token
chmod 600 ~/.bws_token
source ~/.bws_token

# Test authentication
ansible localhost -m debug -a "msg={{ lookup('bitwarden.secrets.lookup', 'test-secret-id') }}"
```

#### CI/CD Integration

```yaml
# GitHub Actions example
env:
  BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}

steps:
  - name: Deploy with Bitwarden secrets
    run: ansible-playbook deploy.yml
```

## Core Patterns

### Pattern 1: Basic Secret Lookup

```yaml
---
- name: Deploy service with Bitwarden secrets
  hosts: all
  gather_facts: yes
  become: true

  tasks:
    - name: Load database password from Bitwarden
      ansible.builtin.set_fact:
        db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
      no_log: true

    - name: Load API key from Bitwarden
      ansible.builtin.set_fact:
        api_key: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-key') }}"
      no_log: true

    - name: Create configuration file with secrets
      ansible.builtin.template:
        src: config.j2
        dest: /etc/service/config.yml
        mode: '0600'
        owner: root
        group: root
      no_log: true
```

**Important**: Always use `no_log: true` for tasks handling secrets to prevent exposure in Ansible output.

### Pattern 2: Batch Secret Loading

```yaml
---
- name: Load all service secrets upfront
  hosts: all
  gather_facts: yes

  tasks:
    - name: Load all secrets from Bitwarden
      ansible.builtin.set_fact:
        service_secrets:
          db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
          db_username: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-username') }}"
          api_key: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-key') }}"
          api_secret: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-secret') }}"
          admin_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-admin-password') }}"
        cacheable: yes
      no_log: true

    - name: Use loaded secrets
      ansible.builtin.debug:
        msg: "Secrets loaded: {{ service_secrets.keys() | list }}"
      no_log: false  # Safe to show keys, not values
```

**Benefit**: Single lookup batch reduces API calls and improves performance.

### Pattern 3: Vault Fallback (During Migration)

```yaml
---
- name: Deploy with Vault fallback support
  hosts: all
  vars_files:
    - group_vars/service_vault.yml  # Legacy vault file

  tasks:
    - name: Get secret with Vault fallback
      ansible.builtin.set_fact:
        db_password: >-
          {{
            lookup('bitwarden.secrets.lookup', 'prod-db-password', default='') |
            default(vault_db_password | default(''), true)
          }}
      no_log: true

    - name: Verify secret loaded
      ansible.builtin.assert:
        that:
          - db_password is defined
          - db_password | length > 0
        fail_msg: "Database password not found in Bitwarden or Vault"
        quiet: true
      no_log: true

    - name: Use secret in configuration
      ansible.builtin.template:
        src: database-config.j2
        dest: /etc/service/db.conf
        mode: '0600'
      no_log: true
```

**Use Case**: Parallel operation during 16-week Bitwarden migration (see DEVELOPMENT_PLAN.md).

### Pattern 4: Error Handling and Validation

```yaml
---
- name: Robust secret retrieval with error handling
  hosts: all

  tasks:
    - name: Verify Bitwarden authentication
      ansible.builtin.command:
        cmd: bws --version
      register: bws_check
      failed_when: false
      changed_when: false
      no_log: false

    - name: Fail if BWS not available
      ansible.builtin.fail:
        msg: "Bitwarden CLI not installed or BWS_ACCESS_TOKEN not set"
      when: bws_check.rc != 0

    - name: Load secret with error handling
      block:
        - name: Attempt to load secret from Bitwarden
          ansible.builtin.set_fact:
            api_token: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-token') }}"
          no_log: true

      rescue:
        - name: Log error (without exposing secret)
          ansible.builtin.debug:
            msg: "Failed to retrieve secret from Bitwarden"

        - name: Fail deployment
          ansible.builtin.fail:
            msg: "Cannot proceed without required secret"

    - name: Validate secret format
      ansible.builtin.assert:
        that:
          - api_token is defined
          - api_token | length >= 32
        fail_msg: "API token is invalid or too short"
        quiet: true
      no_log: true
```

### Pattern 5: Multi-Environment Secret Management

```yaml
---
- name: Deploy across environments with environment-specific secrets
  hosts: all
  vars:
    environment: "{{ lookup('env', 'DEPLOY_ENV') | default('dev', true) }}"

  tasks:
    - name: Load environment-specific secrets
      ansible.builtin.set_fact:
        service_secrets:
          db_password: "{{ lookup('bitwarden.secrets.lookup', environment ~ '-db-password') }}"
          api_key: "{{ lookup('bitwarden.secrets.lookup', environment ~ '-api-key') }}"
      no_log: true

    - name: Display target environment (not secrets)
      ansible.builtin.debug:
        msg: "Deploying to {{ environment }} environment"

    - name: Deploy configuration
      ansible.builtin.template:
        src: config.{{ environment }}.j2
        dest: /etc/service/config.yml
        mode: '0600'
      no_log: true
```

**Secret Naming**: `dev-db-password`, `staging-db-password`, `prod-db-password`

### Pattern 6: Group Variables with Bitwarden

```yaml
# group_vars/production.yml
---
# Service configuration (non-secret)
service_port: 8080
service_log_level: "info"
service_replicas: 3

# Bitwarden secret lookups
service_db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-db-password') }}"
service_api_key: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-api-key') }}"
service_admin_token: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-admin-token') }}"

# During migration: Vault fallback
# service_db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-db-password', default=vault_service_db_password | default('')) }}"
```

### Pattern 7: Secret Scoping and Cleanup

```yaml
---
- name: Use secrets with limited scope
  hosts: all

  tasks:
    - name: Load secret for specific task
      block:
        - name: Get temporary secret
          ansible.builtin.set_fact:
            temp_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-admin-password') }}"
          no_log: true

        - name: Use secret for admin task
          ansible.builtin.uri:
            url: "https://admin.example.com/api/configure"
            method: POST
            user: admin
            password: "{{ temp_admin_password }}"
            force_basic_auth: yes
          no_log: true

      always:
        - name: Clear secret from memory
          ansible.builtin.set_fact:
            temp_admin_password: ""
          no_log: true
```

## CI/CD Integration Patterns

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Install Bitwarden collection
        run: ansible-galaxy collection install bitwarden.secrets

      - name: Deploy with Bitwarden secrets
        env:
          BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
        run: |
          ansible-playbook -i inventory/prod.ini playbooks/site.yml

      - name: Verify deployment
        run: ansible all -i inventory/prod.ini -m ping
```

### GitLab CI

```yaml
# .gitlab-ci.yml
deploy:
  stage: deploy
  image: ansible/ansible:latest
  variables:
    BWS_ACCESS_TOKEN: $BWS_ACCESS_TOKEN  # Set in GitLab CI/CD variables
  before_script:
    - ansible-galaxy collection install bitwarden.secrets
  script:
    - ansible-playbook -i inventory/prod.ini playbooks/site.yml
  only:
    - main
```

## Machine Account Setup

### Creating Machine Accounts

```bash
# In Bitwarden Secrets Manager:
# 1. Create machine account: "ansible-automation"
# 2. Assign to projects: prod/*, staging/*
# 3. Set access level: Read
# 4. Generate access token
# 5. Store token securely (never commit!)

# Use different tokens per environment
BWS_ACCESS_TOKEN_DEV="dev-machine-account-token"
BWS_ACCESS_TOKEN_STAGING="staging-machine-account-token"
BWS_ACCESS_TOKEN_PROD="prod-machine-account-token"
```

### Machine Account Best Practices

1. **Separate accounts per environment**
   - `ansible-dev`: Read access to dev/* secrets
   - `ansible-staging`: Read access to staging/* secrets
   - `ansible-prod`: Read access to prod/* secrets

2. **Least privilege access**
   - Only grant access to required projects
   - Use read-only access for automation
   - Rotate tokens quarterly

3. **Token storage**
   - Never commit tokens to git
   - Use CI/CD secret management
   - Store locally in gitignored files

## Migration Strategies

### Phase 1: Parallel Operation

```yaml
# Support both Bitwarden and Vault during migration
---
- name: Service deployment with dual secret support
  hosts: all
  vars_files:
    - group_vars/service_vault.yml  # Keep vault file

  tasks:
    - name: Load secret (Bitwarden preferred, Vault fallback)
      ansible.builtin.set_fact:
        db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password', default=vault_db_password | default('changeme123')) }}"
      no_log: true
```

### Phase 2: Bitwarden Only

```yaml
# After 2-week validation period, remove Vault fallback
---
- name: Service deployment with Bitwarden only
  hosts: all

  tasks:
    - name: Load secret from Bitwarden
      ansible.builtin.set_fact:
        db_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
      no_log: true
```

## Security Best Practices

### 1. Always Use no_log

```yaml
# ✅ CORRECT
- name: Load secret
  ansible.builtin.set_fact:
    password: "{{ lookup('bitwarden.secrets.lookup', 'secret-id') }}"
  no_log: true

# ❌ WRONG - Secret visible in output
- name: Load secret
  ansible.builtin.set_fact:
    password: "{{ lookup('bitwarden.secrets.lookup', 'secret-id') }}"
```

### 2. Validate Secrets Before Use

```yaml
- name: Validate secret format
  ansible.builtin.assert:
    that:
      - api_key is defined
      - api_key | length >= 32
      - api_key is match('^[A-Za-z0-9]+$')
    fail_msg: "API key validation failed"
    quiet: true
  no_log: true
```

### 3. Limit Secret Scope

```yaml
# Load secrets only when needed
- name: Admin task requiring secret
  block:
    - name: Load admin secret
      ansible.builtin.set_fact:
        admin_token: "{{ lookup('bitwarden.secrets.lookup', 'admin-token') }}"
      no_log: true

    - name: Perform admin action
      ansible.builtin.uri:
        url: "https://api.example.com/admin"
        headers:
          Authorization: "Bearer {{ admin_token }}"
      no_log: true

  always:
    - name: Clear secret
      ansible.builtin.set_fact:
        admin_token: ""
      no_log: true
```

### 4. Never Log Secret Values

```yaml
# ✅ SAFE - Log only metadata
- name: Display loaded secret keys
  ansible.builtin.debug:
    msg: "Loaded secrets: {{ service_secrets.keys() | list }}"

# ❌ UNSAFE - Exposes values
- name: Display secret values
  ansible.builtin.debug:
    var: service_secrets
```

## Common Patterns

### Pattern: Database Configuration

```yaml
- name: Configure PostgreSQL with Bitwarden secrets
  hosts: database
  become: yes

  tasks:
    - name: Load database credentials
      ansible.builtin.set_fact:
        postgres_secrets:
          password: "{{ lookup('bitwarden.secrets.lookup', 'prod-postgres-password') }}"
          replication_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-postgres-replication-password') }}"
      no_log: true

    - name: Create PostgreSQL user
      community.postgresql.postgresql_user:
        name: appuser
        password: "{{ postgres_secrets.password }}"
        encrypted: yes
      no_log: true

    - name: Create replication user
      community.postgresql.postgresql_user:
        name: replicator
        password: "{{ postgres_secrets.replication_password }}"
        encrypted: yes
        role_attr_flags: REPLICATION
      no_log: true
```

### Pattern: API Integration

```yaml
- name: Configure service API with Bitwarden
  hosts: app_servers

  tasks:
    - name: Load API credentials
      ansible.builtin.set_fact:
        api_credentials:
          key: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-key') }}"
          secret: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-secret') }}"
      no_log: true

    - name: Create API config file
      ansible.builtin.copy:
        content: |
          API_KEY={{ api_credentials.key }}
          API_SECRET={{ api_credentials.secret }}
        dest: /etc/service/api.env
        mode: '0600'
        owner: serviceuser
        group: serviceuser
      no_log: true
```

### Pattern: TLS/SSL Certificates

```yaml
- name: Deploy TLS certificates from Bitwarden
  hosts: web_servers

  tasks:
    - name: Load TLS certificate and key
      ansible.builtin.set_fact:
        tls_cert: "{{ lookup('bitwarden.secrets.lookup', 'prod-tls-cert') }}"
        tls_key: "{{ lookup('bitwarden.secrets.lookup', 'prod-tls-key') }}"
      no_log: true

    - name: Install TLS certificate
      ansible.builtin.copy:
        content: "{{ tls_cert }}"
        dest: /etc/ssl/certs/service.crt
        mode: '0644'
        owner: root
        group: root
      no_log: true

    - name: Install TLS private key
      ansible.builtin.copy:
        content: "{{ tls_key }}"
        dest: /etc/ssl/private/service.key
        mode: '0600'
        owner: root
        group: root
      no_log: true
      notify: restart web server
```

## Troubleshooting

### Issue: "Secret not found"

```yaml
- name: Debug Bitwarden connectivity
  block:
    - name: Check BWS_ACCESS_TOKEN
      ansible.builtin.debug:
        msg: "BWS_ACCESS_TOKEN is {{ 'set' if lookup('env', 'BWS_ACCESS_TOKEN') else 'NOT set' }}"

    - name: Test Bitwarden CLI
      ansible.builtin.command:
        cmd: bws secret list --limit 1
      register: bws_test
      failed_when: false
      changed_when: false

    - name: Display BWS test result
      ansible.builtin.debug:
        var: bws_test.rc

    - name: Attempt secret lookup
      ansible.builtin.set_fact:
        test_secret: "{{ lookup('bitwarden.secrets.lookup', 'test-secret-id') }}"
      no_log: true
      register: lookup_result
      failed_when: false
```

### Issue: "Authentication failed"

```bash
# Check token validity
echo $BWS_ACCESS_TOKEN

# Test with Bitwarden CLI
bws secret list --limit 1

# Verify collection installed
ansible-galaxy collection list | grep bitwarden
```

### Issue: "Performance degradation"

```yaml
# Instead of individual lookups
- name: Load each secret individually (SLOW)
  ansible.builtin.set_fact:
    secret1: "{{ lookup('bitwarden.secrets.lookup', 'id1') }}"
    secret2: "{{ lookup('bitwarden.secrets.lookup', 'id2') }}"
    secret3: "{{ lookup('bitwarden.secrets.lookup', 'id3') }}"

# Use batch loading (FASTER)
- name: Load all secrets at once
  ansible.builtin.set_fact:
    all_secrets:
      secret1: "{{ lookup('bitwarden.secrets.lookup', 'id1') }}"
      secret2: "{{ lookup('bitwarden.secrets.lookup', 'id2') }}"
      secret3: "{{ lookup('bitwarden.secrets.lookup', 'id3') }}"
    cacheable: yes
```

## Key Takeaways

1. **Always use no_log: true** for secret-handling tasks
2. **Batch load secrets** upfront for better performance
3. **Validate secrets** before use to catch errors early
4. **Use machine accounts** for automation (never personal accounts)
5. **Implement fallback** during migration for safety
6. **Scope secrets** to minimize exposure
7. **Clear secrets** from memory when done
8. **Never log secret values** in debug output
9. **Separate tokens** per environment (dev/staging/prod)
10. **Test authentication** before playbook execution

This skill provides comprehensive patterns for integrating Bitwarden Secrets Manager into Ansible playbooks securely and efficiently.