---
description: "Validate Terraform infrastructure code with comprehensive format, syntax, linting, and security checks"
allowed-tools: ["Read", "Search", "Bash(terraform:fmt)", "Bash(terraform:init)", "Bash(terraform:validate)", "Bash(tflint)", "Bash(tfsec)", "Bash(terraform-docs)", "Bash(find)", "Bash(tree)"]
author: "Home Lab Infrastructure Team"
version: "1.0"
---

# Terraform Validate

## Purpose
Comprehensive validation of Terraform infrastructure code ensuring format compliance, syntax correctness, linting standards, and security best practices.

## Validation Workflow

### 1. Discover Terraform Structure

```bash
# Show Terraform directory structure
!tree -L 3 terraform/ -I ".terraform"

# Find all Terraform files
!find terraform/ -type f -name "*.tf" | head -20

# Count Terraform files by type
echo "Main files: $(find terraform/ -name 'main.tf' | wc -l)"
echo "Variables: $(find terraform/ -name 'variables.tf' | wc -l)"
echo "Outputs: $(find terraform/ -name 'outputs.tf' | wc -l)"
```

### 2. Format Validation

Check if all Terraform files are properly formatted:

```bash
# Check format (non-destructive, returns exit code 0 if formatted)
!terraform fmt -check -recursive terraform/

# Show files needing formatting (if any)
!terraform fmt -check -recursive -diff terraform/ 2>&1 | grep "^terraform/"

# Count unformatted files
UNFORMATTED=$(terraform fmt -check -recursive terraform/ 2>&1 | grep -c "^terraform/" || echo "0")
echo "Files needing formatting: $UNFORMATTED"
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          TERRAFORM FORMAT CHECK                    ║
╚════════════════════════════════════════════════════╝

Status: ✅ ALL FORMATTED / ❌ [N] FILES NEED FORMATTING

Files checked: [N]
Unformatted: [N]

[If issues found, list files]
```

### 3. Syntax Validation

Validate Terraform syntax for all modules:

```bash
# Find all directories with Terraform files
TERRAFORM_DIRS=$(find terraform/ -type f -name "*.tf" | xargs -I {} dirname {} | sort -u)

# Initialize and validate each directory
for dir in $TERRAFORM_DIRS; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Validating: $dir"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  cd "$dir" || continue

  # Initialize without backend (for validation only)
  terraform init -backend=false -upgrade=false > /dev/null 2>&1

  # Validate
  if terraform validate; then
    echo "✅ $dir validation PASSED"
  else
    echo "❌ $dir validation FAILED"
  fi

  cd - > /dev/null
done
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          TERRAFORM SYNTAX VALIDATION               ║
╚════════════════════════════════════════════════════╝

Modules validated: [N]
✅ Passed: [N]
❌ Failed: [N]

Status: ✅ ALL VALID / ❌ ERRORS FOUND

[If failures, list modules with issues]
```

### 4. Linting with TFLint

Run TFLint to check for common issues and best practices:

```bash
# Check if TFLint is installed
if command -v tflint >/dev/null 2>&1; then
  echo "TFLint version: $(tflint --version)"

  # Run TFLint recursively
  !tflint --recursive --config=.tflint.hcl terraform/

  # Alternative: Lint each module separately for detailed output
  for dir in $(find terraform/modules -type d -mindepth 1 -maxdepth 1); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Linting: $dir"
    cd "$dir" && tflint --config=../../.tflint.hcl && cd -
  done
else
  echo "⚠️ TFLint not installed. Skipping linting."
  echo "Install: https://github.com/terraform-linters/tflint"
fi
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          TERRAFORM LINTING (TFLint)                ║
╚════════════════════════════════════════════════════╝

Status: ✅ NO ISSUES / ⚠️ WARNINGS FOUND / ❌ ERRORS FOUND

Issues found:
├── Errors: [N]
├── Warnings: [N]
└── Info: [N]

[List significant issues]
```

### 5. Security Scanning with TFSec

Run security analysis to identify misconfigurations:

```bash
# Check if TFSec is installed
if command -v tfsec >/dev/null 2>&1; then
  echo "TFSec version: $(tfsec --version)"

  # Run security scan
  !tfsec terraform/ \
    --exclude-downloaded-modules \
    --format=default \
    --minimum-severity=MEDIUM

  # Generate detailed report
  !tfsec terraform/ \
    --exclude-downloaded-modules \
    --format=json \
    --out=tfsec-report.json 2>/dev/null

  # Count issues by severity
  if [ -f tfsec-report.json ]; then
    CRITICAL=$(jq '[.results[] | select(.severity=="CRITICAL")] | length' tfsec-report.json)
    HIGH=$(jq '[.results[] | select(.severity=="HIGH")] | length' tfsec-report.json)
    MEDIUM=$(jq '[.results[] | select(.severity=="MEDIUM")] | length' tfsec-report.json)
    LOW=$(jq '[.results[] | select(.severity=="LOW")] | length' tfsec-report.json)

    echo "Critical: $CRITICAL"
    echo "High: $HIGH"
    echo "Medium: $MEDIUM"
    echo "Low: $LOW"
  fi
else
  echo "⚠️ TFSec not installed. Skipping security scan."
  echo "Install: https://aquasecurity.github.io/tfsec/"
fi
```

**Result Summary**:
```
╔════════════════════════════════════════════════════╗
║          SECURITY SCAN (TFSec)                     ║
╚════════════════════════════════════════════════════╝

Status: ✅ NO ISSUES / ⚠️ WARNINGS / ❌ CRITICAL ISSUES

Security Issues:
├── 🔴 Critical: [N]
├── 🟠 High: [N]
├── 🟡 Medium: [N]
└── 🟢 Low: [N]

[List critical and high severity issues]
```

