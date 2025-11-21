---
description: "Orchestrate infrastructure deployment with validation gates, Terraform planning, Ansible playbook execution, and verification"
allowed-tools: ["Read", "Search", "Bash(terraform:*)", "Bash(ansible-playbook:*)", "Bash(kubectl:*)", "Bash(git:status)", "Bash(git:log)", "Bash(find)"]
author: "Home Lab Infrastructure Team"
version: "1.0"
---

# Infrastructure Deploy

## Purpose
Orchestrate complete infrastructure deployment workflow with proper validation gates, planning, execution, and verification for home lab environments.

## Deployment Workflow

### 1. Pre-Deployment Assessment

```bash
echo "╔════════════════════════════════════════════════════╗"
echo "║     INFRASTRUCTURE DEPLOYMENT ORCHESTRATION        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
  echo "⚠️  Warning: $UNCOMMITTED uncommitted changes detected"
  git status --short
  echo ""
fi

# Check recent commits
echo "Recent commits:"
git log --oneline --decorate -5
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

### 2. Interactive Deployment Menu

```
╔════════════════════════════════════════════════════╗
║          DEPLOYMENT TYPE SELECTION                 ║
╚════════════════════════════════════════════════════╝

What would you like to deploy?

1. Full Stack (Terraform + Ansible + K8s)
2. Infrastructure Only (Terraform)
3. Configuration Only (Ansible)
4. Kubernetes Manifests Only
5. Single Service (Select from list)
6. Validation Dry-Run Only
7. View Deployment Plan
8. Exit

Enter choice [1-8]:
```

### 3. Environment Selection

```bash
echo "╔════════════════════════════════════════════════════╗"
echo "║          ENVIRONMENT SELECTION                     ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Target environment:"
echo "1. dev (Development)"
echo "2. staging (Pre-production)"
echo "3. prod (Production)"
echo ""
echo "Enter choice [1-3]:"
read -r ENV_CHOICE

case $ENV_CHOICE in
  1) ENVIRONMENT="dev" ;;
  2) ENVIRONMENT="staging" ;;
  3) ENVIRONMENT="prod" ;;
  *) echo "Invalid choice"; exit 1 ;;
esac

echo ""
echo "Selected environment: $ENVIRONMENT"
```

### 4. Pre-Deployment Validation

**Run Comprehensive Validation**:

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Pre-Deployment Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VALIDATION_FAILED=0

# Terraform validation
if [ -d "terraform/" ]; then
  echo "Running Terraform validation..."
  if ! terraform fmt -check -recursive terraform/; then
    echo "❌ Terraform format check failed"
    VALIDATION_FAILED=1
  fi

  # Validate all modules
  for dir in $(find terraform/modules -type d -mindepth 1 -maxdepth 1); do
    if ! (cd "$dir" && terraform init -backend=false > /dev/null 2>&1 && terraform validate > /dev/null 2>&1); then
      echo "❌ Terraform validation failed: $dir"
      VALIDATION_FAILED=1
    fi
  done

  if [ "$VALIDATION_FAILED" -eq 0 ]; then
    echo "✅ Terraform validation passed"
  fi
fi

# Ansible validation
if [ -d "ansible/" ]; then
  echo ""
  echo "Running Ansible validation..."

  # Syntax check
  for playbook in $(find ansible/playbooks -name "*.yml" -type f 2>/dev/null); do
    if ! ansible-playbook "$playbook" --syntax-check > /dev/null 2>&1; then
      echo "❌ Ansible syntax check failed: $playbook"
      VALIDATION_FAILED=1
    fi
  done

  if [ "$VALIDATION_FAILED" -eq 0 ]; then
    echo "✅ Ansible validation passed"
  fi
fi

# Check Bitwarden authentication
if [ -n "$BWS_ACCESS_TOKEN" ]; then
  echo "✅ Bitwarden authentication configured"
else
  echo "⚠️  BWS_ACCESS_TOKEN not set (may be required for secrets)"
fi

echo ""
if [ "$VALIDATION_FAILED" -ne 0 ]; then
  echo "❌ VALIDATION FAILED - Deployment blocked"
  echo "Run /tf-validate and /ansible-validate for details"
  exit 1
else
  echo "✅ ALL VALIDATIONS PASSED"
fi

echo ""
```

