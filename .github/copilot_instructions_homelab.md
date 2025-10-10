# GitHub Copilot Instructions - Home Lab Infrastructure

## Project Context

This is a **home lab infrastructure project** focused on production-grade DevOps patterns with rapid experimentation velocity. The project encompasses virtualization, containerization, networking, storage, automation, and cloud-native architectures.

### Key Characteristics
- **Environment**: Home lab (permissive security, resource-constrained)
- **Standards**: Production-grade architecture (HA, load balancing, caching)
- **Approach**: Infrastructure as Code with version control
- **Version Policy**: Latest stable releases; no deprecated features
- **User Experience**: 20+ years in telecommunications, systems engineering, blockchain/DePIN

## Current Technology Versions

```yaml
Terraform: 1.13.3
Ansible Core: 2.19.3
Ansible Community: 12.1.0
Kubernetes: 1.34.x
Docker: Latest stable
Python: 3.11+
Node.js: 20 LTS
Go: 1.21+
```

## Code Generation Guidelines

### General Principles

1. **Complete Solutions**: Generate production-ready, working code
2. **Error Handling**: Always include comprehensive error handling
3. **Logging**: Add structured logging with appropriate levels
4. **Documentation**: Include inline comments for complex logic
5. **Type Safety**: Use type hints (Python), TypeScript, strong typing
6. **Security First**: Implement least privilege, validation, sanitization
7. **Resource Efficiency**: Optimize for home lab constraints
8. **Modern Patterns**: Use current best practices, avoid deprecated features

### Terraform Code Style

```hcl
# Always specify version constraints
terraform {
  required_version = "~> 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Prefer for_each over count for resources
resource "aws_instance" "server" {
  for_each = var.instances
  
  instance_type = each.value.type
  ami           = data.aws_ami.latest.id
  
  # Always tag resources
  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
  
  # Implement lifecycle rules
  lifecycle {
    create_before_destroy = true
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

### Ansible Code Style

```yaml
---
# Use FQCN (Fully Qualified Collection Names)
- name: Configure web servers
  hosts: webservers
  become: true
  gather_facts: true
  
  vars:
    app_version: "1.0.0"
    
  tasks:
    - name: Install nginx package
      ansible.builtin.package:
        name: nginx
        state: present
      tags: [packages, nginx]
    
    # Use blocks for error handling
    - name: Deploy application configuration
      block:
        - name: Template configuration file
          ansible.builtin.template:
            src: app.conf.j2
            dest: /etc/app/app.conf
            owner: root
            group: root
            mode: '0644'
            backup: true
            validate: 'app-config-validator %s'
          notify: Restart application
          
      rescue:
        - name: Restore backup configuration
          ansible.builtin.command:
            cmd: app-restore-config
          changed_when: true
          
      always:
        - name: Verify service health
          ansible.builtin.uri:
            url: http://localhost:8080/health
            status_code: 200
          retries: 3
          delay: 5
  
  handlers:
    - name: Restart application
      ansible.builtin.service:
        name: app
        state: restarted
```

### Python Code Style

```python
"""Module docstring with clear description."""

from typing import Optional, Dict, List, Any
import logging
from pathlib import Path
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class Config:
    """Configuration data class."""
    name: str
    environment: str
    debug: bool = False


class InfrastructureManager:
    """Manages infrastructure deployments.
    
    Attributes:
        config: Configuration object
        _state: Internal state dictionary
    """

    def __init__(self, config: Config) -> None:
        """Initialize the infrastructure manager.
        
        Args:
            config: Configuration object with deployment settings
            
        Raises:
            ValueError: If configuration is invalid
        """
        if not config.name:
            raise ValueError("Configuration name cannot be empty")
        
        self.config = config
        self._state: Dict[str, Any] = {}
        logger.info("Infrastructure manager initialized for %s", config.name)

    def deploy(
        self, 
        service_name: str,
        version: str,
        dry_run: bool = False,
        **kwargs: Any
    ) -> bool:
        """Deploy a service to the infrastructure.
        
        Args:
            service_name: Name of the service to deploy
            version: Version string (semver format)
            dry_run: If True, simulate deployment without changes
            **kwargs: Additional deployment parameters
            
        Returns:
            True if deployment successful, False otherwise
            
        Raises:
            ValueError: If service_name or version is invalid
        """
        if not service_name or not version:
            raise ValueError("Service name and version are required")
        
        try:
            logger.info(
                "Deploying %s v%s (dry_run=%s)",
                service_name,
                version,
                dry_run
            )
            
            # Implementation here
            self._validate_deployment(service_name, version)
            
            if not dry_run:
                self._execute_deployment(service_name, version, **kwargs)
            
            return True
            
        except Exception as exc:
            logger.error(
                "Deployment failed for %s: %s",
                service_name,
                exc,
                exc_info=True
            )
            return False
    
    def _validate_deployment(self, service: str, version: str) -> None:
        """Validate deployment parameters."""
        # Validation logic
        pass
    
    def _execute_deployment(self, service: str, version: str, **kwargs: Any) -> None:
        """Execute the actual deployment."""
        # Deployment logic
        pass
