---
description: "Validate Ansible playbooks and roles with syntax checking, linting, YAML validation, and security best practices"
allowed-tools: ["Read", "Search", "Bash(ansible-playbook:*)", "Bash(ansible-lint:*)", "Bash(yamllint:*)", "Bash(ansible-inventory:*)", "Bash(ansible:*)", "Bash(find)", "Bash(tree)"]
author: "Home Lab Infrastructure Team"
version: "1.0"
---

# Ansible Validate

## Purpose
Comprehensive validation of Ansible playbooks, roles, and configuration ensuring syntax correctness, linting standards, YAML compliance, and best practices adherence.

## Validation Workflow

### 1. Discover Ansible Structure

```bash
# Show Ansible directory structure
!tree -L 3 ansible/ -I "*.retry"

# Find all playbooks
!find ansible/playbooks -type f -name "*.yml" 2>/dev/null | head -20

# Find all roles
!find ansible/roles -type d -mindepth 1 -maxdepth 1 2>/dev/null

# Count Ansible files
echo "Playbooks: $(find ansible/playbooks -name '*.yml' 2>/dev/null | wc -l)"
echo "Roles: $(find ansible/roles -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"
echo "Group vars: $(find ansible/group_vars -name '*.yml' 2>/dev/null | wc -l)"
echo "Inventory files: $(find ansible/inventory -type f 2>/dev/null | wc -l)"
```

### 2. Syntax Validation

Check syntax of all playbooks:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ansible Syntax Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PLAYBOOK_DIR="ansible/playbooks"
SYNTAX_ERRORS=0

if [ -d "$PLAYBOOK_DIR" ]; then
  for playbook in $(find "$PLAYBOOK_DIR" -name "*.yml" -o -name "*.yaml"); do
    echo ""
    echo "Checking: $playbook"

    if ansible-playbook "$playbook" --syntax-check 2>&1; then
      echo "✅ Syntax OK"
    else
      echo "❌ Syntax ERROR"
      ((SYNTAX_ERRORS++))
    fi
  done
else
  echo "⚠️ No playbooks directory found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Syntax check complete"
echo "Total playbooks: $(find "$PLAYBOOK_DIR" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)"
echo "Errors: $SYNTAX_ERRORS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          ANSIBLE SYNTAX VALIDATION                 ║
╚════════════════════════════════════════════════════╝

Playbooks checked: [N]
✅ Passed: [N]
❌ Failed: [N]

Status: ✅ ALL VALID / ❌ ERRORS FOUND

[If failures, list playbooks with issues]
```

### 3. YAML Linting

Validate YAML syntax and formatting:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "YAML Linting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v yamllint >/dev/null 2>&1; then
  echo "yamllint version: $(yamllint --version)"

  # Run yamllint on all Ansible YAML files
  !yamllint ansible/ -f parsable

  # Count issues
  YAML_ISSUES=$(yamllint ansible/ -f parsable 2>&1 | wc -l)
  echo ""
  echo "YAML issues found: $YAML_ISSUES"

  # Show summary by severity
  yamllint ansible/ -f parsable 2>&1 | \
    awk -F':' '{print $4}' | \
    sort | uniq -c | sort -rn
else
  echo "⚠️ yamllint not installed. Skipping YAML validation."
  echo "Install: pip install yamllint"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          YAML LINTING (yamllint)                   ║
╚════════════════════════════════════════════════════╝

Status: ✅ NO ISSUES / ⚠️ WARNINGS / ❌ ERRORS

Files checked: [N]
Issues found:
├── Errors: [N]
└── Warnings: [N]

[List significant issues]
```

### 4. Ansible Linting

Run ansible-lint to check for best practices:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ansible Linting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v ansible-lint >/dev/null 2>&1; then
  echo "ansible-lint version: $(ansible-lint --version)"

  # Run ansible-lint on playbooks
  !ansible-lint ansible/playbooks/ \
    --force-color \
    --parseable

  # Run ansible-lint on roles
  if [ -d "ansible/roles" ]; then
    echo ""
    echo "Linting roles..."
    !ansible-lint ansible/roles/ \
      --force-color \
      --parseable
  fi

  # Generate statistics
  LINT_OUTPUT=$(ansible-lint ansible/ -p 2>&1)
  ERRORS=$(echo "$LINT_OUTPUT" | grep -c "\[E[0-9]" || echo "0")
  WARNINGS=$(echo "$LINT_OUTPUT" | grep -c "\[W[0-9]" || echo "0")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Linting Summary:"
  echo "  Errors: $ERRORS"
  echo "  Warnings: $WARNINGS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
  echo "⚠️ ansible-lint not installed. Skipping Ansible linting."
  echo "Install: pip install ansible-lint"
