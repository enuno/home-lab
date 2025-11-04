# Ansible Vault to Bitwarden Secrets Manager Migration Tool

Automated migration tool for transitioning secrets from Ansible Vault to Bitwarden Secrets Manager (BWS).

## Overview

This tool scans your Ansible directory for vault-encrypted files, extracts secrets, and migrates them to Bitwarden Secrets Manager while maintaining full traceability through detailed mapping files.

### Key Features

- **Automatic Dependency Management**: Checks and installs/updates `ansible-vault` and `bws` CLI tools
- **Smart Vault Discovery**: Recursively scans for encrypted vault files
- **Memory-Safe Decryption**: Never writes decrypted secrets to disk
- **Intelligent Secret Naming**: Generates structured secret names following best practices
- **Comprehensive Mapping**: Creates detailed CSV mapping of vault variables to BWS secret IDs
- **Dry Run Mode**: Preview migration without creating any secrets
- **Error Handling**: Robust error handling with detailed logging
- **Cross-Platform**: Works on macOS and Linux

## Prerequisites

### Required Tools (Auto-installed if missing)

1. **ansible-core** (>= 2.19.0)
   - Contains the `ansible-vault` command
   - Auto-installed via pip if missing

2. **bws** (>= 1.0.0)
   - Bitwarden Secrets Manager CLI
   - Auto-installed via cargo, brew, or direct download

3. **Python 3**
   - Required for YAML parsing
   - Usually pre-installed on most systems

### Authentication Requirements

#### Ansible Vault Authentication

**Option 1: Vault Password File (Recommended)**
```bash
# Create .vault_password file in your ansible directory
echo "your-vault-password" > ~/.ansible/.vault_password
chmod 600 ~/.ansible/.vault_password
```

**Option 2: Interactive Password Prompt**
- If no `.vault_password` file is found, the script will prompt for the password when needed

#### Bitwarden Secrets Manager Authentication

**Required: BWS_ACCESS_TOKEN environment variable**

```bash
# For bash
export BWS_ACCESS_TOKEN="your-machine-account-token"
echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.bashrc

# For zsh
export BWS_ACCESS_TOKEN="your-machine-account-token"
echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.zshrc

# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc
```

**Getting your BWS Access Token:**

1. Log in to your Bitwarden web vault
2. Navigate to **Organization** → **Settings** → **Machine Accounts**
3. Create a new machine account (e.g., "ansible-automation")
4. Grant appropriate project access
5. Generate an access token
6. Copy the token (it will only be shown once!)

## Installation

```bash
# Navigate to your home-lab repository
cd /path/to/home-lab

# The script is located at:
# scripts/vault-bws-migration/migrate-vault-to-bws.sh

# Make executable (should already be done)
chmod +x scripts/vault-bws-migration/migrate-vault-to-bws.sh
```

## Usage

### Basic Usage

```bash
# Migrate from default ansible directory (/etc/ansible)
./scripts/vault-bws-migration/migrate-vault-to-bws.sh

# Migrate from custom ansible directory
./scripts/vault-bws-migration/migrate-vault-to-bws.sh --ansible-dir ./ansible

# For this repository specifically:
cd scripts/vault-bws-migration
./migrate-vault-to-bws.sh --ansible-dir ../../ansible
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--ansible-dir PATH` | Path to ansible directory | `/etc/ansible` |
| `--project-id ID` | Bitwarden project ID for organizing secrets | None |
| `--environment ENV` | Environment tag (prod/staging/dev) | `prod` |
| `--dry-run` | Preview migration without creating secrets | Disabled |
| `--verbose` | Enable verbose debug output | Disabled |
| `-h, --help` | Display help message | - |
| `-v, --version` | Display script version | - |

### Examples

#### 1. Dry Run (Preview Only)

Preview what secrets would be migrated without actually creating them:

```bash
./migrate-vault-to-bws.sh \
  --ansible-dir ../../ansible \
  --dry-run \
  --verbose
```

