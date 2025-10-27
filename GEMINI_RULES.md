# GEMINI_RULES.md — Google Gemini Guidelines for Home Lab Infrastructure

## Home Lab Philosophy: Learning + Production Patterns

This repository represents a **home lab environment** that intentionally blends:
- 🎓 **Learning objectives** (experimentation, skill development, trying new tech)
- 🏭 **Production patterns** (HA, monitoring, security, reliability)
- 💰 **Budget constraints** (cost-effective solutions, resource optimization)
- ⚡ **Rapid iteration** (quick deployments, safe to fail, rollback capability)

When providing code suggestions, recommendations, or architectural guidance, **balance these competing priorities**.

## Code Quality Standards: Staging/Pre-Production Level

### Quality Target: "Would You Deploy This to Staging?"

**Not Enterprise-Strict:**
- ❌ Don't require 100% test coverage
- ❌ Don't enforce every possible lint rule
- ❌ Don't demand exhaustive documentation for every function
- ❌ Don't block commits for minor style issues

**But Staging/Pre-Prod Rigorous:**
- ✅ **Security**: No secrets in code, proper secret management (Bitwarden)
- ✅ **Functionality**: Code must work reliably, handle errors gracefully
- ✅ **Readability**: Clear naming, comments on complex logic, understandable by others
- ✅ **Testing**: Critical paths tested, can validate changes work
- ✅ **Documentation**: Key decisions explained, usage examples provided
- ✅ **Maintainability**: Can be updated 6 months later without confusion

### Practical Quality Gates

**🔴 Must Pass (Failures Block Merge):**
- No secrets committed to Git (detect-secrets enforced)
- Ansible playbooks pass syntax check (`ansible-playbook --syntax-check`)
- Terraform code formatted and validated (`terraform fmt`, `terraform validate`)
- YAML files syntactically valid (yamllint with relaxed rules)
- Critical security vulnerabilities addressed (tfsec/checkov high/critical)
- No broken functionality in main code paths

**🟡 Should Pass (Warnings Acceptable):**
- Ansible-lint style recommendations
- Terraform tflint best practice suggestions
- Minor security improvements (medium/low severity)
- Documentation completeness
- Performance optimization opportunities
- Code style consistency

**🟢 Can Skip for WIP (But Document):**
- Use `git commit --no-verify` for work-in-progress experiments
- Add WIP prefix to commit messages
- Explain what's being tested and why checks are bypassed
- Fix before merging to main branch

## Infrastructure Architecture Patterns

### High Availability (HA) Principles
When designing infrastructure components, consider HA even in home lab context:

**Multi-Node Redundancy:**
```yaml
# Good: HA-capable design
kubernetes_control_plane:
  nodes: 3
  distribution: different physical hosts

database:
  primary: node1
  replicas: [node2, node3]
  automatic_failover: true
```

**Load Balancing:**
```hcl
# Good: Traffic distribution across multiple backends
resource "proxmox_vm_qemu" "web_server" {
  count = 3  # Multiple instances

  tags = {
    role = "web"
    load_balanced = "true"
  }
}
```

**Graceful Degradation:**
```python
# Good: Fail gracefully, continue with reduced functionality
try:
    metrics_client = PrometheusClient(config)
except ConnectionError:
    logger.warning("Metrics unavailable, continuing without observability")
    metrics_client = NullMetricsClient()
```

### Caching and Performance
Home labs have resource constraints—optimize aggressively:

**Layer Caching:**
```yaml
# Ansible: Cache facts for faster playbook runs
ansible.cfg:
  gathering: smart
  fact_caching: jsonfile
  fact_caching_timeout: 3600
```

**HTTP Caching:**
```nginx
# Nginx: Cache static content, reduce origin requests
location /static/ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

**Container Registry Caching:**
```yaml
# K8s: Use local registry mirror to cache images
apiVersion: v1
kind: ConfigMap
metadata:
  name: registry-mirror
data:
  config: |
    registry-mirrors:
      - https://registry.local:5000
```

## Secrets Management: Bitwarden Migration Context

### Current Migration Status
This project is **actively migrating** from Ansible Vault to Bitwarden Secrets Manager.

**Legacy Pattern (Being Phased Out):**
```yaml
# group_vars/prod/vault.yml (encrypted with ansible-vault)
vault_database_password: "supersecret123"
vault_api_key: "abc-xyz-789"

# playbook.yml
tasks:
  - name: Configure database
    postgresql_db:
      password: "{{ vault_database_password }}"
```

**New Pattern (Target State):**
```yaml
# Secrets stored in Bitwarden Secrets Manager
# Organized by projects: dev, staging, prod
# Machine accounts for automation access

# playbook.yml
tasks:
  - name: Configure database
    postgresql_db:
      password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-postgres-password') }}"
    no_log: true