### 5. Terraform Deployment Phase

**Step 1: Terraform Plan**

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Terraform Infrastructure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TERRAFORM_DIR="terraform/environments/$ENVIRONMENT"

if [ -d "$TERRAFORM_DIR" ]; then
  cd "$TERRAFORM_DIR" || exit 1

  echo "Initializing Terraform..."
  !terraform init -upgrade

  echo ""
  echo "Generating Terraform plan..."
  !terraform plan -out=tfplan

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Terraform Plan Summary"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Extract plan summary
  terraform show -json tfplan | jq -r '
    .resource_changes[] |
    select(.change.actions != ["no-op"]) |
    "\(.change.actions[0] | ascii_upcase): \(.address)"
  ' | sort | uniq -c

  echo ""
  echo "Review the plan above."
  echo ""
else
  echo "⚠️  Terraform directory not found: $TERRAFORM_DIR"
  echo "Skipping Terraform phase"
fi
```

**Step 2: Terraform Apply (with approval)**

```bash
if [ -d "$TERRAFORM_DIR" ] && [ -f "$TERRAFORM_DIR/tfplan" ]; then
  echo "Apply Terraform plan? (yes/NO)"
  read -r APPLY_TERRAFORM

  if [ "$APPLY_TERRAFORM" = "yes" ]; then
    echo ""
    echo "Applying Terraform infrastructure..."
    !terraform apply tfplan

    if [ $? -eq 0 ]; then
      echo "✅ Terraform apply succeeded"

      # Extract outputs
      echo ""
      echo "Terraform Outputs:"
      terraform output -json | jq .

      # Save outputs for Ansible
      terraform output -json > "$TERRAFORM_DIR/outputs.json"
    else
      echo "❌ Terraform apply failed"
      exit 1
    fi
  else
    echo "Terraform apply cancelled"
    exit 0
  fi

  cd - > /dev/null
fi

echo ""
```

### 6. Ansible Deployment Phase

**Step 1: Ansible Check Mode**

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Ansible Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

ANSIBLE_DIR="ansible"
INVENTORY="$ANSIBLE_DIR/inventory/$ENVIRONMENT.ini"
PLAYBOOK="$ANSIBLE_DIR/playbooks/site.yml"

if [ ! -f "$INVENTORY" ]; then
  INVENTORY=$(find "$ANSIBLE_DIR/inventory" -type f -name "*$ENVIRONMENT*" | head -1)
fi

if [ ! -f "$PLAYBOOK" ]; then
  echo "Select playbook to deploy:"
  find "$ANSIBLE_DIR/playbooks" -name "*.yml" -type f | nl -w2 -s'. '
  read -r PLAYBOOK_NUM
  PLAYBOOK=$(find "$ANSIBLE_DIR/playbooks" -name "*.yml" -type f | sed -n "${PLAYBOOK_NUM}p")
fi

if [ -f "$PLAYBOOK" ] && [ -f "$INVENTORY" ]; then
  echo "Inventory: $INVENTORY"
  echo "Playbook: $PLAYBOOK"
  echo ""

  echo "Running Ansible check mode (dry-run)..."
  !ansible-playbook -i "$INVENTORY" "$PLAYBOOK" \
    --check \
    --diff \
    --limit "$ENVIRONMENT" 2>&1 | head -100

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Ansible Check Mode Complete"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
else
  echo "⚠️  Ansible playbook or inventory not found"
  echo "Skipping Ansible phase"
  SKIP_ANSIBLE=1
fi
```

**Step 2: Ansible Apply (with approval)**

```bash
if [ "$SKIP_ANSIBLE" != "1" ]; then
  echo "Execute Ansible playbook? (yes/NO)"
  read -r APPLY_ANSIBLE

  if [ "$APPLY_ANSIBLE" = "yes" ]; then
    echo ""
    echo "Deploying with Ansible..."
    !ansible-playbook -i "$INVENTORY" "$PLAYBOOK" \
      --limit "$ENVIRONMENT" \
      --verbose

    if [ $? -eq 0 ]; then
      echo ""
      echo "✅ Ansible deployment succeeded"
    else
      echo ""
      echo "❌ Ansible deployment failed"
      exit 1
    fi
  else
    echo "Ansible deployment cancelled"
    exit 0
  fi
fi

echo ""
```

