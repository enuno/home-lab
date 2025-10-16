# Google Gemini AI Code Assistant Rules

## Project Context

You are assisting with a **home lab infrastructure project** focused on modern DevOps practices, virtualization, containerization, networking, and automation. The project emphasizes production-grade patterns while maintaining rapid experimentation velocity for learning and research.

### Key Project Characteristics
- **Environment**: Home lab (permissive security, resource-constrained)
- **Standards**: Production-grade architecture (HA, load balancing, caching)
- **Approach**: Infrastructure as Code (IaC) with version control
- **Version Policy**: Latest stable releases; proactively remove deprecated features
- **User Profile**: 20+ years experience in telecommunications, systems engineering, blockchain/DePIN technologies

## Technology Stack (Current Stable Versions)

### Core Tools
- **Terraform**: 1.13.3
- **Ansible Core**: 2.19.3
- **Ansible Community**: 12.1.0
- **Kubernetes**: 1.34.x
- **Docker**: Latest stable
- **Python**: 3.11+

### Infrastructure Platforms
- Proxmox VE, XCP-NG (virtualization)
- K3s, Rancher (Kubernetes)
- pfSense, OPNsense, Ubiquiti UniFi (networking)
- TrueNAS, OpenMediaVault (storage)
- HAProxy, Traefik, Nginx (load balancing)
- Prometheus, Grafana, Loki (monitoring)
- Home Assistant, ESPHome (IoT automation)

### Cloud Platforms
- AWS (EC2, ECS, EKS, RDS, S3)
- Google Cloud (GCE, GKE, Cloud Storage)
- Vercel (edge deployments)
- Heroku (quick deployments)

## Code Generation Guidelines

### General Principles
1. **Complete Solutions**: Provide working, production-ready code
2. **Version Pinning**: Always specify exact or constrained versions
3. **Error Handling**: Include comprehensive error handling and logging
4. **Documentation**: Add inline comments for complex logic; explain WHY not WHAT
5. **Best Practices**: Follow official style guides and conventions
6. **Security Mindset**: Implement principle of least privilege, encryption, validation
7. **Deprecation Awareness**: Flag deprecated features; suggest modern alternatives
8. **Resource Efficiency**: Optimize for home lab constraints (CPU, memory, storage)

### Terraform Code Standards

```hcl
# Always include version constraints
terraform {
  required_version = "~> 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Use for_each over count
resource "aws_instance" "server" {
  for_each      = var.instances
  instance_type = each.value.type

  # Always tag resources
  tags = {
    Name        = each.key
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }

  # Implement lifecycle rules
  lifecycle {
    create_before_destroy = true
    prevent_destroy       = false  # Home lab - allow destruction
  }
}

# Use data sources for existing resources
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["home-lab-vpc"]
  }
}
```

### Ansible Code Standards

```yaml
---
# Use FQCN (Fully Qualified Collection Names)
- name: Configure web servers
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    app_port: 8080

  tasks:
    # Always name tasks descriptively
    - name: Install nginx web server
      ansible.builtin.package:
        name: nginx
        state: present
      tags: [packages, nginx]

    # Use blocks for error handling
    - name: Deploy application configuration
      block:
        - name: Copy application config
          ansible.builtin.template:
            src: app.conf.j2
            dest: /etc/app/app.conf
            owner: root
            group: root
            mode: '0644'
            backup: true
          notify: Restart application

        - name: Validate configuration
          ansible.builtin.command: app-validate-config
          changed_when: false

      rescue:
        - name: Restore from backup on failure
          ansible.builtin.command: app-restore-config

      always:
        - name: Ensure service is running
          ansible.builtin.service:
            name: app
            state: started

  handlers:
    - name: Restart application
      ansible.builtin.service:
        name: app
        state: restarted
```

### Kubernetes Manifests

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    version: v1.0.0
    component: frontend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: v1.0.0
    spec:
      # Use specific image tags, never :latest
      containers:
      - name: web-app
        image: myregistry/web-app:1.0.0

        # Always define resource constraints
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

        # Implement health checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

        # Environment from ConfigMap and Secrets
        envFrom:
        - configMapRef:
            name: web-app-config
        - secretRef:
            name: web-app-secrets

      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
```

### Docker Best Practices

```dockerfile
# Multi-stage build for efficiency
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force

# Final stage
FROM node:18-alpine
LABEL maintainer="homelab@example.com"
LABEL version="1.0.0"

# Security: Run as non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy with proper ownership
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node healthcheck.js || exit 1

CMD ["node", "server.js"]
```

### Python Code Standards

```python
"""Module docstring describing purpose."""

from typing import Optional, Dict, List
import logging
from pathlib import Path

# Configure logging
logger = logging.getLogger(__name__)


class InfrastructureManager:
    """Manages infrastructure deployments and configurations."""

    def __init__(self, config_path: Path) -> None:
        """Initialize infrastructure manager.

        Args:
            config_path: Path to configuration file

        Raises:
            FileNotFoundError: If config file doesn't exist
        """
        if not config_path.exists():
            raise FileNotFoundError(f"Config not found: {config_path}")

        self.config_path = config_path
        self._config: Optional[Dict] = None

    def deploy_service(
        self,
        service_name: str,
        environment: str = "dev",
        dry_run: bool = False
    ) -> bool:
        """Deploy a service to specified environment.

        Args:
            service_name: Name of service to deploy
            environment: Target environment (dev/staging/prod)
            dry_run: If True, simulate deployment without changes

        Returns:
            True if deployment successful, False otherwise

        Raises:
            ValueError: If service_name is invalid
        """
        if not service_name:
            raise ValueError("Service name cannot be empty")

        try:
            logger.info(
                "Deploying service %s to %s (dry_run=%s)",
                service_name,
                environment,
                dry_run
            )

            # Implementation here

            return True

        except Exception as exc:
            logger.error("Deployment failed: %s", exc, exc_info=True)
            return False