**Output:**
- Shows all vault files that would be processed
- Lists all secrets that would be created
- No actual secrets created in Bitwarden
- Safe to run multiple times

#### 2. Production Migration

Migrate all production secrets with project organization:

```bash
./migrate-vault-to-bws.sh \
  --ansible-dir ../../ansible \
  --project-id "abc123-def456-ghi789" \
  --environment prod \
  --verbose
```

#### 3. Staging Environment Migration

Migrate staging secrets with different naming:

```bash
./migrate-vault-to-bws.sh \
  --ansible-dir /path/to/staging/ansible \
  --environment staging \
  --project-id "staging-project-id"
```

#### 4. Verbose Debugging

Run with maximum output for troubleshooting:

```bash
./migrate-vault-to-bws.sh \
  --ansible-dir ../../ansible \
  --verbose \
  --dry-run
```

## Output Files

All output files are saved to `scripts/vault-bws-migration/migration-output/` with timestamps:

### 1. Migration Report (`migration-report-YYYYMMDD_HHMMSS.txt`)

Human-readable summary of the migration:

```
════════════════════════════════════════════════════════════════
Ansible Vault to Bitwarden Secrets Manager Migration Report
════════════════════════════════════════════════════════════════

Migration Date: 2025-11-02 14:30:00
Ansible Directory: /Users/elvis/ansible
Environment: prod
Project ID: abc123

────────────────────────────────────────────────────────────────
Statistics
────────────────────────────────────────────────────────────────
Vault Files Processed: 5
Secrets Discovered: 23
Secrets Created: 23
Errors: 0

────────────────────────────────────────────────────────────────
Next Steps
────────────────────────────────────────────────────────────────
1. Review the secret mapping file
2. Update Ansible playbooks to use Bitwarden lookup
3. Test playbooks in staging environment
4. Archive vault files after successful migration
```

### 2. Secret Mapping (`secret-mapping-YYYYMMDD_HHMMSS.csv`)

CSV file mapping vault variables to Bitwarden secrets:

```csv
"Vault Variable","BWS Secret Name","BWS Secret ID","Source File"
"vault_pihole_admin_password","prod-pihole-vault-pihole-admin-password","secret-id-1","ansible/group_vars/pihole_vault.yml"
"vault_tailscale_auth_key","prod-k3s-cluster-vault-tailscale-auth-key","secret-id-2","ansible/group_vars/k3s_cluster_vault.yml"
"vault_rancher_bootstrap_password","prod-rancher-vault-rancher-bootstrap-password","secret-id-3","ansible/group_vars/rancher_vault.yml"
```

**Use this file to:**
- Update your Ansible playbooks with the correct secret IDs
- Track which secrets came from which vault files
- Audit the migration for completeness
- Reference during playbook updates

### 3. Error Log (`errors-YYYYMMDD_HHMMSS.log`)

Only created if errors occur during migration. Contains detailed error information for troubleshooting.

## Secret Naming Convention

The script generates Bitwarden secret names following this pattern:

```
{environment}-{service}-{secret-type}
```

### Examples

| Vault Variable | Service (from filename) | Generated BWS Name |
|----------------|-------------------------|-------------------|
| `vault_pihole_admin_password` | `pihole_vault.yml` → `pihole` | `prod-pihole-vault-pihole-admin-password` |
| `vault_tailscale_auth_key` | `k3s_cluster_vault.yml` → `k3s-cluster` | `prod-k3s-cluster-vault-tailscale-auth-key` |
| `vault_rancher_bootstrap_password` | `rancher_vault.yml` → `rancher` | `prod-rancher-vault-rancher-bootstrap-password` |
| `vault_haproxy_stats_password` | `haproxy_vault.yml` → `haproxy` | `prod-haproxy-vault-haproxy-stats-password` |

**Note:** Variables with `vault_` prefix follow this project's naming convention for select sensitive variables (see [CLAUDE.md](../../CLAUDE.md#ansible-vault-conventions)).

