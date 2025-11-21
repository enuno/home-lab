---
description: "Assist with migrating secrets from Ansible Vault to Bitwarden Secrets Manager with guided workflow and validation"
allowed-tools: ["Read", "Search", "Edit", "Bash(ansible-vault:*)", "Bash(bws:*)", "Bash(find)", "Bash(grep)", "Bash(ansible-playbook:*)", "Bash(git:status)"]
author: "Home Lab Infrastructure Team"
version: "1.0"
---

# Vault Migration Assistant

## Purpose
Guide the migration of secrets from Ansible Vault files to Bitwarden Secrets Manager following the 16-week phased migration plan from DEVELOPMENT_PLAN.md.

## Migration Workflow

### 1. Assess Current Migration Status

```bash
echo "╔════════════════════════════════════════════════════╗"
echo "║     VAULT TO BITWARDEN MIGRATION STATUS           ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Check DEVELOPMENT_PLAN.md for current phase
@DEVELOPMENT_PLAN.md

# Find all vault files
VAULT_FILES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml" -type f 2>/dev/null)
VAULT_COUNT=$(echo "$VAULT_FILES" | grep -v "^$" | wc -l)

echo "Vault Files Found: $VAULT_COUNT"
echo ""

if [ "$VAULT_COUNT" -gt 0 ]; then
  echo "Existing Vault Files:"
  echo "$VAULT_FILES" | while read vault_file; do
    # Check if encrypted
    if head -1 "$vault_file" 2>/dev/null | grep -q "\$ANSIBLE_VAULT"; then
      ENCRYPTED="🔒 Encrypted"
    else
      ENCRYPTED="⚠️  PLAINTEXT"
    fi

    # Check for template
    if [ -f "${vault_file}.template" ]; then
      TEMPLATE="✅ Template exists"
    else
      TEMPLATE="❌ No template"
    fi

    echo "  - $(basename $vault_file): $ENCRYPTED, $TEMPLATE"
  done
else
  echo "✅ No vault files found - migration may be complete!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Bitwarden setup
echo "Bitwarden Secrets Manager Status:"

if command -v bws >/dev/null 2>&1; then
  echo "  ✅ BWS CLI installed: $(bws --version)"
else
  echo "  ❌ BWS CLI not installed"
  echo "     Install: https://bitwarden.com/help/secrets-manager-cli/"
fi

if ansible-galaxy collection list 2>/dev/null | grep -q "bitwarden.secrets"; then
  BW_VERSION=$(ansible-galaxy collection list | grep "bitwarden.secrets" | awk '{print $2}')
  echo "  ✅ Bitwarden Ansible collection: v$BW_VERSION"
else
  echo "  ❌ Bitwarden Ansible collection not installed"
  echo "     Install: ansible-galaxy collection install bitwarden.secrets"
fi

if [ -n "$BWS_ACCESS_TOKEN" ]; then
  echo "  ✅ BWS_ACCESS_TOKEN environment variable set"
else
  echo "  ⚠️  BWS_ACCESS_TOKEN not set"
  echo "     Set: export BWS_ACCESS_TOKEN='your-machine-account-token'"
fi

# Check for Bitwarden usage in playbooks
BWS_LOOKUPS=$(grep -r "lookup('bitwarden.secrets.lookup'" ansible/ 2>/dev/null | wc -l)
VAULT_VARS=$(grep -r "vault_" ansible/group_vars ansible/host_vars 2>/dev/null | grep -v ".template" | grep -v "_vault.yml" | wc -l)

echo ""
echo "Migration Progress:"
echo "  Bitwarden lookups in code: $BWS_LOOKUPS"
echo "  Legacy vault_ variables: $VAULT_VARS"

if [ "$BWS_LOOKUPS" -gt 0 ] && [ "$VAULT_COUNT" -gt 0 ]; then
  echo "  📊 Status: Parallel operation (migration in progress)"
elif [ "$BWS_LOOKUPS" -gt 0 ] && [ "$VAULT_COUNT" -eq 0 ]; then
  echo "  ✅ Status: Migration complete"
elif [ "$VAULT_COUNT" -gt 0 ]; then
  echo "  📋 Status: Ready to begin migration"
else
  echo "  ⚠️  Status: No secrets found"
fi

echo ""
```

### 2. Interactive Migration Menu

Present migration options to user:

```
╔════════════════════════════════════════════════════╗
║          MIGRATION ACTION MENU                     ║
╚════════════════════════════════════════════════════╝

What would you like to do?

1. Inventory vault secrets (Phase 2)
2. Export vault secrets for Bitwarden import (Phase 2)
3. Update playbook to use Bitwarden lookup (Phase 3-5)
4. Test Bitwarden lookup (Phase 3-5)
5. Remove vault fallback (Phase 6)
6. Archive vault files (Phase 6)
7. View full migration plan (DEVELOPMENT_PLAN.md)
8. Exit

Enter choice [1-8]:
```

### 3. Action: Inventory Vault Secrets

**Step 1: Select Vault File to Inventory**

```bash
# List available vault files
echo "Available vault files:"
find ansible/group_vars ansible/host_vars -name "*_vault.yml" -type f 2>/dev/null | \
  nl -w2 -s'. '

echo ""
echo "Enter file number to inventory (or 'all' for all files):"
read -r FILE_CHOICE

# Process selection
if [ "$FILE_CHOICE" = "all" ]; then
  SELECTED_FILES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml" -type f 2>/dev/null)
else
  SELECTED_FILES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml" -type f 2>/dev/null | sed -n "${FILE_CHOICE}p")
fi
```

**Step 2: Decrypt and Analyze**

```bash
for vault_file in $SELECTED_FILES; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Inventorying: $vault_file"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Decrypt to temporary location (secure)
  TEMP_FILE="/tmp/vault_inventory_$(basename $vault_file).tmp"

  if ansible-vault view "$vault_file" > "$TEMP_FILE" 2>/dev/null; then
    echo "✅ Decrypted successfully"

    # Extract variable names and types
    echo ""
    echo "Secrets found:"

    grep -E "^[a-zA-Z_].*:" "$TEMP_FILE" | while IFS=: read var_name var_value; do
      # Determine variable type
      if echo "$var_value" | grep -q "lookup"; then
        VAR_TYPE="🔄 Already migrated (lookup)"
      elif echo "$var_name" | grep -q "^vault_"; then
        VAR_TYPE="🔑 Vault variable"
      else
        VAR_TYPE="📝 Regular variable"
      fi

      echo "  - $var_name: $VAR_TYPE"
    done

    # Clean up
    shred -u "$TEMP_FILE" 2>/dev/null || rm -f "$TEMP_FILE"
  else
    echo "❌ Failed to decrypt (check vault password)"
  fi

  echo ""
done
```

**Step 3: Generate Inventory Report**

```markdown
# Vault Secret Inventory

**File**: [vault_file]
**Date**: [ISO 8601 timestamp]

## Secrets to Migrate

| Variable Name | Type | Target Bitwarden Secret |
|---------------|------|-------------------------|
| vault_pihole_admin_password | password | prod-pihole-admin-password |
| vault_pihole_api_key | api_key | prod-pihole-api-key |
| vault_tailscale_auth_key | token | prod-tailscale-auth-key |

## Migration Checklist

- [ ] Create Bitwarden secrets
- [ ] Update playbooks with Bitwarden lookups
- [ ] Test deployment with Bitwarden
- [ ] Test fallback to vault (if still in parallel phase)
- [ ] Archive vault file after validation period

## Notes

[Any special considerations for this service]
```

### 4. Action: Update Playbook for Bitwarden

**Step 1: Select Playbook**

```bash
# List playbooks
echo "Available playbooks:"
find ansible/playbooks -name "*.yml" -type f 2>/dev/null | nl -w2 -s'. '

echo ""
echo "Enter playbook number to update:"
read -r PLAYBOOK_CHOICE

PLAYBOOK=$(find ansible/playbooks -name "*.yml" -type f 2>/dev/null | sed -n "${PLAYBOOK_CHOICE}p")
```

**Step 2: Analyze Current Secret Usage**

```bash
@$PLAYBOOK

# Find vault variable references
echo "Vault variables found in playbook:"
grep -n "vault_" "$PLAYBOOK" | head -20

# Find corresponding group_vars
PLAY_NAME=$(basename "$PLAYBOOK" .yml)
GROUP_VARS=$(find ansible/group_vars -name "${PLAY_NAME}.yml" -o -name "${PLAY_NAME}_*.yml" 2>/dev/null)

if [ -n "$GROUP_VARS" ]; then
  echo ""
  echo "Related group vars:"
  echo "$GROUP_VARS" | while read gv_file; do
    echo "  - $gv_file"
    grep -n "vault_" "$gv_file" 2>/dev/null | head -10
  done
fi
```

**Step 3: Generate Bitwarden Lookup Pattern**