```

### JavaScript/TypeScript Code Style

```typescript
/**
 * Infrastructure deployment manager
 */
import { Logger } from './logger';
import { Config, DeploymentOptions, DeploymentResult } from './types';

export class InfrastructureManager {
  private readonly logger: Logger;
  private readonly config: Config;

  /**
   * Create a new infrastructure manager
   * @param config - Configuration object
   */
  constructor(config: Config) {
    if (!config.name) {
      throw new Error('Configuration name is required');
    }

    this.config = config;
    this.logger = new Logger(config.name);
    this.logger.info('Infrastructure manager initialized');
  }

  /**
   * Deploy a service to infrastructure
   * @param serviceName - Name of the service
   * @param version - Version to deploy
   * @param options - Deployment options
   * @returns Deployment result
   */
  async deploy(
    serviceName: string,
    version: string,
    options: DeploymentOptions = {}
  ): Promise<DeploymentResult> {
    if (!serviceName || !version) {
      throw new Error('Service name and version are required');
    }

    try {
      this.logger.info(
        `Deploying ${serviceName} v${version} (dry_run=${options.dryRun || false})`
      );

      await this.validateDeployment(serviceName, version);

      if (!options.dryRun) {
        await this.executeDeployment(serviceName, version, options);
      }

      return {
        success: true,
        service: serviceName,
        version,
        timestamp: new Date(),
      };
    } catch (error) {
      this.logger.error(`Deployment failed: ${error}`);
      return {
        success: false,
        service: serviceName,
        version,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date(),
      };
    }
  }

  private async validateDeployment(service: string, version: string): Promise<void> {
    // Validation logic
  }

  private async executeDeployment(
    service: string,
    version: string,
    options: DeploymentOptions
  ): Promise<void> {
    // Deployment logic
  }
}
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
    managed-by: terraform
  annotations:
    description: "Web application frontend"
    deployment.kubernetes.io/revision: "1"
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
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      
      # Init containers
      initContainers:
      - name: wait-for-db
        image: busybox:1.36
        command: ['sh', '-c', 'until nc -z postgres 5432; do sleep 2; done']
      
      # Main containers
      containers:
      - name: web-app
        image: myregistry/web-app:1.0.0  # Never use :latest
        imagePullPolicy: IfNotPresent
        
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        
        # Resource constraints
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /healthz
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /ready
            port: http
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        # Environment configuration
        env:
        - name: ENVIRONMENT
          value: "production"
        - name: LOG_LEVEL
          value: "info"
        
        envFrom:
        - configMapRef:
            name: web-app-config
        - secretRef:
            name: web-app-secrets
        
        # Volume mounts
        volumeMounts:
        - name: config
          mountPath: /etc/app
          readOnly: true
        - name: tmp
          mountPath: /tmp
      
      # Volumes
      volumes:
      - name: config
        configMap:
          name: web-app-config
      - name: tmp
        emptyDir: {}
      
      # Pod anti-affinity for HA
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: web-app
              topologyKey: kubernetes.io/hostname
```

### Docker Best Practices

```dockerfile
# syntax=docker/dockerfile:1.4

# Multi-stage build for efficiency
FROM node:20-alpine AS builder

# Metadata
LABEL maintainer="homelab@example.com"
LABEL version="1.0.0"
LABEL description="Web application"

# Set working directory
WORKDIR /app

# Copy dependency files first (layer caching)
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Build application
RUN npm run build

# Final stage - minimal runtime image
FROM node:20-alpine

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    # Create necessary directories
    mkdir -p /app /tmp && \
    chown -R nodejs:nodejs /app /tmp

# Set working directory
WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node healthcheck.js || exit 1

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000