### Custom Environment

With `--environment staging`:

```
staging-pihole-admin-password
staging-k3s-cluster-token
staging-rancher-bootstrap-password
```

## Updating Ansible Playbooks

After migration, update your playbooks to use Bitwarden lookups:

### Before Migration (Ansible Vault)

```yaml
# group_vars/pihole_vault.yml (encrypted)
vault_pihole_admin_password: "changeme123"
```

### After Migration (Bitwarden Secrets Manager)

```yaml
# group_vars/pihole.yml (unencrypted - references BWS)
pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-pihole-vault-pihole-admin-password') }}"

# Or reference by secret ID (from mapping file)
pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'abcd-1234-efgh-5678') }}"

# Note: The BWS secret name includes 'vault-' from the original variable name
```

### Parallel Operation (Recommended During Transition)

Keep vault fallback during migration:

```yaml
# group_vars/pihole.yml
pihole_admin_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-pihole-vault-pihole-admin-password', default=vault_pihole_admin_password | default('')) }}"
```

This allows:
- Testing Bitwarden integration without breaking existing playbooks
- Graceful rollback if issues occur
- Gradual migration of services

## Workflow: Complete Migration Process

### Phase 1: Preparation

1. **Install Dependencies**
   ```bash
   # Script will auto-install, or manually:
   pip install ansible-core>=2.19.0
   cargo install bws  # or brew install bitwarden/tap/bws
   ```

2. **Set Up Bitwarden**
   - Create organization and projects
   - Create machine account
   - Set `BWS_ACCESS_TOKEN` environment variable
   - Test authentication: `bws secret list`

3. **Backup Existing Vault Files**
   ```bash
   cd ansible
   tar czf vault-backup-$(date +%Y%m%d).tar.gz group_vars/*_vault.yml
   gpg --encrypt --recipient your-email@example.com vault-backup-*.tar.gz
   ```

### Phase 2: Migration

4. **Dry Run**
   ```bash
   ./migrate-vault-to-bws.sh --ansible-dir ../../ansible --dry-run --verbose
   ```

5. **Review Output**
   - Check that all expected secrets are found
   - Verify secret naming makes sense
   - Ensure no secrets are missing

6. **Execute Migration**
   ```bash
   ./migrate-vault-to-bws.sh \
     --ansible-dir ../../ansible \
     --project-id "your-project-id" \
     --environment prod
   ```

7. **Verify in Bitwarden**
   ```bash
   bws secret list
   ```

### Phase 3: Playbook Updates

8. **Update One Playbook (Pilot)**
   - Choose non-critical service (e.g., Nostr relay)
   - Update group_vars to use Bitwarden lookup
   - Test in staging/dev environment
   - Validate service functionality

9. **Update Remaining Playbooks**
   - Use the mapping CSV as reference
   - Update service by service
   - Test each one before moving to next
   - Maintain vault fallback during transition

### Phase 4: Validation

10. **Test All Services**
    ```bash
    # Test deployment with Bitwarden secrets
    ansible-playbook -i inventory/prod.ini playbooks/deploy-pihole.yml --check
    ansible-playbook -i inventory/prod.ini playbooks/deploy-k3s.yml --check
    ```

11. **Monitor for Issues**
    - Check service logs
    - Verify authentication works
    - Ensure no service disruptions

### Phase 5: Cleanup

12. **Archive Vault Files** (after 2+ weeks of successful operation)
    ```bash
    mkdir -p ansible/archive/vault-$(date +%Y%m%d)
    mv ansible/group_vars/*_vault.yml ansible/archive/vault-$(date +%Y%m%d)/
    ```

13. **Update Documentation**
    - Update README files with Bitwarden instructions
    - Remove references to vault password files
    - Document new secret management workflow

## Troubleshooting

### Issue: Dependency Installation Fails

**Error:** `Failed to install ansible-core via pip`