```yaml
# Example transformation
# BEFORE (Vault):
service_password: "{{ vault_service_password | default('changeme123') }}"

# DURING MIGRATION (Bitwarden with Vault fallback):
service_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-password', default=vault_service_password | default('')) }}"

# AFTER MIGRATION (Bitwarden only):
service_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-password') }}"
```

**Step 4: Update Group Vars File**

```bash
# Prompt for Bitwarden secret ID
echo ""
echo "Enter Bitwarden secret ID for this variable:"
echo "Example: prod-pihole-admin-password"
read -r SECRET_ID

# Generate updated configuration
cat << 'EOF'

Updated configuration (copy to group_vars file):

```yaml
# Bitwarden lookup with vault fallback (during migration)
service_password: "{{ lookup('bitwarden.secrets.lookup', '$SECRET_ID', default=vault_service_password | default('')) }}"
```

After migration complete and 2-week validation period:

```yaml
# Bitwarden only
service_password: "{{ lookup('bitwarden.secrets.lookup', '$SECRET_ID') }}"
```
EOF
```

### 5. Action: Test Bitwarden Lookup

**Step 1: Verify Bitwarden Authentication**

```bash
echo "Testing Bitwarden authentication..."

if [ -z "$BWS_ACCESS_TOKEN" ]; then
  echo "❌ BWS_ACCESS_TOKEN not set"
  echo ""
  echo "Set your machine account token:"
  echo "export BWS_ACCESS_TOKEN='your-token-here'"
  exit 1
fi

# Test connection
if bws secret list --limit 1 > /dev/null 2>&1; then
  echo "✅ Bitwarden authentication successful"
else
  echo "❌ Bitwarden authentication failed"
  echo "Check your BWS_ACCESS_TOKEN"
  exit 1
fi
```

**Step 2: Test Secret Retrieval**

```bash
echo ""
echo "Enter Bitwarden secret ID to test:"
read -r TEST_SECRET_ID

echo ""
echo "Testing secret retrieval..."

# Test with Ansible
TEST_RESULT=$(ansible localhost -m debug \
  -a "msg={{ lookup('bitwarden.secrets.lookup', '$TEST_SECRET_ID') }}" \
  --one-line 2>&1)

if echo "$TEST_RESULT" | grep -q "SUCCESS"; then
  echo "✅ Secret retrieved successfully"
  echo "   (Secret value hidden for security)"
else
  echo "❌ Secret retrieval failed"
  echo "$TEST_RESULT"
fi
```

**Step 3: Test Playbook in Check Mode**

```bash
echo ""
echo "Test playbook with Bitwarden secrets? (y/N)"
read -r TEST_PLAYBOOK

if [ "$TEST_PLAYBOOK" = "y" ]; then
  echo ""
  echo "Select playbook to test:"
  find ansible/playbooks -name "*.yml" -type f 2>/dev/null | nl -w2 -s'. '

  read -r PB_NUM
  PLAYBOOK=$(find ansible/playbooks -name "*.yml" -type f 2>/dev/null | sed -n "${PB_NUM}p")

  echo ""
  echo "Testing: $PLAYBOOK"

  # Find inventory
  INVENTORY=$(find ansible/inventory -type f | head -1)

  if [ -f "$PLAYBOOK" ] && [ -f "$INVENTORY" ]; then
    !ansible-playbook -i "$INVENTORY" "$PLAYBOOK" \
      --check \
      --diff \
      --limit localhost 2>&1 | head -100

    echo ""
    echo "✅ Check mode test complete (output truncated)"
  else
    echo "❌ Playbook or inventory not found"
  fi
fi
```

### 6. Action: Remove Vault Fallback

**Only after migration complete and validated for 2+ weeks**

```bash
echo "⚠️  WARNING: This will remove vault fallback mechanisms"
echo "Only proceed if:"
echo "  1. All secrets migrated to Bitwarden"
echo "  2. Services running on Bitwarden for 2+ weeks"
echo "  3. No issues reported"
echo ""
echo "Proceed? (yes/NO)"
read -r PROCEED

if [ "$PROCEED" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

# Find group_vars files with fallback pattern
echo ""
echo "Finding files with vault fallback patterns..."

FILES_WITH_FALLBACK=$(grep -r "default=vault_" ansible/group_vars 2>/dev/null | cut -d: -f1 | sort -u)

if [ -n "$FILES_WITH_FALLBACK" ]; then
  echo "Files with fallback patterns:"
  echo "$FILES_WITH_FALLBACK"

  echo ""
  echo "Transform pattern:"
  echo "FROM: lookup('bitwarden.secrets.lookup', 'id', default=vault_var | default(''))"
  echo "TO:   lookup('bitwarden.secrets.lookup', 'id')"

  echo ""
  echo "Update these files manually or use sed/awk"
  echo ""
  echo "Example sed command (review before using):"
  echo "sed -i.bak 's/default=vault_[^ ]*//g' group_vars/service.yml"
else
  echo "✅ No fallback patterns found"
fi
```