fi
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          ANSIBLE LINTING                           ║
╚════════════════════════════════════════════════════╝

Status: ✅ NO ISSUES / ⚠️ WARNINGS / ❌ ERRORS

Issues found:
├── [E***] Errors: [N]
├── [W***] Warnings: [N]
└── [INFO] Suggestions: [N]

Common Issues:
❌ [E208] FQCN not used: [N] occurrences
⚠️ [W503] Deprecated command usage: [N] occurrences

[List top issues with file locations]
```

### 5. Inventory Validation

Verify inventory structure and variables:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Inventory Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -d "ansible/inventory" ]; then
  # List all inventory files
  echo "Inventory files:"
  find ansible/inventory -type f | while read inv_file; do
    echo "  - $inv_file"
  done

  # Validate inventory by listing all hosts
  for inv_file in $(find ansible/inventory -type f); do
    echo ""
    echo "Validating: $inv_file"

    if ansible-inventory -i "$inv_file" --list > /dev/null 2>&1; then
      echo "✅ Inventory valid"

      # Show host count
      HOST_COUNT=$(ansible-inventory -i "$inv_file" --list | jq '.["_meta"]["hostvars"] | length')
      echo "   Hosts defined: $HOST_COUNT"

      # Show groups
      GROUP_COUNT=$(ansible-inventory -i "$inv_file" --list | jq '. | keys | length - 2')
      echo "   Groups defined: $GROUP_COUNT"
    else
      echo "❌ Inventory INVALID"
    fi
  done
else
  echo "⚠️ No inventory directory found"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 6. Check for Secrets and Vault Files

Verify vault file conventions and security:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Vault and Secrets Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find vault files
VAULT_FILES=$(find ansible/group_vars ansible/host_vars -name "*_vault.yml" 2>/dev/null)

if [ -n "$VAULT_FILES" ]; then
  echo "Vault files found:"
  echo "$VAULT_FILES" | while read vault_file; do
    echo "  - $vault_file"

    # Check if file is encrypted
    if head -1 "$vault_file" | grep -q "\$ANSIBLE_VAULT"; then
      echo "    ✅ Encrypted"
    else
      echo "    ❌ NOT ENCRYPTED (SECURITY RISK!)"
    fi

    # Check for corresponding template
    TEMPLATE_FILE="${vault_file}.template"
    if [ -f "$TEMPLATE_FILE" ]; then
      echo "    ✅ Template exists: $TEMPLATE_FILE"
    else
      echo "    ⚠️ No template found (should create $TEMPLATE_FILE)"
    fi
  done
else
  echo "No vault files found (migration to Bitwarden may be complete)"
fi

# Check for plaintext secrets (security scan)
echo ""
echo "Checking for potential plaintext secrets..."
if command -v grep >/dev/null 2>&1; then
  # Simple pattern matching (not comprehensive)
  SUSPICIOUS=$(grep -r -i -E "(password|secret|api_key|token):\s*['\"]?[a-zA-Z0-9]" \
    ansible/group_vars ansible/host_vars 2>/dev/null | \
    grep -v "_vault.yml" | \
    grep -v ".template" | \
    grep -v "changeme" | \
    grep -v "lookup" | \
    wc -l)

  if [ "$SUSPICIOUS" -gt 0 ]; then
    echo "⚠️ Found $SUSPICIOUS lines with potential plaintext secrets"
    echo "   Review these files manually for security"
  else
    echo "✅ No obvious plaintext secrets detected"
  fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 7. Check Bitwarden Integration

Verify Bitwarden Secrets Manager setup and usage:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Bitwarden Integration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Bitwarden collection is installed
if ansible-galaxy collection list 2>/dev/null | grep -q "bitwarden.secrets"; then
  echo "✅ Bitwarden Secrets collection installed"

  # Get version
  BW_VERSION=$(ansible-galaxy collection list | grep "bitwarden.secrets" | awk '{print $2}')
  echo "   Version: $BW_VERSION"
else
  echo "❌ Bitwarden Secrets collection NOT installed"
  echo "   Install: ansible-galaxy collection install bitwarden.secrets"
fi

# Check for Bitwarden lookups in playbooks
BWS_USAGE=$(grep -r "lookup('bitwarden.secrets.lookup'" ansible/ 2>/dev/null | wc -l)
if [ "$BWS_USAGE" -gt 0 ]; then
  echo "✅ Bitwarden lookups found: $BWS_USAGE occurrences"
else
  echo "⚠️ No Bitwarden lookups found (migration may not have started)"
fi

# Check for BWS_ACCESS_TOKEN environment variable
if [ -n "$BWS_ACCESS_TOKEN" ]; then
  echo "✅ BWS_ACCESS_TOKEN environment variable is set"
else
  echo "⚠️ BWS_ACCESS_TOKEN not set (required for Bitwarden authentication)"
  echo "   Set: export BWS_ACCESS_TOKEN='your-token'"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 8. Dry Run Validation (Optional)

Test playbook execution in check mode:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Dry Run Validation (Check Mode)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Prompt user if they want to run dry-run
echo "Would you like to run playbooks in check mode? (y/N)"
read -r RUN_CHECK

if [ "$RUN_CHECK" = "y" ] || [ "$RUN_CHECK" = "Y" ]; then
  # Find a test playbook or use site.yml
  TEST_PLAYBOOK="ansible/playbooks/site.yml"

  if [ -f "$TEST_PLAYBOOK" ]; then
    # Find an inventory file
    INVENTORY=$(find ansible/inventory -type f -name "*.ini" -o -name "*.yml" | head -1)

    if [ -f "$INVENTORY" ]; then
      echo "Running check mode on: $TEST_PLAYBOOK"
      echo "Using inventory: $INVENTORY"

      !ansible-playbook -i "$INVENTORY" "$TEST_PLAYBOOK" \
        --check \
        --diff \
        --limit "localhost" 2>&1 | head -50

      echo ""
      echo "✅ Check mode completed (output truncated)"
    else
      echo "⚠️ No inventory file found, skipping dry run"
    fi
  else
    echo "⚠️ No site.yml or test playbook found"
  fi
else
  echo "Skipping dry run validation"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 9. Generate Comprehensive Validation Report

Create **ANSIBLE_VALIDATION_REPORT.md**:

```markdown
# Ansible Validation Report

