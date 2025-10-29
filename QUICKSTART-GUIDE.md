# Bitwarden Secrets Manager Migration - Quick Start Guide

## Pre-Migration Checklist

### Week 0: Preparation
- [ ] Subscribe to Bitwarden Secrets Manager
- [ ] Review current DEVELOPMENT_PLAN.md thoroughly
- [ ] Back up all Ansible Vault files
- [ ] Document all vault passwords
- [ ] Install required tools (Python 3.11+, Ansible 2.19.3+)
- [ ] Set up development environment for testing

## Installation Commands

### Install Bitwarden CLI (Linux)
```bash
curl -LO https://github.com/bitwarden/sdk-sm/releases/latest/download/bws-x86_64-unknown-linux-gnu.zip
unzip bws-x86_64-unknown-linux-gnu.zip
sudo mv bws /usr/local/bin/
sudo chmod +x /usr/local/bin/bws
bws --version
```

### Install Ansible Collection
```bash
pip install bitwarden-sdk
ansible-galaxy collection install bitwarden.secrets
ansible-galaxy collection list | grep bitwarden
```

### macOS Configuration
```bash
# Add to ~/.zshrc or ~/.bashrc
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

## Quick Reference: Ansible Conversion

### Before (Ansible Vault)
```yaml
---
- name: Deploy Application
  hosts: webservers
  vars_files:
    - vars/vault.yml
  tasks:
    - name: Configure database
      postgresql_user:
        password: "{{ vault_db_password }}"
```

### After (Bitwarden Secrets Manager)
```yaml
---
- name: Deploy Application
  hosts: webservers
  tasks:
    - name: Configure database
      postgresql_user:
        password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
      no_log: true
```

## Common CLI Commands

### Authentication
```bash
# Set access token as environment variable
export BWS_ACCESS_TOKEN="<your-access-token>"

# Verify authentication
bws secret list
```

### Secret Management
```bash
# List all secrets
bws secret list

# Get specific secret
bws secret get <secret-id>

# Create new secret
bws secret create "secret-key" "secret-value" "<project-id>"

# Update secret
bws secret edit <secret-id> --value "new-value"

# Delete secret
bws secret delete <secret-id>
```

### Project Management
```bash
# List projects
bws project list

# Create project
bws project create "Project Name"

# Get project details
bws project get <project-id>
```

## Migration Script Templates

### 1. Find All Vault Files
```bash
#!/bin/bash
# find-vault-files.sh
find . -type f -exec grep -l '\$ANSIBLE_VAULT' {} \; > vault_files.txt
echo "Found $(wc -l < vault_files.txt) vault files"
```

### 2. Decrypt All Vaults
```bash
#!/bin/bash
# decrypt-vaults.sh
VAULT_PASSWORD_FILE="~/.vault_pass"
OUTPUT_DIR="decrypted-secrets"
mkdir -p "$OUTPUT_DIR"

while IFS= read -r vault_file; do
    output_file="$OUTPUT_DIR/$(basename "$vault_file").decrypted"
    ansible-vault decrypt \
        --vault-password-file="$VAULT_PASSWORD_FILE" \
        --output="$output_file" \
        "$vault_file"
done < vault_files.txt
```

### 3. Export Secrets to JSON
```python
#!/usr/bin/env python3
# export-to-json.py
import yaml
import json
import sys

def export_vault_to_json(vault_file, environment):
    with open(vault_file, 'r') as f:
        data = yaml.safe_load(f)

    secrets = []
    for key, value in data.items():
        secrets.append({
            "key": f"{environment}-{key}",
            "value": str(value),
            "note": f"Migrated from {vault_file}"
        })

    output = f"secrets-{environment}.json"
    with open(output, 'w') as f:
        json.dump(secrets, f, indent=2)

    print(f"Exported {len(secrets)} secrets to {output}")

if __name__ == "__main__":
    export_vault_to_json(sys.argv[1], sys.argv[2])
```

### 4. Import to Bitwarden
```bash
#!/bin/bash
# import-to-bitwarden.sh
export BWS_ACCESS_TOKEN="<your-token>"
PROJECT_ID="<your-project-id>"