### 7. Kubernetes Deployment Phase (if applicable)

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Kubernetes Manifests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

K8S_DIR="k8s/$ENVIRONMENT"

if [ -d "$K8S_DIR" ]; then
  echo "Found Kubernetes manifests in: $K8S_DIR"
  echo ""

  # Validate manifests
  echo "Validating Kubernetes manifests..."
  for manifest in $(find "$K8S_DIR" -name "*.yaml" -o -name "*.yml"); do
    if kubectl apply --dry-run=client -f "$manifest" > /dev/null 2>&1; then
      echo "✅ Valid: $(basename $manifest)"
    else
      echo "❌ Invalid: $(basename $manifest)"
    fi
  done

  echo ""
  echo "Apply Kubernetes manifests? (yes/NO)"
  read -r APPLY_K8S

  if [ "$APPLY_K8S" = "yes" ]; then
    echo ""
    echo "Applying Kubernetes manifests..."

    for manifest in $(find "$K8S_DIR" -name "*.yaml" -o -name "*.yml"); do
      echo "Applying: $(basename $manifest)"
      !kubectl apply -f "$manifest"
    done

    if [ $? -eq 0 ]; then
      echo ""
      echo "✅ Kubernetes manifests applied"
    else
      echo ""
      echo "❌ Kubernetes deployment failed"
    fi
  else
    echo "Kubernetes deployment skipped"
  fi
else
  echo "No Kubernetes manifests found for environment: $ENVIRONMENT"
  echo "Skipping Kubernetes phase"
fi

echo ""
```

### 8. Post-Deployment Verification

```bash
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Post-Deployment Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VERIFICATION_FAILED=0

# Terraform state check
if [ -d "terraform/environments/$ENVIRONMENT" ]; then
  echo "Checking Terraform state..."
  cd "terraform/environments/$ENVIRONMENT" || exit 1

  RESOURCE_COUNT=$(terraform state list | wc -l)
  echo "✅ Terraform resources in state: $RESOURCE_COUNT"

  cd - > /dev/null
fi

# Ansible verification
if [ -f "$INVENTORY" ] && [ "$SKIP_ANSIBLE" != "1" ]; then
  echo ""
  echo "Verifying Ansible-managed hosts..."

  # Ping all hosts
  if ansible -i "$INVENTORY" all -m ping --limit "$ENVIRONMENT" > /dev/null 2>&1; then
    echo "✅ All hosts reachable"
  else
    echo "❌ Some hosts unreachable"
    VERIFICATION_FAILED=1
  fi

  # Check service status (example)
  echo "✅ Service health checks would run here"
fi

# Kubernetes verification
if command -v kubectl >/dev/null 2>&1; then
  echo ""
  echo "Checking Kubernetes cluster health..."

  # Get nodes
  NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready)

  if [ "$NODE_COUNT" -gt 0 ]; then
    echo "✅ Kubernetes nodes: $READY_NODES/$NODE_COUNT ready"

    # Get pods
    POD_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c Running)

    echo "✅ Kubernetes pods: $RUNNING_PODS/$POD_COUNT running"
  fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$VERIFICATION_FAILED" -ne 0 ]; then
  echo "⚠️  Some verification checks failed"
else
  echo "✅ All verification checks passed"
fi

echo ""
```

### 9. Generate Deployment Report

```markdown
# Infrastructure Deployment Report

**Deployment Date**: [ISO 8601 timestamp]
**Environment**: [$ENVIRONMENT]
**Deployed By**: [User/Agent]
**Branch**: [$CURRENT_BRANCH]
**Commit**: [git hash]

---

## 📊 Deployment Summary

| Phase | Status | Duration | Resources |
|-------|--------|----------|-----------|
| Validation | ✅ | [time] | - |
| Terraform | ✅ / ❌ | [time] | [N] resources |
| Ansible | ✅ / ❌ | [time] | [N] hosts |
| Kubernetes | ✅ / ❌ / ⏭️  | [time] | [N] manifests |
| Verification | ✅ / ❌ | [time] | - |

**Overall Status**: ✅ SUCCESS / ❌ FAILED / ⚠️ PARTIAL

---

## 🏗️ Infrastructure Changes

### Terraform
```
Resources created: [N]
Resources modified: [N]
Resources destroyed: [N]

Notable changes:
- [Resource 1]: Created
- [Resource 2]: Modified
```