**Solutions:**
```bash
# Ensure pip is up to date
pip install --upgrade pip

# Try with pip3 specifically
pip3 install ansible-core>=2.19.0

# Install with user flag
pip install --user ansible-core>=2.19.0
```

**Error:** `Failed to install bws`

**Solutions:**
```bash
# Try different installation methods in order:

# 1. Cargo (Rust package manager)
cargo install bws

# 2. Homebrew (macOS)
brew install bitwarden/tap/bws

# 3. Direct download
mkdir -p ~/.local/bin
curl -L -o ~/.local/bin/bws \
  https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-apple-darwin
chmod +x ~/.local/bin/bws
export PATH="$PATH:$HOME/.local/bin"
```

### Issue: BWS_ACCESS_TOKEN Not Set

**Error:** `BWS_ACCESS_TOKEN environment variable is not set`

**Solution:**
```bash
# Set token for current session
export BWS_ACCESS_TOKEN="your-token-here"

# Make permanent (bash)
echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.bashrc
source ~/.bashrc

# Make permanent (zsh)
echo 'export BWS_ACCESS_TOKEN="your-token"' >> ~/.zshrc
source ~/.zshrc

# Verify
echo $BWS_ACCESS_TOKEN
```

### Issue: Vault Decryption Fails

**Error:** `Failed to decrypt: vault file`

**Solutions:**
```bash
# Verify vault password is correct
ansible-vault view ansible/group_vars/pihole_vault.yml

# Check .vault_password file exists
ls -la ansible/.vault_password

# Verify file permissions
chmod 600 ansible/.vault_password

# Try with --ask-vault-password (interactive)
# Script will auto-detect if .vault_password is missing
```

### Issue: Bitwarden Authentication Fails

**Error:** `Failed to authenticate with Bitwarden Secrets Manager`

**Solutions:**
```bash
# Test bws authentication
bws secret list

# Verify token is valid (not expired)
# Log in to Bitwarden web vault and check machine account

# Regenerate token if expired
# Update BWS_ACCESS_TOKEN with new token

# Check network connectivity to Bitwarden
curl -I https://api.bitwarden.com
```

### Issue: No Vault Files Found

**Error:** `No encrypted vault files found`

**Solutions:**
```bash
# Verify ansible directory path
ls -la /path/to/ansible/group_vars/

# Check for encrypted files manually
grep -r "ANSIBLE_VAULT" ansible/group_vars/

# Ensure files match naming pattern: *vault*.yml
# Script looks for: *vault*.yml or *vault*.yaml

# Check file is actually encrypted
head -n1 ansible/group_vars/pihole_vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256
```

### Issue: Secret Creation Fails

**Error:** `Failed to create secret: <name>`

**Possible Causes:**
1. **Duplicate secret name**: Secret with that name already exists
2. **Invalid project ID**: Project doesn't exist or no access
3. **Permission denied**: Machine account lacks create permission
4. **Invalid secret value**: Contains unsupported characters

**Solutions:**
```bash
# Check if secret exists
bws secret list | grep "secret-name"

# Delete duplicate (if safe to do so)
bws secret delete <secret-id>

# Verify project ID
bws project list

# Check machine account permissions in Bitwarden web vault

# Try creating manually to see exact error
bws secret create "test-secret" "test-value"
```

## Best Practices

### 1. Always Start with Dry Run

```bash
./migrate-vault-to-bws.sh --ansible-dir ../../ansible --dry-run
```

- Validates all steps without making changes
- Identifies issues before actual migration
- Safe to run multiple times

### 2. Backup Before Migration

```bash
cd ansible
tar czf vault-backup-$(date +%Y%m%d).tar.gz group_vars/*_vault.yml
gpg --encrypt --recipient your-email@example.com vault-backup-*.tar.gz
mv vault-backup-*.tar.gz.gpg ~/secure-backups/
```

### 3. Use Project Organization

```bash
# Create separate projects for environments
./migrate-vault-to-bws.sh \
  --project-id "prod-project-id" \
  --environment prod

./migrate-vault-to-bws.sh \
  --project-id "staging-project-id" \
  --environment staging
```