**Report Generated**: [ISO 8601 timestamp]
**Project**: HomeLab Infrastructure
**Ansible Version**: [version]
**Branch**: [current branch]
**Commit**: [git hash]

---

## 📊 Validation Summary

| Check | Status | Issues | Result |
|-------|--------|--------|--------|
| Syntax | ✅ / ❌ | [N] errors | ✅ / ❌ |
| YAML Lint | ✅ / ⚠️ / ❌ | [N] issues | ✅ / ⚠️ / ❌ |
| Ansible Lint | ✅ / ⚠️ / ❌ | [N] issues | ✅ / ⚠️ / ❌ |
| Inventory | ✅ / ❌ | [N] errors | ✅ / ❌ |
| Vault Security | ✅ / ⚠️ / ❌ | [N] issues | ✅ / ⚠️ / ❌ |
| Bitwarden | ✅ / ⚠️ / ❌ | - | ✅ / ⚠️ / ❌ |
| **Overall** | **✅ / ❌** | **[N] total** | **PASS / FAIL** |

---

## ✅ Quality Gates

### Must-Pass (Blocking)
- [x] ✅ All playbooks have valid syntax
- [x] ✅ YAML files properly formatted
- [ ] ❌ No critical ansible-lint errors ([N] found)
- [x] ✅ No plaintext secrets in vars
- [x] ✅ Vault files encrypted

### Should-Pass (Warnings Acceptable)
- [ ] ⚠️ Ansible-lint warnings ([N] warnings)
- [ ] ⚠️ YAML formatting ([N] minor issues)
- [x] ✅ Inventory structure valid