# Start application
CMD ["node", "dist/server.js"]
```

## High Availability Patterns

### Load Balancer Configuration (HAProxy)

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  http-server-close
    option  forwardfor except 127.0.0.0/8
    option  redispatch
    retries 3
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

frontend web_frontend
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    
    # HTTP to HTTPS redirect
    redirect scheme https code 301 if !{ ssl_fc }
    
    # Security headers
    http-response set-header X-Frame-Options SAMEORIGIN
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header X-XSS-Protection "1; mode=block"
    
    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    default_backend web_backend

backend web_backend
    balance roundrobin
    option httpchk GET /health HTTP/1.1\r\nHost:\ localhost
    http-check expect status 200
    
    # Connection pooling
    server web1 192.168.1.10:8080 check inter 5s fall 3 rise 2 maxconn 100
    server web2 192.168.1.11:8080 check inter 5s fall 3 rise 2 maxconn 100
    server web3 192.168.1.12:8080 check inter 5s fall 3 rise 2 maxconn 100

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 30s
    stats show-legends
```

## Deprecated Features - Never Use

### Terraform
❌ `terraform_remote_state` data source (use direct data sources)
❌ `count` where `for_each` is more appropriate
❌ `${var.name}` interpolation syntax (use `var.name`)
❌ Providers without `required_providers` block
❌ Resources without lifecycle rules for critical infrastructure

### Ansible
❌ `include` (use `include_tasks` or `import_tasks`)
❌ Short module names (always use FQCN like `ansible.builtin.copy`)
❌ `with_*` loops (use `loop` keyword)
❌ Bare variables in conditionals (use `{{ }}`)
❌ `sudo` (use `become`)
❌ `action: module` syntax (use `module:`)

### Kubernetes
❌ `extensions/v1beta1` API version (use `apps/v1`)
❌ `:latest` image tags in production
❌ `kubectl run` for production workloads (use manifests)
❌ Deployments without resource requests/limits
❌ Missing health checks (liveness/readiness probes)
❌ Services without pod disruption budgets

### Docker
❌ Running containers as root
❌ Using `:latest` tags in production
❌ Installing unnecessary packages
❌ Not using multi-stage builds
❌ Missing HEALTHCHECK instructions
❌ Exposing sensitive information in ENV

### Python
❌ `#!/usr/bin/env python` (use `#!/usr/bin/env python3`)
❌ `dict.has_key()` (use `in` operator)
❌ `<>` operator (use `!=`)
❌ `print` statement (use `print()` function)
❌ String formatting with `%` (use f-strings)

## Security Best Practices

### Input Validation
```python
def validate_input(data: str) -> bool:
    """Validate and sanitize user input."""
    import re
    
    # Whitelist validation
    pattern = r'^[a-zA-Z0-9_-]+$'
    if not re.match(pattern, data):
        raise ValueError("Invalid input format")
    
    # Length validation
    if len(data) > 255:
        raise ValueError("Input too long")
    
    return True
```

### Secret Management
```python
import os
from pathlib import Path

# ✅ Good: Load from environment or secrets manager
api_key = os.getenv('API_KEY')
if not api_key:
    raise ValueError("API_KEY environment variable not set")

# ✅ Good: Load from mounted secret
secret_file = Path('/run/secrets/api_key')
if secret_file.exists():
    api_key = secret_file.read_text().strip()

# ❌ Bad: Hardcoded secrets
# api_key = "sk-1234567890abcdef"
```

### SQL Injection Prevention
```python
import psycopg2

# ✅ Good: Parameterized queries
def get_user(conn, user_id: int):
    cursor = conn.cursor()
    cursor.execute(
        "SELECT * FROM users WHERE id = %s",
        (user_id,)
    )
    return cursor.fetchone()

# ❌ Bad: String concatenation
# def get_user(conn, user_id):
#     cursor = conn.cursor()
#     cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")
#     return cursor.fetchone()
```

## Testing Patterns

### Python Testing
```python
import pytest
from unittest.mock import Mock, patch

class TestInfrastructureManager:
    """Test suite for InfrastructureManager."""
    
    @pytest.fixture
    def manager(self):
        """Create a manager instance for testing."""
        config = Config(name="test", environment="dev")
        return InfrastructureManager(config)
    
    def test_deploy_success(self, manager):
        """Test successful deployment."""
        result = manager.deploy("web-app", "1.0.0", dry_run=True)
        assert result is True
    
    def test_deploy_invalid_name(self, manager):
        """Test deployment with invalid service name."""
        with pytest.raises(ValueError, match="Service name"):
            manager.deploy("", "1.0.0")
    
    @patch('module.external_api_call')
    def test_deploy_with_mock(self, mock_api, manager):
        """Test deployment with mocked external calls."""
        mock_api.return_value = {"status": "success"}
        result = manager.deploy("web-app", "1.0.0")
        assert result is True
        mock_api.assert_called_once()
```

## Performance Optimization

