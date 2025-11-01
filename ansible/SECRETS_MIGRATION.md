# Secrets Migration Guide: Ansible Vault → Bitwarden Secrets Manager

## Overview

This guide provides step-by-step instructions for migrating secrets from Ansible Vault to Bitwarden Secrets Manager for the home-lab infrastructure automation project.

**Migration Objectives:**
- Centralize secret management in Bitwarden Secrets Manager
- Eliminate scattered vault files across `group_vars/` and `host_vars/`
- Enable better secret lifecycle management and audit trails
- Improve team collaboration with project-based organization
- Maintain backward compatibility during transition period

**Timeline:** Rolling migration with parallel operation support (no downtime required)

**Risk Level:** Low to Medium (with proper testing and rollback procedures)

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Prerequisites](#prerequisites)
3. [Bitwarden Setup](#bitwarden-setup)
4. [Migration Process](#migration-process)
5. [Playbook Updates](#playbook-updates)
6. [Testing Strategy](#testing-strategy)
7. [Rollback Procedures](#rollback-procedures)
8. [Post-Migration Cleanup](#post-migration-cleanup)
9. [Troubleshooting](#troubleshooting)
10. [Reference](#reference)

---

## Current State Analysis

### Existing Vault Files

Located in `/ansible/group_vars/`:

```
all_vault.yml               # Global secrets (Tailscale auth keys, etc.)
k3s_cluster_vault.yml       # K3s cluster credentials and certificates
pihole_vault.yml            # Pi-hole admin password and API tokens
rancher_vault.yml           # Rancher admin credentials
haproxy_vault.yml           # HAProxy credentials
ts-recorder_vault.yml       # Tailscale recorder service credentials
```

**Template files** (`.template` suffix) are reference examples and do NOT contain real secrets.

### Vault Password Management

- Vault password stored in: `ansible/.vault_password` (gitignored)
- Used via: `--vault-password-file` flag or `ANSIBLE_VAULT_PASSWORD_FILE` env var
- All vault files encrypted with same master password

### Current Usage Pattern

Playbooks load vault files via `include_vars`:

```yaml
- name: Load vault variables
  ansible.builtin.include_vars:
    file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
```

Variables follow naming convention: `vault_<service>_<secret_name>`

Example:
```yaml
vault_pihole_admin_password: "encrypted_value"
vault_tailscale_auth_key: "tskey-auth-..."
vault_k3s_token: "K10..."
```

---

## Prerequisites

### Required Tools

1. **Bitwarden CLI (`bw`)**
   ```bash
   # macOS
   brew install bitwarden-cli

   # Linux
   snap install bw

   # Verify installation
   bw --version
   ```

2. **Bitwarden Secrets Manager SDK (`bws`)**
   ```bash
   # macOS
   brew install bitwarden/tap/bws

   # Linux - download from GitHub releases
   wget https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-unknown-linux-gnu.zip
   unzip bws-x86_64-unknown-linux-gnu.zip
   sudo mv bws /usr/local/bin/

   # Verify installation
   bws --version
   ```

3. **Ansible Collection for Bitwarden**
   ```bash
   ansible-galaxy collection install bitwarden.secrets
   ```

4. **jq** (for JSON processing)
   ```bash
   brew install jq  # macOS
   sudo apt install jq  # Debian/Ubuntu
   ```

### Bitwarden Account Setup

1. **Bitwarden Account** (if not already created)
   - Sign up at: https://vault.bitwarden.com
   - Verify email address
   - Enable two-factor authentication (recommended)

2. **Bitwarden Organization** (for Secrets Manager)
   - Create organization: Settings → Organizations → New Organization
   - Name: `HomeLab Infrastructure`
   - Plan: Secrets Manager (check pricing)

3. **Secrets Manager Access**
   - Navigate to organization → Secrets Manager
   - Verify access to Projects, Secrets, and Machine Accounts

### Required Permissions

- Ansible Vault password/key to decrypt existing vault files
- Bitwarden account with Secrets Manager admin permissions
- Ability to create machine accounts and access tokens

---

## Bitwarden Setup

### Step 1: Create Projects

Projects organize secrets by environment and service type.

**Recommended Project Structure:**

```
HomeLab Infrastructure (Organization)
├── global-secrets          # Cross-environment secrets
├── k3s-infrastructure      # Kubernetes cluster secrets
├── network-services        # DNS, DHCP, HAProxy, etc.
├── monitoring-services     # Prometheus, Grafana credentials
└── application-services    # App-specific secrets
```

**Create projects via CLI:**

```bash
# Login to Bitwarden
bw login

# Unlock vault
export BW_SESSION=$(bw unlock --raw)

# Create projects (requires organization ID)
ORG_ID="your-organization-id"

bw create item --organizationid "$ORG_ID" --collectionid "$COLLECTION_ID" <<EOF
{
  "type": 1,
  "name": "global-secrets",
  "notes": "Cross-environment global secrets",
  "organizationId": "$ORG_ID"
}
EOF
```

**Or create via Web UI:**
1. Login to Bitwarden web vault
2. Navigate to Organizations → Your Org → Secrets Manager
3. Click "New Project"
4. Name: `global-secrets`
5. Repeat for each project

### Step 2: Create Machine Accounts

Machine accounts provide authentication for automation contexts.

**Recommended Machine Accounts:**

```
homelab-ansible-dev         # Development/testing automation
homelab-ansible-staging     # Pre-production automation
homelab-ansible-prod        # Production automation
homelab-ci-cd               # CI/CD pipeline access
```

**Create via Web UI:**
1. Organizations → Your Org → Secrets Manager → Machine Accounts
2. Click "New Machine Account"
3. Name: `homelab-ansible-prod`
4. Grant access to relevant projects (e.g., all projects for prod)
5. Click "Create Access Token"
6. **IMPORTANT:** Copy and save the access token immediately (shown only once)
7. Store token in secure location (password manager, environment variable)

**Machine Account Token Format:**
```
0.48c78342-1635-48a6-accd-afbe00f5e0f1.C08vJlwF...
```

### Step 3: Configure Access Tokens

**For local development:**

```bash
# Add to ~/.bashrc or ~/.zshrc
export BWS_ACCESS_TOKEN="0.48c78342-1635-48a6-accd-afbe00f5e0f1.C08vJlwF..."

# Or use direnv for project-specific tokens
# Create .envrc in project root (gitignored)
export BWS_ACCESS_TOKEN="your-dev-token-here"
```

**For CI/CD pipelines:**
- Store token as encrypted secret in GitHub Actions, GitLab CI, etc.
- Inject as environment variable during playbook execution

**Security Best Practices:**
- Use separate tokens for dev/staging/prod
- Rotate tokens quarterly
- Revoke unused or compromised tokens immediately
- Never commit tokens to git (add to `.gitignore`)

---

## Migration Process

### Overview

**Migration Strategy:** Incremental migration with dual-read support

1. Maintain existing vault files (continue to work)
2. Export secrets to Bitwarden
3. Update playbooks to read from Bitwarden with vault fallback
4. Test thoroughly in dev environment
5. Gradually migrate staging, then production
6. Archive vault files after successful transition

### Step 1: Inventory and Categorize Secrets

Create a mapping of all secrets to their target Bitwarden projects.

**Inventory Script:**

```bash
#!/bin/bash
# File: scripts/inventory-vault-secrets.sh

ANSIBLE_DIR="/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible"
VAULT_PASSWORD_FILE="$ANSIBLE_DIR/.vault_password"
OUTPUT_FILE="secrets-inventory.csv"

echo "Vault File,Variable Name,Target Project,Notes" > "$OUTPUT_FILE"

# Function to extract variable names from vault file
extract_vars() {
    local vault_file=$1
    local project=$2

    # Decrypt and extract variable names
    ansible-vault view "$vault_file" --vault-password-file="$VAULT_PASSWORD_FILE" | \
    grep -E '^[a-z_]+:' | \
    awk -F: '{print $1}' | \
    while read var_name; do
        echo "$(basename $vault_file),$var_name,$project," >> "$OUTPUT_FILE"
    done
}

# Inventory each vault file
extract_vars "$ANSIBLE_DIR/group_vars/all_vault.yml" "global-secrets"
extract_vars "$ANSIBLE_DIR/group_vars/k3s_cluster_vault.yml" "k3s-infrastructure"
extract_vars "$ANSIBLE_DIR/group_vars/pihole_vault.yml" "network-services"
extract_vars "$ANSIBLE_DIR/group_vars/rancher_vault.yml" "k3s-infrastructure"
extract_vars "$ANSIBLE_DIR/group_vars/haproxy_vault.yml" "network-services"
extract_vars "$ANSIBLE_DIR/group_vars/ts-recorder_vault.yml" "monitoring-services"

echo "Inventory complete: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
```

**Run inventory:**
```bash
chmod +x scripts/inventory-vault-secrets.sh
./scripts/inventory-vault-secrets.sh
```

**Review output** and adjust project assignments as needed.

### Step 2: Export Secrets from Vault

**CRITICAL SECURITY NOTE:**
- Perform exports on secure, encrypted workstation
- Clear shell history after export (`history -c`)
- Delete temporary files after import to Bitwarden
- Use encrypted backups for vault files before migration

**Export Script:**

```bash
#!/bin/bash
# File: scripts/export-vault-secrets.sh

ANSIBLE_DIR="/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible"
VAULT_PASSWORD_FILE="$ANSIBLE_DIR/.vault_password"
EXPORT_DIR="$ANSIBLE_DIR/vault-exports"

# Create secure export directory
mkdir -p "$EXPORT_DIR"
chmod 700 "$EXPORT_DIR"

# Export each vault file to JSON
export_vault() {
    local vault_file=$1
    local output_name=$(basename "$vault_file" .yml)

    echo "Exporting: $vault_file"

    ansible-vault view "$vault_file" --vault-password-file="$VAULT_PASSWORD_FILE" | \
    python3 -c "
import sys, yaml, json
data = yaml.safe_load(sys.stdin)
print(json.dumps(data, indent=2))
" > "$EXPORT_DIR/${output_name}.json"

    # Secure the exported file
    chmod 600 "$EXPORT_DIR/${output_name}.json"
}

# Export all vault files
export_vault "$ANSIBLE_DIR/group_vars/all_vault.yml"
export_vault "$ANSIBLE_DIR/group_vars/k3s_cluster_vault.yml"
export_vault "$ANSIBLE_DIR/group_vars/pihole_vault.yml"
export_vault "$ANSIBLE_DIR/group_vars/rancher_vault.yml"
export_vault "$ANSIBLE_DIR/group_vars/haproxy_vault.yml"
export_vault "$ANSIBLE_DIR/group_vars/ts-recorder_vault.yml"

echo ""
echo "Exports complete in: $EXPORT_DIR"
echo "Files are temporarily unencrypted - handle with care!"
echo "Delete after importing to Bitwarden."
```

**Run export:**
```bash
chmod +x scripts/export-vault-secrets.sh
./scripts/export-vault-secrets.sh
```

**Expected Output:**
```
vault-exports/
├── all_vault.json
├── k3s_cluster_vault.json
├── pihole_vault.json
├── rancher_vault.json
├── haproxy_vault.json
└── ts-recorder_vault.json
```

### Step 3: Import Secrets to Bitwarden

**Manual Import (Recommended for First Time):**

1. Login to Bitwarden web vault
2. Navigate to organization → Secrets Manager → Projects
3. Select target project (e.g., `global-secrets`)
4. Click "New Secret"
5. Fill in details:
   - **Key:** `tailscale_auth_key` (use original vault variable name)
   - **Value:** The actual secret value from exported JSON
   - **Notes:** Original vault file, purpose, rotation schedule
6. Repeat for each secret

**Semi-Automated Import Script:**

```bash
#!/bin/bash
# File: scripts/import-to-bitwarden.sh

EXPORT_DIR="/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible/vault-exports"
BWS_CLI="bws"

# Ensure BWS_ACCESS_TOKEN is set
if [ -z "$BWS_ACCESS_TOKEN" ]; then
    echo "Error: BWS_ACCESS_TOKEN environment variable not set"
    exit 1
fi

# Function to create secret in Bitwarden
create_secret() {
    local key=$1
    local value=$2
    local project_id=$3
    local notes=$4

    echo "Creating secret: $key in project $project_id"

    bws secret create "$project_id" "$key" "$value" --note "$notes"
}

# Import secrets from all_vault.json to global-secrets project
GLOBAL_PROJECT_ID="your-global-secrets-project-id"

jq -r 'to_entries[] | "\(.key)|\(.value)"' "$EXPORT_DIR/all_vault.json" | \
while IFS='|' read key value; do
    create_secret "$key" "$value" "$GLOBAL_PROJECT_ID" "Migrated from all_vault.yml"
done

# Repeat for other vault files with appropriate project IDs
# K3S_PROJECT_ID="your-k3s-project-id"
# jq -r 'to_entries[] | "\(.key)|\(.value)"' "$EXPORT_DIR/k3s_cluster_vault.json" | \
# while IFS='|' read key value; do
#     create_secret "$key" "$value" "$K3S_PROJECT_ID" "Migrated from k3s_cluster_vault.yml"
# done

echo "Import complete"
```

**Get Project IDs:**
```bash
bws project list
```

**Run import:**
```bash
# Update script with actual project IDs
chmod +x scripts/import-to-bitwarden.sh
./scripts/import-to-bitwarden.sh
```

### Step 4: Verify Secrets in Bitwarden

**List all secrets:**
```bash
bws secret list --project-id "your-project-id"
```

**Retrieve specific secret:**
```bash
bws secret get "secret-id"
```

**Web UI verification:**
1. Login to Bitwarden web vault
2. Navigate to Secrets Manager → Projects
3. Click each project
4. Verify all secrets are present with correct values

---

## Playbook Updates

### Step 1: Install Bitwarden Ansible Collection

```bash
ansible-galaxy collection install bitwarden.secrets
```

Verify installation:
```bash
ansible-galaxy collection list | grep bitwarden
```

### Step 2: Update Playbook Structure (Dual-Read Pattern)

**Pattern:** Read from Bitwarden first, fall back to vault if not found.

**Example: Pi-hole Deployment Playbook**

**Before (Vault Only):**

```yaml
- name: Load Pi-hole configuration variables
  hosts: k3s_masters[0]
  gather_facts: false
  tags: [always]

  pre_tasks:
    - name: Load Pi-hole variables
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole.yml"
      tags: [always]

    - name: Load Pi-hole vault (if exists)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
      tags: [always]
```

**After (Dual-Read with Bitwarden Priority):**

```yaml
- name: Load Pi-hole configuration variables
  hosts: k3s_masters[0]
  gather_facts: false
  tags: [always]

  pre_tasks:
    - name: Load Pi-hole variables
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole.yml"
      tags: [always]

    # NEW: Load secrets from Bitwarden Secrets Manager
    - name: Load secrets from Bitwarden
      when: lookup('env', 'BWS_ACCESS_TOKEN') | length > 0
      block:
        - name: Retrieve Pi-hole admin password from Bitwarden
          ansible.builtin.set_fact:
            vault_pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'vault_pihole_admin_password') }}"
          no_log: true
          ignore_errors: true

        - name: Set Bitwarden secret retrieval status
          ansible.builtin.set_fact:
            using_bitwarden_secrets: true
          when: vault_pihole_admin_password is defined

    # FALLBACK: Load Pi-hole vault if Bitwarden not available
    - name: Load Pi-hole vault (fallback)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
      when: vault_pihole_admin_password is not defined
      tags: [always]

    - name: Display secret source
      ansible.builtin.debug:
        msg: "Using secrets from: {{ 'Bitwarden Secrets Manager' if using_bitwarden_secrets | default(false) else 'Ansible Vault' }}"
```

### Step 3: Create Reusable Secret Loading Role

**Role Structure:**

```
roles/load-bitwarden-secrets/
├── tasks/
│   └── main.yml
├── defaults/
│   └── main.yml
└── README.md
```

**roles/load-bitwarden-secrets/defaults/main.yml:**

```yaml
---
# Default configuration for Bitwarden secret loading
bitwarden_secrets: []  # List of secret keys to retrieve
bitwarden_project_id: ""  # Optional: filter by project
fallback_to_vault: true  # Enable vault fallback
vault_file: ""  # Path to vault file for fallback
```

**roles/load-bitwarden-secrets/tasks/main.yml:**

```yaml
---
- name: Check if Bitwarden access token is available
  ansible.builtin.set_fact:
    bws_token_available: "{{ lookup('env', 'BWS_ACCESS_TOKEN') | length > 0 }}"

- name: Load secrets from Bitwarden Secrets Manager
  when: bws_token_available
  block:
    - name: Retrieve secrets from Bitwarden
      ansible.builtin.set_fact:
        "{{ item }}": "{{ lookup('bitwarden.secrets.lookup', item) }}"
      loop: "{{ bitwarden_secrets }}"
      no_log: true
      ignore_errors: true

    - name: Report Bitwarden secret loading status
      ansible.builtin.debug:
        msg: "Successfully loaded {{ bitwarden_secrets | length }} secrets from Bitwarden"

- name: Fallback to Ansible Vault
  when: (not bws_token_available or fallback_to_vault) and vault_file | length > 0
  block:
    - name: Load vault file
      ansible.builtin.include_vars:
        file: "{{ vault_file }}"
      when: vault_file is file

    - name: Report vault loading status
      ansible.builtin.debug:
        msg: "Loaded secrets from Ansible Vault: {{ vault_file }}"
```

**Usage in Playbook:**

```yaml
- name: Load secrets for Pi-hole deployment
  hosts: k3s_masters[0]
  gather_facts: false

  roles:
    - role: load-bitwarden-secrets
      vars:
        bitwarden_secrets:
          - vault_pihole_admin_password
          - vault_pihole_api_token
        vault_file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
```

### Step 4: Update All Playbooks

**Recommended Order:**

1. **Development/Test Playbooks** (lowest risk)
   - Update test playbooks first
   - Validate Bitwarden integration
   - Fix any issues before production

2. **Non-Critical Services**
   - Pi-hole, monitoring tools
   - Services with easy rollback

3. **Infrastructure Services**
   - K3s cluster, Rancher
   - Test thoroughly in staging

4. **Critical Production Services**
   - HAProxy, DNS, core networking
   - Migrate during maintenance window

**Validation Checklist for Each Playbook:**

- [ ] Bitwarden collection imported
- [ ] BWS_ACCESS_TOKEN environment variable set
- [ ] Secret names match Bitwarden keys exactly
- [ ] Fallback to vault file configured
- [ ] `no_log: true` on all secret operations
- [ ] Testing completed in dev environment
- [ ] Rollback procedure documented

---

## Testing Strategy

### Test Environment Setup

**Create Test Inventory:**

```ini
# inventory/test.ini
[test_servers]
test-vm-01 ansible_host=10.2.0.50 ansible_user=ansible

[k3s_masters]
test-vm-01

[k3s_workers]
# None for basic testing
```

**Create Test Playbook:**

```yaml
# playbooks/test-bitwarden-integration.yml
---
- name: Test Bitwarden Secrets Manager Integration
  hosts: test_servers
  gather_facts: false

  tasks:
    - name: Test BWS_ACCESS_TOKEN availability
      ansible.builtin.debug:
        msg: "BWS token is {{ 'AVAILABLE' if lookup('env', 'BWS_ACCESS_TOKEN') | length > 0 else 'NOT AVAILABLE' }}"

    - name: Test secret retrieval
      block:
        - name: Retrieve test secret from Bitwarden
          ansible.builtin.set_fact:
            test_secret: "{{ lookup('bitwarden.secrets.lookup', 'vault_pihole_admin_password') }}"
          no_log: true

        - name: Validate secret retrieval
          ansible.builtin.assert:
            that:
              - test_secret is defined
              - test_secret | length > 0
            success_msg: "Secret successfully retrieved from Bitwarden"
            fail_msg: "Failed to retrieve secret from Bitwarden"

      rescue:
        - name: Handle Bitwarden lookup failure
          ansible.builtin.debug:
            msg: "Bitwarden lookup failed - will fall back to vault"

    - name: Test vault fallback
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
      when: test_secret is not defined
```

### Test Execution

**Step 1: Validate Token:**

```bash
export BWS_ACCESS_TOKEN="your-dev-token"
bws secret list
```

**Step 2: Run Test Playbook:**

```bash
cd ansible
ansible-playbook -i inventory/test.ini playbooks/test-bitwarden-integration.yml
```

**Expected Output:**
```
TASK [Test BWS_ACCESS_TOKEN availability]
ok: [test-vm-01] => {
    "msg": "BWS token is AVAILABLE"
}

TASK [Retrieve test secret from Bitwarden]
ok: [test-vm-01]

TASK [Validate secret retrieval]
ok: [test-vm-01] => {
    "changed": false,
    "msg": "Secret successfully retrieved from Bitwarden"
}
```

### Test Scenarios

**1. Bitwarden Available:**
```bash
export BWS_ACCESS_TOKEN="your-dev-token"
ansible-playbook playbooks/test-bitwarden-integration.yml
# Expect: Secrets loaded from Bitwarden
```

**2. Bitwarden Unavailable (Fallback to Vault):**
```bash
unset BWS_ACCESS_TOKEN
ansible-playbook playbooks/test-bitwarden-integration.yml --vault-password-file=.vault_password
# Expect: Secrets loaded from vault file
```

**3. Both Available (Bitwarden Priority):**
```bash
export BWS_ACCESS_TOKEN="your-dev-token"
ansible-playbook playbooks/test-bitwarden-integration.yml --vault-password-file=.vault_password
# Expect: Secrets loaded from Bitwarden (not vault)
```

### Integration Testing

**Test Full Service Deployment:**

```bash
# Test Pi-hole deployment with Bitwarden secrets
export BWS_ACCESS_TOKEN="your-dev-token"
ansible-playbook -i inventory/dev.ini playbooks/pihole-deploy.yml --check --diff

# Verify no errors, check diff output
# If satisfied, run without --check
ansible-playbook -i inventory/dev.ini playbooks/pihole-deploy.yml
```

**Validate Service Functionality:**
```bash
# Check Pi-hole web interface login with Bitwarden-sourced password
# Test DNS resolution
# Verify all service endpoints accessible
```

---

## Rollback Procedures

### Scenario 1: Bitwarden Integration Fails During Testing

**Symptoms:**
- Secret lookup failures
- Authentication errors
- Playbook execution failures

**Rollback Steps:**

1. **Unset Bitwarden token:**
   ```bash
   unset BWS_ACCESS_TOKEN
   ```

2. **Run playbook with vault fallback:**
   ```bash
   ansible-playbook playbooks/your-playbook.yml --vault-password-file=.vault_password
   ```

3. **Investigate errors:**
   ```bash
   # Check token validity
   bws secret list

   # Verify secret exists
   bws secret get "secret-id"

   # Check collection installation
   ansible-galaxy collection list | grep bitwarden
   ```

4. **Fix issues** and re-test before re-enabling Bitwarden

### Scenario 2: Production Deployment Fails After Migration

**Symptoms:**
- Service unavailable
- Authentication failures in production
- Critical infrastructure down

**IMMEDIATE ROLLBACK:**

1. **SSH to affected servers and restore from backup:**
   ```bash
   # If using vault file backups
   cd /path/to/ansible
   git checkout HEAD~1 -- group_vars/*/vault.yml
   ```

2. **Re-run deployment with vault:**
   ```bash
   unset BWS_ACCESS_TOKEN
   ansible-playbook -i inventory/prod.ini playbooks/restore-service.yml --vault-password-file=.vault_password
   ```

3. **Verify service restoration:**
   ```bash
   # Check service status
   ansible -i inventory/prod.ini all -m shell -a "systemctl status service-name"
   ```

4. **Post-incident review:**
   - Document what went wrong
   - Update migration procedures
   - Re-test in staging before retry

### Scenario 3: Corrupted Secrets in Bitwarden

**Symptoms:**
- Wrong secret values
- Services failing authentication
- Data integrity issues

**Recovery Steps:**

1. **Identify affected secrets:**
   ```bash
   bws secret list --project-id "project-id"
   ```

2. **Restore from vault exports:**
   ```bash
   # Re-import from vault-exports/*.json
   cd vault-exports
   jq -r '.vault_pihole_admin_password' pihole_vault.json
   # Manually update in Bitwarden web UI
   ```

3. **Verify secret correctness:**
   ```bash
   # Test retrieval
   bws secret get "secret-id"

   # Compare with original vault
   ansible-vault view group_vars/pihole_vault.yml --vault-password-file=.vault_password
   ```

4. **Re-deploy affected services:**
   ```bash
   export BWS_ACCESS_TOKEN="your-token"
   ansible-playbook playbooks/affected-service-deploy.yml
   ```

### Emergency Contact Procedure

If critical production failure:

1. **Disable Bitwarden integration globally:**
   ```bash
   # Create temporary wrapper script
   cat > run-ansible-vault-only.sh <<'EOF'
   #!/bin/bash
   unset BWS_ACCESS_TOKEN
   ansible-playbook "$@" --vault-password-file=.vault_password
   EOF
   chmod +x run-ansible-vault-only.sh
   ```

2. **Notify team of rollback**

3. **Document incident**

4. **Schedule post-mortem**

---

## Post-Migration Cleanup

### Step 1: Verify Migration Completeness

**Checklist:**

- [ ] All secrets accessible via Bitwarden
- [ ] All playbooks updated and tested
- [ ] Production deployments successful
- [ ] No vault file dependencies in active playbooks
- [ ] Team trained on Bitwarden access
- [ ] Documentation updated

### Step 2: Archive Vault Files

**DO NOT DELETE IMMEDIATELY** - Keep encrypted backups for 90 days minimum.

```bash
# Create archive directory
mkdir -p ansible/vault-archives/$(date +%Y-%m-%d)

# Move vault files to archive
mv group_vars/*_vault.yml ansible/vault-archives/$(date +%Y-%m-%d)/

# Keep templates for reference
# DO NOT archive .template files

# Create archive README
cat > ansible/vault-archives/$(date +%Y-%m-%d)/README.md <<EOF
# Vault Archive - $(date +%Y-%m-%d)

These vault files were archived after successful migration to Bitwarden Secrets Manager.

**Migration Date:** $(date +%Y-%m-%d)
**Archived By:** $(whoami)
**Retention Period:** 90 days minimum

## Files Archived
$(ls -1 ansible/vault-archives/$(date +%Y-%m-%d)/*.yml)

## Restoration Procedure
If restoration is needed:
1. Copy vault files back to group_vars/
2. Unset BWS_ACCESS_TOKEN
3. Run playbooks with --vault-password-file

## Deletion Schedule
Safe to delete after: $(date -d "+90 days" +%Y-%m-%d)
EOF
```

### Step 3: Update `.gitignore`

```bash
# Add archived vault files to .gitignore
echo "ansible/vault-archives/*_vault.yml" >> .gitignore
echo "ansible/vault-exports/" >> .gitignore
```

### Step 4: Remove Vault Password File (Optional)

**ONLY after 90-day retention period and confirmed migration success:**

```bash
# Securely delete vault password file
shred -vfz -n 10 ansible/.vault_password

# Remove from filesystem
rm ansible/.vault_password
```

### Step 5: Update Documentation

**Files to Update:**

1. **README.md** - Update secret management section
2. **CLAUDE.md** - Mark vault migration as complete
3. **DEVELOPMENT_PLAN.md** - Check off migration tasks
4. **ansible/README.md** - Update setup instructions

**Example Update for README.md:**

```markdown
## Secrets Management

This project uses **Bitwarden Secrets Manager** for centralized secret management.

### Setup

1. Install Bitwarden Secrets CLI:
   ```bash
   brew install bitwarden/tap/bws
   ```

2. Obtain access token from team lead

3. Set environment variable:
   ```bash
   export BWS_ACCESS_TOKEN="your-access-token"
   ```

4. Verify access:
   ```bash
   bws secret list
   ```

### Running Playbooks

```bash
export BWS_ACCESS_TOKEN="your-token"
ansible-playbook playbooks/your-playbook.yml
```

~~### Legacy Vault Files~~

~~Vault files have been archived and are no longer in active use.~~
~~See `ansible/vault-archives/` for historical reference.~~
```

### Step 6: Team Communication

**Announcement Template:**

```
Subject: Secrets Migration to Bitwarden Complete

Team,

The migration from Ansible Vault to Bitwarden Secrets Manager is now complete.

**What Changed:**
- All secrets now stored in Bitwarden Secrets Manager
- Vault files archived to ansible/vault-archives/
- Playbooks updated to use Bitwarden lookup

**Action Required:**
1. Install Bitwarden Secrets CLI: brew install bitwarden/tap/bws
2. Request access token from infrastructure team
3. Set BWS_ACCESS_TOKEN environment variable
4. Update local workflows to use Bitwarden

**Documentation:**
- Migration guide: ansible/SECRETS_MIGRATION.md
- Bitwarden setup: [link to internal docs]

**Support:**
Contact infrastructure team for token access or troubleshooting.

**Rollback Plan:**
Vault files retained for 90 days in case rollback needed.
```

---

## Troubleshooting

### Issue: `bitwarden.secrets` collection not found

**Error:**
```
ERROR! couldn't resolve module/action 'bitwarden.secrets.lookup'
```

**Solution:**
```bash
ansible-galaxy collection install bitwarden.secrets
ansible-galaxy collection list | grep bitwarden
```

### Issue: Secret lookup fails with "Unauthorized"

**Error:**
```
fatal: [host]: FAILED! => {"msg": "An unhandled exception occurred while running the lookup plugin 'bitwarden.secrets.lookup'. Error was a <class 'ansible.errors.AnsibleError'>, original message: Unauthorized"}
```

**Diagnostic Steps:**

1. **Verify token is set:**
   ```bash
   echo $BWS_ACCESS_TOKEN
   ```

2. **Test token directly:**
   ```bash
   bws secret list
   ```

3. **Check token permissions:**
   - Login to Bitwarden web vault
   - Navigate to Machine Accounts
   - Verify token has access to relevant projects

4. **Regenerate token if needed:**
   - Revoke old token
   - Create new access token
   - Update environment variable

### Issue: Secret exists but lookup returns empty

**Symptoms:**
```
TASK [Retrieve secret]
ok: [host] => {"ansible_facts": {"my_secret": ""}, "changed": false}
```

**Diagnostic Steps:**

1. **Verify secret key name:**
   ```bash
   bws secret list --project-id "project-id"
   # Ensure key matches exactly (case-sensitive)
   ```

2. **Check secret value:**
   ```bash
   bws secret get "secret-id"
   ```

3. **Verify project access:**
   ```bash
   bws project list
   # Ensure machine account has access
   ```

4. **Update Ansible lookup syntax:**
   ```yaml
   # Correct syntax
   vault_pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'vault_pihole_admin_password') }}"

   # Incorrect syntax (missing .secrets)
   vault_pihole_admin_password: "{{ lookup('bitwarden.lookup', 'vault_pihole_admin_password') }}"
   ```

### Issue: Playbook hangs during secret lookup

**Symptoms:**
- Playbook execution pauses at secret lookup task
- No error message displayed
- Eventually times out

**Causes:**
- Network connectivity issues
- Bitwarden API rate limiting
- Invalid token format

**Solutions:**

1. **Check network connectivity:**
   ```bash
   curl -I https://vault.bitwarden.com
   ```

2. **Verify Bitwarden API status:**
   - Check https://status.bitwarden.com

3. **Reduce concurrent lookups:**
   ```yaml
   # Instead of multiple parallel lookups, use serial
   - name: Load secrets sequentially
     ansible.builtin.set_fact:
       "{{ item }}": "{{ lookup('bitwarden.secrets.lookup', item) }}"
     loop:
       - secret1
       - secret2
     loop_control:
       pause: 1  # 1 second delay between lookups
   ```

### Issue: Different secrets needed per environment

**Scenario:**
- Dev, staging, and prod need different secret values
- Same playbook used across environments

**Solution: Environment-Specific Projects**

1. **Create environment projects:**
   - `homelab-dev-secrets`
   - `homelab-staging-secrets`
   - `homelab-prod-secrets`

2. **Use environment variable to select project:**
   ```yaml
   - name: Set environment-specific project
     ansible.builtin.set_fact:
       bw_project: "{{ lookup('env', 'DEPLOYMENT_ENV') | default('dev') }}"

   - name: Retrieve environment-specific secret
     ansible.builtin.set_fact:
       db_password: "{{ lookup('bitwarden.secrets.lookup', 'db_password', project=bw_project) }}"
   ```

3. **Set environment during execution:**
   ```bash
   export DEPLOYMENT_ENV="prod"
   ansible-playbook playbooks/deploy.yml
   ```

### Issue: Vault fallback not working

**Symptoms:**
- Bitwarden lookup fails
- Expected vault fallback doesn't occur
- Playbook fails completely

**Solution:**

Ensure proper error handling:

```yaml
- name: Load secrets with proper fallback
  block:
    - name: Try Bitwarden first
      ansible.builtin.set_fact:
        vault_pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'vault_pihole_admin_password') }}"
      when: lookup('env', 'BWS_ACCESS_TOKEN') | length > 0
      no_log: true
      ignore_errors: true
  rescue:
    - name: Fallback to vault file
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/pihole_vault.yml"
      when: vault_pihole_admin_password is not defined
```

---

## Reference

### Bitwarden Secrets Manager CLI Commands

**Common Operations:**

```bash
# List all secrets
bws secret list

# List secrets in specific project
bws secret list --project-id "project-id"

# Get secret details
bws secret get "secret-id"

# Create new secret
bws secret create "project-id" "secret-key" "secret-value"

# Update secret
bws secret edit "secret-id" --value "new-value"

# Delete secret
bws secret delete "secret-id"

# List projects
bws project list

# List machine accounts
# (Not available via CLI - use web UI)
```

### Ansible Lookup Plugin Syntax

**Basic Lookup:**
```yaml
my_variable: "{{ lookup('bitwarden.secrets.lookup', 'secret_key') }}"
```

**Lookup with Error Handling:**
```yaml
my_variable: "{{ lookup('bitwarden.secrets.lookup', 'secret_key', errors='ignore') | default('fallback_value') }}"
```

**Multiple Secret Retrieval:**
```yaml
- name: Load multiple secrets
  ansible.builtin.set_fact:
    "{{ item.name }}": "{{ lookup('bitwarden.secrets.lookup', item.key) }}"
  loop:
    - { name: 'db_password', key: 'vault_db_password' }
    - { name: 'api_key', key: 'vault_api_key' }
  no_log: true
```

### Environment Variables

```bash
# Required for Bitwarden Secrets CLI
export BWS_ACCESS_TOKEN="your-access-token"

# Optional: Deployment environment
export DEPLOYMENT_ENV="prod"

# Optional: Bitwarden server (for self-hosted)
export BW_SERVER="https://your-bitwarden-server.com"

# Legacy: Ansible Vault password file (during transition)
export ANSIBLE_VAULT_PASSWORD_FILE=".vault_password"
```

### Migration Timeline Example

**Week 1: Preparation**
- Day 1-2: Install tools, create Bitwarden organization
- Day 3-4: Create projects and machine accounts
- Day 5: Export and inventory vault secrets

**Week 2: Import and Testing**
- Day 1-2: Import secrets to Bitwarden
- Day 3-4: Update test playbooks
- Day 5: Integration testing in dev environment

**Week 3: Staging Deployment**
- Day 1-2: Update all playbooks
- Day 3: Deploy to staging environment
- Day 4-5: Staging validation and fixes

**Week 4: Production Migration**
- Day 1: Final staging validation
- Day 2-3: Production deployment (service by service)
- Day 4: Production validation
- Day 5: Documentation and team training

**Week 5+: Monitoring**
- Monitor for issues
- 30-day observation period
- 90-day vault retention before deletion

### Useful Links

**Bitwarden Documentation:**
- Secrets Manager: https://bitwarden.com/help/secrets-manager-overview/
- CLI Reference: https://bitwarden.com/help/secrets-manager-cli/
- API Documentation: https://bitwarden.com/help/api/

**Ansible Collections:**
- Bitwarden Secrets Collection: https://galaxy.ansible.com/bitwarden/secrets
- Collection Documentation: https://github.com/bitwarden/sm-ansible

**Security Best Practices:**
- Token Rotation: https://bitwarden.com/help/machine-accounts/
- Access Control: https://bitwarden.com/help/organizations/

---

## Summary

This migration guide provides a comprehensive, step-by-step approach to transitioning from Ansible Vault to Bitwarden Secrets Manager while maintaining system reliability and security.

**Key Principles:**
- Incremental migration with dual-read support
- Extensive testing before production deployment
- Comprehensive rollback procedures
- 90-day retention period for vault files
- Team training and documentation

**Success Criteria:**
- All secrets accessible via Bitwarden
- Zero downtime during migration
- All playbooks updated and functional
- Team members trained and productive
- Vault files safely archived

For questions or issues during migration, refer to the troubleshooting section or contact the infrastructure team.

**Document Version:** 1.0
**Last Updated:** 2025-10-31
**Author:** Infrastructure Automation Team