### 6. Generate Terraform Documentation

Auto-generate module documentation:

```bash
# Check if terraform-docs is installed
if command -v terraform-docs >/dev/null 2>&1; then
  echo "terraform-docs version: $(terraform-docs --version)"

  # Generate documentation for each module
  for module in $(find terraform/modules -type d -mindepth 1 -maxdepth 1); do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Generating docs for: $module"

    # Check if README.md exists
    if [ -f "$module/README.md" ]; then
      # Update existing README
      terraform-docs markdown table "$module" > "$module/README.md"
      echo "✅ Documentation updated: $module/README.md"
    else
      # Create new README
      terraform-docs markdown table "$module" > "$module/README.md"
      echo "✅ Documentation created: $module/README.md"
    fi
  done
else
  echo "⚠️ terraform-docs not installed. Skipping documentation generation."
  echo "Install: https://terraform-docs.io/"
fi
```

### 7. Generate Comprehensive Validation Report

Create **TERRAFORM_VALIDATION_REPORT.md**:

```markdown
# Terraform Validation Report

**Report Generated**: [ISO 8601 timestamp]
**Project**: HomeLab Infrastructure
**Terraform Version**: [version]
**Branch**: [current branch]
**Commit**: [git hash]

---

## 📊 Validation Summary

| Check | Status | Issues | Result |
|-------|--------|--------|--------|
| Format | ✅ / ❌ | [N] unformatted | ✅ / ❌ |
| Syntax | ✅ / ❌ | [N] errors | ✅ / ❌ |
| Linting | ✅ / ⚠️ / ❌ | [N] warnings | ✅ / ⚠️ / ❌ |
| Security | ✅ / ⚠️ / ❌ | [N] issues | ✅ / ⚠️ / ❌ |
| **Overall** | **✅ / ❌** | **[N] total** | **PASS / FAIL** |

---

## ✅ Quality Gates

### Must-Pass (Blocking)
- [x] ✅ All Terraform files formatted
- [x] ✅ Syntax validation passed for all modules
- [ ] ❌ No critical security issues ([N] found)
- [x] ✅ Core modules validated

### Should-Pass (Warnings Acceptable)
- [ ] ⚠️ TFLint checks ([N] warnings)
- [x] ✅ Best practices followed
- [ ] ⚠️ Documentation up to date

**Gate Status**: ❌ BLOCKED / ⚠️ WARNINGS / ✅ READY FOR REVIEW

---

## 📝 Detailed Results

[Include details from each validation step]

---

## 🎯 Action Items

### Critical (Fix Before Merge)
1. [Critical issue 1]
2. [Critical issue 2]

### High Priority
1. [High priority issue 1]
2. [High priority issue 2]

### Recommendations
1. [Recommendation 1]
2. [Recommendation 2]

---

## 📋 Quick Fix Commands

```bash
# Format all files
terraform fmt -recursive terraform/

# Fix specific module
cd terraform/modules/[module-name]
terraform init -backend=false
terraform validate

# Re-run security scan
tfsec terraform/ --exclude-downloaded-modules
```

---

**Next Steps**:
1. Fix all critical and high-priority issues
2. Run `/tf-validate` again to verify fixes
3. Commit changes and create PR
4. Automated validation will run in CI/CD

**Validation Report**: terraform-validation-report.md
**Security Report**: tfsec-report.json
```

### 8. Display Summary to User

```
╔════════════════════════════════════════════════════╗
║       TERRAFORM VALIDATION COMPLETE                ║
╚════════════════════════════════════════════════════╝

PROJECT: HomeLab Infrastructure
TERRAFORM VERSION: [version]

VALIDATION RESULTS:
  Format:    ✅ / ❌  ([N] files checked)
  Syntax:    ✅ / ❌  ([N] modules validated)
  Linting:   ✅ / ⚠️ / ❌  ([N] issues)
  Security:  ✅ / ⚠️ / ❌  ([N] issues)

QUALITY GATES:
  Must-Pass: ✅ / ❌
  Should-Pass: ✅ / ⚠️

STATUS: ✅ READY FOR PR / ⚠️ WARNINGS / ❌ BLOCKED

REPORTS GENERATED:
  - TERRAFORM_VALIDATION_REPORT.md
  - tfsec-report.json

NEXT STEPS:
  [List recommended actions based on results]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run 'terraform fmt -recursive' to auto-fix formatting
Run 'tfsec terraform/' for detailed security analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Usage Examples

### Basic Validation
```
/tf-validate
```
Runs all validation checks on Terraform code

### Integration with Other Commands
```
# Validate before deployment
/tf-validate && /infra-deploy

# Part of PR workflow
/tf-validate && /test-all && /pr
```

---

## Tool Requirements

**Required**:
- terraform >= 1.13.3

**Recommended**:
- tflint (linting)
- tfsec (security scanning)
- terraform-docs (documentation generation)

**Installation**:
```bash
# macOS
brew install terraform tflint tfsec terraform-docs

# Linux
wget https://releases.hashicorp.com/terraform/1.13.3/terraform_1.13.3_linux_amd64.zip
# Follow installation instructions for tflint, tfsec, terraform-docs
```

---

## When to Use /tf-validate

- Before committing Terraform changes
- Before creating a pull request
- After making infrastructure changes
- As part of CI/CD pipeline
- Before running terraform plan/apply
- After updating Terraform modules
- During code review

---

## Exit Codes

- **0**: All validations passed
- **1**: Format check failed
- **2**: Syntax validation failed
- **3**: Security issues found
- **4**: Linting errors