jq -c '.[]' secrets-production.json | while read -r secret; do
    KEY=$(echo "$secret" | jq -r '.key')
    VALUE=$(echo "$secret" | jq -r '.value')
    NOTE=$(echo "$secret" | jq -r '.note')

    echo "Creating: $KEY"
    bws secret create "$KEY" "$VALUE" "$PROJECT_ID" --note "$NOTE"
done
```

## Testing Checklist

### Phase Testing
- [ ] CLI authentication works
- [ ] Can list all secrets
- [ ] Can retrieve individual secrets
- [ ] Ansible collection installed correctly
- [ ] Test playbook runs successfully
- [ ] Secrets retrieved match vault values
- [ ] No secrets appear in logs (no_log: true works)
- [ ] CI/CD integration functional
- [ ] Event logs show access patterns
- [ ] Token rotation procedure works

### Security Validation
- [ ] No tokens in git history
- [ ] Environment variables properly set
- [ ] Machine accounts have least-privilege access
- [ ] Access tokens have expiration dates
- [ ] Event logging enabled
- [ ] Backup procedures tested
- [ ] Rollback procedures documented

## Troubleshooting

### "Module bitwarden.secrets not found"
```bash
pip install bitwarden-sdk
ansible-galaxy collection install bitwarden.secrets
```

### "Authentication failed"
```bash
# Check token is set
echo $BWS_ACCESS_TOKEN

# Test manually
bws secret list

# Verify token hasn't expired (check web app)
```

### "Secret not found"
```bash
# List all accessible secrets with IDs
bws secret list | jq '.[] | {key: .key, id: .id}'

# Verify machine account has project access
```

### macOS fork() error
```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
# Add to ~/.zshrc permanently
```

## CI/CD Integration Examples

### GitHub Actions
```yaml
name: Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: |
          pip install ansible bitwarden-sdk
          ansible-galaxy collection install bitwarden.secrets
      - name: Run playbook
        env:
          BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
        run: ansible-playbook deploy.yml
```

### GitLab CI
```yaml
deploy:
  script:
    - pip install ansible bitwarden-sdk
    - ansible-galaxy collection install bitwarden.secrets
    - export BWS_ACCESS_TOKEN=$BWS_ACCESS_TOKEN
    - ansible-playbook deploy.yml
  only:
    - main
```

## Security Best Practices

### DO:
- ✓ Use environment variables for tokens
- ✓ Enable `no_log: true` on sensitive tasks
- ✓ Rotate tokens every 90 days
- ✓ Use separate tokens per environment
- ✓ Review event logs regularly
- ✓ Back up secrets before changes
- ✓ Test in dev before production
- ✓ Document all changes

### DON'T:
- ✗ Never commit tokens to git
- ✗ Never log secret values
- ✗ Never share tokens between environments
- ✗ Never use personal accounts for automation
- ✗ Never skip the no_log directive
- ✗ Never delete vault backups immediately
- ✗ Never deploy without testing

## Emergency Rollback

### If Migration Fails
```bash
# 1. Restore vault access
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass

# 2. Revert playbooks
git checkout <pre-migration-commit> playbooks/

# 3. Remove Bitwarden collection
ansible-galaxy collection remove bitwarden.secrets

# 4. Verify vault works
ansible-playbook --check playbooks/test.yml
```

### If Token Compromised
```bash
# 1. Immediately revoke in web app:
#    Machine Accounts → Access Tokens → Revoke

# 2. Generate new token with expiration

# 3. Update all systems with new token

# 4. Review event logs for unauthorized access

# 5. Rotate affected secrets
```

## Contact & Resources

### Documentation
- Full Plan: DEVELOPMENT_PLAN.md
- Task List: bitwarden_migration_tasks.csv
- Bitwarden Docs: https://bitwarden.com/help/secrets-manager-overview/
- Ansible Collection: https://galaxy.ansible.com/bitwarden/secrets

### Support
- Bitwarden Support: https://bitwarden.com/contact/
- Ansible Docs: https://docs.ansible.com/
- Community: https://community.bitwarden.com/

### Key Contacts
- Project Lead: [Your Name]
- Security Review: [Security Contact]
- Operations: [Ops Contact]

---

**Quick Start Guide Version**: 1.0
**Last Updated**: October 29, 2025
**For Use With**: DEVELOPMENT_PLAN.md v1.0