### 4. Keep Mapping Files

- Store `secret-mapping-*.csv` in secure location
- Version control is OK (no secret values in file)
- Reference when updating playbooks
- Use for audit and compliance

### 5. Implement Parallel Operation

During transition period, support both vault and Bitwarden:

```yaml
my_secret: "{{ lookup('bitwarden.secrets.lookup', 'bws-id', default=vault_my_secret | default('')) }}"
```

### 6. Test Incrementally

- Migrate one service at a time
- Test thoroughly before moving to next
- Keep rollback procedure ready
- Monitor for issues

### 7. Document Everything

- Update README files with new workflow
- Document secret naming conventions
- Keep migration reports
- Train team members

## Security Considerations

### ✅ Good Practices

- **Never commit** `.vault_password` files
- **Never commit** `BWS_ACCESS_TOKEN` to git
- **Always use** machine accounts for automation
- **Rotate** machine account tokens quarterly
- **Enable** audit logging in Bitwarden
- **Use** project-based access controls
- **Backup** vault files before migration
- **Test** in non-production first

### ❌ Avoid

- Don't use personal Bitwarden accounts for automation
- Don't store BWS_ACCESS_TOKEN in plain text files
- Don't skip dry run before actual migration
- Don't delete vault files immediately after migration
- Don't grant machine accounts more access than needed

## Migration Script Details

### Files Processed

The script scans for these patterns:
- `*vault*.yml`
- `*vault*.yaml`

In these directories:
- `group_vars/`
- `host_vars/`

### Files Skipped

- Template files: `*.template`
- Unencrypted files (no `$ANSIBLE_VAULT` header)
- Hidden files (`.`)

### Variables Extracted

All variables from vault files are extracted:
- ✅ `vault_pihole_admin_password` (standard pattern with `vault_` prefix)
- ✅ `vault_tailscale_auth_key` (select sensitive variables)
- ✅ `vault_rancher_bootstrap_password` (prefixed for easy identification)
- ✅ Entire config files without prefix (when entire file is the secret)
- ❌ Commented out variables (YAML parser loads these as None)

**Note:** This project follows the convention of prefixing select sensitive variables with `vault_` for easy identification in playbooks. See [CLAUDE.md - Ansible Vault Conventions](../../CLAUDE.md#ansible-vault-conventions) for details.

## FAQ

**Q: Will this script modify my vault files?**
A: No. The script only reads vault files. All decryption happens in memory.

**Q: Can I run this multiple times?**
A: Yes, but Bitwarden may reject duplicate secret names. Use `--dry-run` for testing.

**Q: What if I don't have a .vault_password file?**
A: The script will prompt for the password interactively when decrypting files.

**Q: Can I migrate only specific vault files?**
A: Not currently. The script processes all encrypted vault files found. You can manually filter the results afterward.

**Q: Does this work with Ansible Vault 2.0 format?**
A: Yes, the script supports all Ansible Vault formats (1.1, 1.2, 2.0).

**Q: What happens to nested secrets in YAML?**
A: Nested structures are flattened and converted to JSON strings for storage in Bitwarden.

**Q: Can I customize the secret naming pattern?**
A: Not currently via CLI, but you can modify the `generate_secret_name()` function in the script.

## Support

For issues, questions, or contributions:

- **GitHub Issues**: [Report issues](https://github.com/your-repo/home-lab/issues)
- **Documentation**: See [CLAUDE.md](../../CLAUDE.md) for project context
- **Migration Guide**: See [DEVELOPMENT_PLAN.md](../../DEVELOPMENT_PLAN.md) for complete migration strategy

## License

MIT License - See [LICENSE](../../LICENSE) file for details.

## Version History

### v1.0.0 (2025-11-02)
- Initial release
- Automatic dependency management
- Dry run support
- Cross-platform support (macOS, Linux)
- Comprehensive mapping and reporting
- Robust error handling