### Migration Tracking
- [ ] ⏳ Bitwarden collection installed
- [ ] ⏳ Bitwarden lookups implemented ([N]% complete)
- [ ] ⏳ Vault files archived

**Gate Status**: ❌ BLOCKED / ⚠️ WARNINGS / ✅ READY FOR REVIEW

---

## 📝 Detailed Results

### Syntax Validation
```
Playbooks checked: [N]
✅ Passed: [N]
❌ Failed: [N]

[List any failed playbooks]
```

### Ansible Lint Issues
```
Total issues: [N]

Top Issues by Type:
1. [E208] FQCN not used - [N] occurrences
2. [W503] Deprecated command - [N] occurrences
3. [INFO] Missing tags - [N] occurrences

[Details of critical issues]
```

### Security Findings
```
Vault files: [N] found
✅ Encrypted: [N]
❌ Unencrypted: [N] (CRITICAL!)

Plaintext secrets: [N] potential matches
⚠️ Requires manual review
```

---

## 🎯 Action Items

### Critical (Fix Before Merge)
1. [Critical issue 1 with file:line]
2. [Critical issue 2 with file:line]

### High Priority
1. [High priority issue 1]
2. [High priority issue 2]

### Migration Tasks
1. Install Bitwarden collection if missing
2. Migrate [N] playbooks to Bitwarden lookups
3. Archive vault files after migration complete

---

## 📋 Quick Fix Commands

```bash
# Fix FQCN issues
sed -i 's/apt:/ansible.builtin.apt:/g' playbooks/*.yml

# Run ansible-lint with auto-fix
ansible-lint --fix ansible/playbooks/

# Validate after fixes
/ansible-validate
```

---

**Next Steps**:
1. Fix all critical and high-priority issues
2. Run `/ansible-validate` again to verify
3. Test playbooks with `/ansible-validate` dry-run mode
4. Commit changes and create PR

**Validation Report**: ansible-validation-report.md
```

### 10. Display Summary to User

```
╔════════════════════════════════════════════════════╗
║       ANSIBLE VALIDATION COMPLETE                  ║
╚════════════════════════════════════════════════════╝

PROJECT: HomeLab Infrastructure
ANSIBLE VERSION: [version]

VALIDATION RESULTS:
  Syntax:    ✅ / ❌  ([N] playbooks checked)
  YAML Lint: ✅ / ⚠️ / ❌  ([N] issues)
  Ansible Lint: ✅ / ⚠️ / ❌  ([N] issues)
  Inventory: ✅ / ❌  ([N] files)
  Vault Security: ✅ / ⚠️ / ❌
  Bitwarden: ✅ / ⚠️ / ❌  ([N]% migrated)

QUALITY GATES:
  Must-Pass: ✅ / ❌
  Should-Pass: ✅ / ⚠️

STATUS: ✅ READY FOR PR / ⚠️ WARNINGS / ❌ BLOCKED

REPORTS GENERATED:
  - ANSIBLE_VALIDATION_REPORT.md

NEXT STEPS:
  [List recommended actions based on results]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Bitwarden Migration: [N]% complete
Run '/vault-migrate' for migration assistance
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Usage Examples

### Basic Validation
```
/ansible-validate
```
Runs all validation checks on Ansible code

### Integration with Other Commands
```
# Validate before deployment
/ansible-validate && /infra-deploy

# Part of PR workflow
/ansible-validate && /tf-validate && /pr
```

---

## Tool Requirements

**Required**:
- ansible-core >= 2.19.3
- ansible >= 12.1.0

**Recommended**:
- ansible-lint (best practices checking)
- yamllint (YAML validation)
- bitwarden.secrets collection (secret management)

**Installation**:
```bash
# Python packages
pip install ansible==12.1.0 ansible-core==2.19.3
pip install ansible-lint yamllint

# Bitwarden collection
ansible-galaxy collection install bitwarden.secrets
```

---

## When to Use /ansible-validate

- Before committing Ansible changes
- Before creating a pull request
- After writing new playbooks
- After modifying existing playbooks or roles
- During Bitwarden migration
- As part of CI/CD pipeline
- Before deploying to production
- During code review

---

## Exit Codes

- **0**: All validations passed
- **1**: Syntax check failed
- **2**: Linting errors found
- **3**: Security issues detected
- **4**: YAML validation failed