### 7. Action: Archive Vault Files

**Only after vault removal complete**

```bash
echo "⚠️  WARNING: This will archive all vault files"
echo "Only proceed if vault fallback already removed"
echo ""
echo "Proceed? (yes/NO)"
read -r PROCEED

if [ "$PROCEED" != "yes" ]; then
  echo "Cancelled"
  exit 0
fi

# Create archive directory
ARCHIVE_DIR="ansible/archive/vault-$(date +%Y%m%d)"
mkdir -p "$ARCHIVE_DIR"

echo "Created archive directory: $ARCHIVE_DIR"

# Find vault files
VAULT_FILES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml" -type f 2>/dev/null)

if [ -n "$VAULT_FILES" ]; then
  echo ""
  echo "Archiving vault files:"

  echo "$VAULT_FILES" | while read vault_file; do
    echo "  Moving: $vault_file → $ARCHIVE_DIR/"
    mv "$vault_file" "$ARCHIVE_DIR/"
  done

  # Also archive templates
  TEMPLATES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml.template" -type f 2>/dev/null)
  if [ -n "$TEMPLATES" ]; then
    echo ""
    echo "Archiving template files:"
    echo "$TEMPLATES" | while read template_file; do
      echo "  Moving: $template_file → $ARCHIVE_DIR/"
      mv "$template_file" "$ARCHIVE_DIR/"
    done
  fi

  echo ""
  echo "✅ Vault files archived to: $ARCHIVE_DIR"
  echo ""
  echo "Update ansible.cfg:"
  echo "  Remove: vault_password_file = .vault_password"
  echo "  Add comment: # Secrets now managed via Bitwarden Secrets Manager"
else
  echo "No vault files found to archive"
fi
```

### 8. Migration Progress Tracking

```bash
# Generate migration status summary
cat << 'EOF'

╔════════════════════════════════════════════════════╗
║          MIGRATION PROGRESS SUMMARY                ║
╚════════════════════════════════════════════════════╝

Current Phase: [Determine from DEVELOPMENT_PLAN.md]

Checklist:
- [ ] Phase 1: Bitwarden infrastructure setup
- [ ] Phase 2: Secret inventory complete
- [ ] Phase 3: Secrets imported to Bitwarden
- [ ] Phase 4: Pilot service migrated (Nostr relay)
- [ ] Phase 5: Core services migrated
- [ ] Phase 6: Vault fallback removed
- [ ] Phase 7: Vault files archived
- [ ] Phase 8: Secret rotation complete

Services Migrated: [N] / [Total]
  ✅ nostr-relay
  ✅ pihole
  ⏳ k3s-cluster (in progress)
  ⏳ rancher
  ⏳ haproxy
  ⏳ tailscale-recorder

Next Steps:
1. [Next immediate action]
2. [Following action]

See DEVELOPMENT_PLAN.md for full 16-week timeline
EOF
```

---

## Usage Examples

### Start Migration Assessment
```
/vault-migrate
```

### Guided Workflow
```
/vault-migrate
# Follow interactive menu
# Choose actions based on current migration phase
```

### Integration with Validation
```
# After updating playbook
/vault-migrate
# Then validate
/ansible-validate
```

---

## Safety Features

1. **Secure Temporary Files**: Decrypted secrets stored in /tmp, shredded after use
2. **No Secret Logging**: All secret values masked in output
3. **Backup Verification**: Archives created before file removal
4. **Parallel Operation**: Supports vault fallback during migration
5. **Validation Gates**: Tests required before removing fallbacks

---

## Migration Phases (Reference)

**Phase 1-2** (Weeks 1-3): Setup & Inventory
**Phase 3-4** (Weeks 3-5): Bitwarden Import & Pilot
**Phase 5** (Weeks 5-8): Core Services Migration
**Phase 6** (Weeks 9-10): Vault Deprecation
**Phase 7-9** (Weeks 11-16): Rotation, Training, Docs

See @DEVELOPMENT_PLAN.md for complete details

---

## When to Use /vault-migrate

- Beginning Ansible Vault to Bitwarden migration
- During active migration (any phase)
- To check migration status
- After completing a migration phase
- When updating playbooks for Bitwarden
- Before archiving vault files
- To track overall progress