```

### When Suggesting Secret Management Solutions

**Always Prefer Bitwarden:**
- ✅ Centralized secret storage
- ✅ Granular access control via machine accounts
- ✅ Audit trail of secret access
- ✅ Team collaboration support
- ✅ API access for automation

**Avoid Suggesting:**
- ❌ Hardcoded secrets in code
- ❌ Secrets in environment files committed to Git
- ❌ Plain text config files
- ❌ New Ansible Vault encrypted files (legacy approach)

**Acceptable for Local Development:**
- ✅ `.env` files (must be gitignored)
- ✅ Local `~/.config/` files for personal credentials
- ✅ Temporary test secrets (with clear documentation they're not production)

### Secret Naming Conventions
```
Format: {environment}-{service}-{resource}-{type}

Examples:
  prod-db-postgres-password
  staging-api-jwt-secret
  dev-s3-access-key
  prod-vpn-certificate
```

## Testing Approach: Practical for Resource-Constrained Environments

### Ansible Playbook Testing

**Minimum Required Tests:**
```bash
# 1. Syntax validation (always run)
ansible-playbook playbook.yml --syntax-check

# 2. Check mode dry-run (before actual run)
ansible-playbook playbook.yml --check --diff

# 3. Lint for common issues (moderate strictness)
ansible-lint playbook.yml
```

**Recommended for Important Playbooks:**
```bash
# 4. Molecule testing for roles
cd roles/critical_role
molecule test

# 5. Integration testing in dev environment
ansible-playbook -i inventory/dev playbook.yml --tags test
```

**Nice to Have (Not Required):**
- Unit tests for custom modules
- Full end-to-end automated testing
- Performance benchmarking

### Terraform Testing

**Minimum Required:**
```bash
# 1. Format check
terraform fmt -check -recursive

# 2. Validation
terraform validate

# 3. Plan review (always before apply)
terraform plan -out=tfplan
```

**Recommended:**
```bash
# 4. Security scanning
tfsec . --minimum-severity MEDIUM
checkov -d . --framework terraform

# 5. Documentation generation
terraform-docs markdown . > README.md
```

**Nice to Have:**
- Terratest integration tests
- Cost estimation (Infracost)
- Compliance scanning (Terrascan)

### Kubernetes Manifest Testing

**Minimum Required:**
```bash
# 1. Client-side dry run
kubectl apply --dry-run=client -f manifest.yml

# 2. Server-side validation
kubectl apply --dry-run=server -f manifest.yml
```

**Recommended:**
```bash
# 3. Schema validation
kubeval manifest.yml

# 4. Best practices check
kube-score score manifest.yml

# 5. Security scanning
kubesec scan manifest.yml
```

## Documentation Requirements: Comprehensive but Practical

### What to Document (Required)

**Infrastructure Overview:**
- System architecture diagram (even simple ASCII art)
- Network topology and IP addressing scheme
- Service dependencies and data flows
- Backup and disaster recovery procedures

**Code Documentation:**
```python
# Good: Explains WHY, not just WHAT
def retry_with_backoff(func, max_attempts=3):
    """
    Retry function with exponential backoff.

    Home lab networks can be flaky—retry important operations
    to avoid false failures from transient network issues.

    Args:
        func: Function to retry
        max_attempts: Maximum retry attempts (default: 3)

    Returns:
        Function result or raises last exception
    """
```

```yaml
# Good: Context for unusual configurations
- name: Disable SELinux (required for legacy app compatibility)
  # Note: This specific application doesn't support SELinux.
  # Considered alternatives (containers, VMs) but deployment
  # complexity too high for home lab. Trade-off accepted.
  ansible.posix.selinux:
    state: disabled
```

**README Files:**
Each major directory/module should have README.md with:
- Purpose and scope
- Prerequisites and dependencies
- Usage examples (copy-paste ready)
- Configuration options
- Troubleshooting common issues

### What NOT to Document (Overkill)

**Don't Waste Time On:**
- ❌ Documenting every single variable (self-explanatory ones)
- ❌ API-doc style function documentation for simple utility functions
- ❌ Change logs for every minor tweak (Git history suffices)
- ❌ Detailed explanations of well-known tools (link to official docs instead)

**Instead Focus Energy On:**
- ✅ Non-obvious design decisions
- ✅ Workarounds for specific issues
- ✅ Integration points between systems
- ✅ Lessons learned and failure post-mortems

## AI-Assisted Code Generation Guidelines

### When Generating Ansible Playbooks

**Always Include:**
1. FQCN (Fully Qualified Collection Names): `ansible.builtin.copy` not `copy`
2. Idempotency: Tasks safe to run multiple times
3. Error handling: `block/rescue` for complex tasks
4. Tags: For selective execution
5. Check mode support: Where applicable

**Example:**
```yaml
- name: Install and configure nginx
  hosts: web_servers
  become: true

  tasks:
    - name: Install nginx package
      ansible.builtin.package:
        name: nginx
        state: present
      tags: [install, nginx]

    - name: Deploy nginx configuration
      ansible.builtin.template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        validate: 'nginx -t -c %s'
      notify: Reload nginx
      tags: [config, nginx]

  handlers:
    - name: Reload nginx
      ansible.builtin.systemd:
        name: nginx
        state: reloaded