### Database Query Optimization
```python
# ✅ Good: Batch operations
def update_users_batch(conn, user_updates: List[Dict]):
    """Update multiple users in a single transaction."""
    cursor = conn.cursor()
    try:
        cursor.execute("BEGIN")
        cursor.executemany(
            "UPDATE users SET status = %s WHERE id = %s",
            [(u['status'], u['id']) for u in user_updates]
        )
        cursor.execute("COMMIT")
    except Exception:
        cursor.execute("ROLLBACK")
        raise

# ❌ Bad: Individual operations
# for user in users:
#     update_user(conn, user['id'], user['status'])
```

### Caching Patterns
```python
from functools import lru_cache
from typing import Optional
import redis

# In-memory caching
@lru_cache(maxsize=128)
def get_config(key: str) -> Optional[str]:
    """Get configuration value with caching."""
    # Expensive operation
    return load_config_from_file(key)

# Redis caching
class CachedDataManager:
    def __init__(self, redis_url: str):
        self.redis = redis.from_url(redis_url)
        self.cache_ttl = 3600  # 1 hour
    
    def get_data(self, key: str) -> Optional[Dict]:
        """Get data with Redis caching."""
        # Try cache first
        cached = self.redis.get(key)
        if cached:
            return json.loads(cached)
        
        # Fetch from source
        data = self._fetch_from_source(key)
        
        # Cache result
        if data:
            self.redis.setex(
                key,
                self.cache_ttl,
                json.dumps(data)
            )
        
        return data
```

## Monitoring & Observability

### Structured Logging
```python
import logging
import json

class JSONFormatter(logging.Formatter):
    """Format logs as JSON for structured logging."""
    
    def format(self, record):
        log_data = {
            'timestamp': self.formatTime(record),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno,
        }
        
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_data)

# Configure logger
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

### Prometheus Metrics
```python
from prometheus_client import Counter, Histogram, Gauge

# Define metrics
request_count = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

active_connections = Gauge(
    'active_connections',
    'Number of active connections'
)

# Use metrics
@request_duration.time()
def handle_request(method: str, endpoint: str):
    """Handle HTTP request with metrics."""
    try:
        # Process request
        result = process_request()
        request_count.labels(method, endpoint, '200').inc()
        return result
    except Exception:
        request_count.labels(method, endpoint, '500').inc()
        raise
```

## Response Format Preferences

### Code Comments
- Explain **WHY**, not **WHAT**
- Document assumptions and limitations
- Reference relevant documentation
- Note performance considerations
- Explain security decisions

### Function Documentation
- Clear description of purpose
- Parameter types and descriptions
- Return type and description
- Exceptions that may be raised
- Usage examples when helpful

### Error Messages
- Be specific and actionable
- Include context for debugging
- Suggest solutions when possible
- Log appropriate details
- Never expose sensitive information

## Home Lab Specific Considerations

### Resource Efficiency
```python
# Use generators for large datasets
def process_large_file(filepath: Path):
    """Process large file efficiently with generator."""
    with filepath.open() as f:
        for line in f:
            yield process_line(line)

# Implement connection pooling
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    'postgresql://user:pass@localhost/db',
    poolclass=QueuePool,
    pool_size=5,  # Limit for home lab
    max_overflow=2,
    pool_pre_ping=True
)
```

### Power Management
```bash
# Include power-aware scheduling in cron jobs
# Run heavy tasks during off-peak hours
0 2 * * * /usr/local/bin/backup-script.sh
0 3 * * 0 /usr/local/bin/weekly-maintenance.sh
```

### Cost Optimization
```python
# Implement auto-shutdown for dev environments
import boto3
from datetime import datetime, time

def auto_shutdown_dev_instances():
    """Shutdown dev instances outside business hours."""
    ec2 = boto3.client('ec2')
    
    now = datetime.now().time()
    business_hours = time(8, 0) <= now <= time(18, 0)
    
    if not business_hours:
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Environment', 'Values': ['dev']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                ec2.stop_instances(InstanceIds=[instance['InstanceId']])
```

## Always Remember

1. **Security**: Never commit secrets, always validate input, use least privilege
2. **Reliability**: Implement retries, circuit breakers, graceful degradation
3. **Observability**: Log everything, expose metrics, implement tracing
4. **Performance**: Cache aggressively, batch operations, use async where appropriate
5. **Maintainability**: Write clear code, document decisions, follow conventions
6. **Testing**: Test edge cases, mock external dependencies, aim for high coverage
7. **Resources**: Be mindful of CPU, memory, network, storage constraints

## Questions to Ask Before Generating Code

1. What is the deployment environment? (dev/staging/prod)
2. What are the scale requirements?
3. Are there specific performance constraints?
4. What monitoring/observability is needed?
5. Are there compliance or security requirements?
6. What is the expected failure mode?
7. How will this be tested?
8. What are the resource constraints?