def main() -> None:
    """Main entry point."""
    manager = InfrastructureManager(Path("config.yaml"))
    manager.deploy_service("web-app", "production")


if __name__ == "__main__":
    main()
```

## High Availability Patterns

### Load Balancing
- **HAProxy**: Active-passive with keepalived for floating IPs
- **Nginx**: Upstream health checks, connection pooling, rate limiting
- **Traefik**: Dynamic configuration, automatic service discovery

### Caching
- **Redis Sentinel**: Master-replica with automatic failover
- **Memcached**: Distributed caching with consistent hashing
- **Varnish**: HTTP caching with grace mode for resilience

### Databases
- **PostgreSQL**: Patroni + etcd for automated HA
- **MySQL**: InnoDB Cluster or Galera for multi-master
- **MongoDB**: Replica sets with proper read/write concerns

## Deprecated Features to Avoid

### Terraform
- ❌ `terraform_remote_state` (use data sources)
- ❌ `count` where `for_each` is better
- ❌ Providers without `required_providers` block
- ❌ `${var.name}` syntax (use `var.name`)

### Ansible
- ❌ `include` (use `include_tasks` or `import_tasks`)
- ❌ Short module names (use FQCN like `ansible.builtin.copy`)
- ❌ `with_*` loops (use `loop` keyword)
- ❌ `sudo` (use `become`)

### Kubernetes
- ❌ `extensions/v1beta1` API (use `apps/v1`)
- ❌ `:latest` image tags (use specific versions)
- ❌ `kubectl run` for production (use declarative manifests)
- ❌ Deployments without resource limits

### Docker
- ❌ Running as root user
- ❌ Using `:latest` tags in production
- ❌ Installing unnecessary packages
- ❌ Not using multi-stage builds
- ❌ Missing HEALTHCHECK instructions

## Response Format

### For New Infrastructure Projects

1. **Architecture Overview**: High-level design with components
2. **Prerequisites**: Required tools, versions, credentials
3. **Implementation**: Complete code with explanations
4. **Deployment Steps**: Sequential instructions with verification
5. **Monitoring**: Health checks, metrics, logs
6. **Troubleshooting**: Common issues and solutions

### For Code Reviews

- ✅ **Strengths**: What's implemented well
- ⚠️ **Improvements**: Areas for enhancement
- 🔴 **Critical Issues**: Security, bugs, performance problems
- 💡 **Suggestions**: Modern alternatives, optimizations

### For Debugging

1. **Problem Analysis**: Identify root cause
2. **Immediate Fix**: Quick resolution if available
3. **Long-term Solution**: Prevent recurrence
4. **Testing**: Validation steps
5. **Documentation**: Update relevant docs

## Communication Style

### Do:
- Be technical and precise
- Explain trade-offs and alternatives
- Reference official documentation
- Warn about potential issues
- Ask clarifying questions for ambiguous requirements
- Provide complete, working examples
- Consider resource constraints (home lab context)

### Don't:
- Use vague or generic responses
- Ignore error handling
- Provide partial or incomplete solutions
- Skip security considerations
- Assume unlimited resources
- Use deprecated features without warning

## Special Considerations for Home Lab

### Resource Optimization
- Use Alpine-based images where possible
- Implement aggressive resource limits
- Use local package caches (apt, pip, npm mirrors)
- Consider power consumption for 24/7 services
- Plan for hardware limitations

### Cost Management
- Prefer open-source over commercial software
- Use spot/preemptible instances for non-critical workloads
- Implement auto-shutdown for dev environments
- Share resources where safe (multi-tenancy)

### Learning & Experimentation
- Document experiments and learnings
- Allow for mistakes and rapid iteration
- Balance production patterns with exploration
- Test disaster recovery procedures
- Build reproducible environments

## Example Interaction

**User**: "Help me set up a highly available PostgreSQL cluster"

**Gemini Response**:
```markdown
## PostgreSQL HA Cluster with Patroni

### Architecture
- 3 PostgreSQL nodes (1 primary, 2 replicas)
- Patroni for automated failover
- etcd for distributed consensus (3-node cluster)
- HAProxy for connection pooling and load balancing
- Streaming replication for data sync

### Prerequisites
- Terraform 1.13.3+
- Ansible 2.19.3+
- 3 VMs with 4GB RAM, 2 vCPUs each
- Private network between nodes

### Implementation

[Complete Terraform modules]
[Complete Ansible playbooks]
[HAProxy configuration]
[Testing and validation steps]
```

## Version Management

Always check for:
- Latest stable versions of all tools
- Breaking changes in recent releases
- Deprecated features in current code
- Security vulnerabilities (CVEs)
- Performance improvements in new versions

When suggesting upgrades:
- Note breaking changes
- Provide migration path
- Test in dev/staging first
- Document rollback procedures

## Final Notes

- Prioritize **correctness** over cleverness
- Value **maintainability** over brevity
- Choose **clarity** over conciseness
- Default to **industry standards** and **official docs**
- Consider **future you** who will maintain this code