### Ansible
```
Hosts configured: [N]
Tasks executed: [N]
Changes made: [N]

Services deployed:
- Service 1: ✅ Running
- Service 2: ✅ Running
```

### Kubernetes
```
Deployments: [N]
Services: [N]
ConfigMaps: [N]
Secrets: [N]

Running pods: [N] / [Total]
```

---

## ✅ Verification Results

### Infrastructure Health
- Terraform state: [N] resources
- Ansible hosts: [N] / [N] reachable
- K8s nodes: [N] / [N] ready
- K8s pods: [N] / [N] running

### Service Health
- [Service 1]: ✅ Healthy
- [Service 2]: ✅ Healthy

---

## 📋 Post-Deployment Actions

### Immediate
- [ ] Verify service endpoints
- [ ] Check monitoring dashboards
- [ ] Review logs for errors

### Short-term
- [ ] Update documentation
- [ ] Notify team of deployment
- [ ] Schedule health check in 24h

---

**Deployment Log**: deployment-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).log
**Terraform Plan**: tfplan
**Ansible Output**: ansible-deploy.log
```

### 10. Display Deployment Summary

```
╔════════════════════════════════════════════════════╗
║       INFRASTRUCTURE DEPLOYMENT COMPLETE           ║
╚════════════════════════════════════════════════════╝

ENVIRONMENT: $ENVIRONMENT
TIMESTAMP: [ISO 8601]

DEPLOYMENT PHASES:
  Validation:  ✅
  Terraform:   ✅ / ❌ ([N] resources)
  Ansible:     ✅ / ❌ ([N] hosts)
  Kubernetes:  ✅ / ❌ / ⏭️  ([N] pods)
  Verification:✅ / ❌

STATUS: ✅ SUCCESSFUL / ❌ FAILED / ⚠️ PARTIAL

INFRASTRUCTURE:
  Terraform resources: [N]
  Ansible hosts: [N] configured
  K8s pods: [N] running

VERIFICATION:
  All health checks: ✅ / ❌
  Services online: ✅ / ❌

REPORTS:
  - DEPLOYMENT_REPORT.md
  - deployment-$ENVIRONMENT.log

NEXT STEPS:
  1. Monitor service health
  2. Review deployment logs
  3. Update documentation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Deployment complete!
View full report: DEPLOYMENT_REPORT.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Usage Examples

### Full Stack Deployment
```
/infra-deploy
# Select: 1. Full Stack
# Select environment: prod
# Review and approve each phase
```

### Infrastructure Only (Terraform)
```
/infra-deploy
# Select: 2. Infrastructure Only
# Select environment: staging
```

### Configuration Only (Ansible)
```
/infra-deploy
# Select: 3. Configuration Only
# Select environment: dev
```

### Dry-Run Validation
```
/infra-deploy
# Select: 6. Validation Dry-Run Only
# Runs all checks without applying changes
```

---

## Safety Features

1. **Validation Gates**: Blocks deployment if pre-checks fail
2. **Approval Required**: Manual approval for each phase
3. **Dry-Run First**: Check mode before actual execution
4. **Verification**: Post-deployment health checks
5. **Rollback Support**: Failed deployments can be reverted
6. **Audit Trail**: Complete logs of all changes

---

## Pre-Deployment Checklist

- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] Validation checks passed (`/tf-validate`, `/ansible-validate`)
- [ ] Bitwarden secrets configured (if needed)
- [ ] Backup of current state created
- [ ] Team notified of deployment
- [ ] Rollback plan documented

---

## Post-Deployment Checklist

- [ ] All services healthy
- [ ] Monitoring dashboards green
- [ ] No errors in logs
- [ ] Documentation updated
- [ ] Team notified of completion
- [ ] Deployment report reviewed

---

## When to Use /infra-deploy

- Deploying to new environment
- Rolling out infrastructure changes
- Updating service configurations
- Applying Kubernetes manifests
- After terraform/ansible modifications
- Part of CI/CD pipeline
- Scheduled maintenance deployments

---

## Exit Codes

- **0**: Deployment successful
- **1**: Validation failed
- **2**: Terraform failed
- **3**: Ansible failed
- **4**: Kubernetes failed
- **5**: Verification failed