```

### When Generating Terraform Code

**Always Include:**
1. Version constraints: Both terraform and providers
2. Resource tagging: For organization and cost tracking
3. Lifecycle rules: For HA and safe updates
4. Output values: For integration with other modules
5. Variable validation: Where applicable

**Example:**
```hcl
terraform {
  required_version = ">= 1.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.vm_name))
    error_message = "VM name must contain only lowercase letters, numbers, and hyphens."
  }
}

resource "proxmox_vm_qemu" "this" {
  name = var.vm_name

  # HA: Create replacement before destroying old
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
  }
}

output "vm_ip" {
  description = "IP address of the created VM"
  value       = proxmox_vm_qemu.this.default_ipv4_address
}
```

### When Generating Kubernetes Manifests

**Always Include:**
1. Resource limits: CPU and memory constraints
2. Health probes: Liveness and readiness checks
3. Labels: For organization and selection
4. Specific image tags: Never use `:latest`
5. Security context: Run as non-root where possible

**Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: myapp
    tier: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000

      containers:
      - name: app
        image: registry.local/myapp:v1.2.3  # Specific version

        ports:
        - containerPort: 8080

        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30

        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
```

## Cost and Resource Optimization

### Think Home Lab, Not Cloud Scale

**Optimize for Limited Resources:**
```yaml
# Good: Right-sized for home lab
kubernetes_node:
  ram: "16GB"
  cpu_cores: 4
  over_provision_ratio: 1.2  # Some overcommit acceptable

# Bad: Cloud-scale overkill
kubernetes_node:
  ram: "64GB"
  cpu_cores: 16
  dedicated_per_service: true  # Wasteful at home lab scale
```

**Shared Infrastructure:**
```yaml
# Good: Multi-tenant where safe
database_cluster:
  instances: 3
  hosts_multiple_apps: true
  resource_isolation: namespace_level

# Bad: Dedicated everything
database_cluster:
  instances_per_app: 3
  dedicated_nodes: true  # Unnecessary cost
```

**Storage Tiering:**
```yaml
# Good: Tiered storage strategy
storage:
  hot_data: ssd  # Active databases, frequently accessed
  warm_data: hdd  # Logs, infrequently accessed
  cold_data: external  # Backups, archives
```

## Error Handling and Resilience

### Fail Gracefully in Home Lab Context

**Network is Unreliable:**
```python
# Home WiFi/network can be flaky
@retry(tries=3, delay=2, backoff=2)
def fetch_external_resource(url):
    """Retry with exponential backoff for network ops."""
    return requests.get(url, timeout=10)
```

**Services May Be Down:**
```yaml
# Allow deployments to succeed even if monitoring is down
- name: Register service with Prometheus
  uri:
    url: "{{ prometheus_url }}/api/v1/targets"
    method: POST
    body_format: json
    body: "{{ service_config }}"
  ignore_errors: true  # Don't block deployment
  tags: [monitoring]
```

**Handle Resource Exhaustion:**
```yaml
# Home lab may run out of resources
- name: Deploy application
  kubernetes.core.k8s:
    definition: "{{ app_manifest }}"
    state: present
  register: deploy_result
  failed_when:
    - deploy_result is failed
    - "'insufficient memory' not in deploy_result.msg"  # Acceptable in home lab
```

## Summary: Gemini's Role in This Project

When working with this home lab repository:

1. **Balance Quality and Pragmatism**: Staging-level code quality, not enterprise overkill
2. **Consider Constraints**: Limited resources, budget, time
3. **Embrace Learning**: Encourage experimentation, document lessons learned
4. **Prioritize Functionality**: Must work reliably, handle failures gracefully
5. **Think HA**: Use production patterns even at small scale
6. **Optimize Resources**: Efficient use of CPU, RAM, storage, network
7. **Secure by Default**: Bitwarden for secrets, no hardcoded credentials
8. **Document Decisions**: Explain why, not just what
9. **Enable Iteration**: Fast feedback loops, safe to experiment
10. **Share Knowledge**: Code and patterns should be reusable by community

**Your output should help build a home lab that is:**
- ✅ Reliable enough to run 24/7
- ✅ Secure enough to expose selected services
- ✅ Documented enough to maintain months later
- ✅ Efficient enough to run on limited hardware
- ✅ Flexible enough to experiment and learn
- ✅ Sharable enough to help others build similar setups
