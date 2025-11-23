---
name: "terraform-module-architecture"
description: "Design production-grade Terraform modules for home lab infrastructure with HA patterns, proper structure, variable design, and Proxmox optimization. Use when creating new modules, implementing multi-master Kubernetes clusters, load balancers, or building reusable infrastructure components. Includes module structure, HA implementations, cost optimization, and testing patterns."
allowed-tools: ["Read", "Search", "Edit"]
version: "1.0.0"
author: "Home Lab Infrastructure Team"
---

# Terraform Module Architecture

## When to Use This Skill

Claude automatically applies this skill when you:
- Ask to "create a Terraform module for..."
- Request "design infrastructure for Kubernetes/K3s cluster"
- Need "high availability patterns for..."
- Want "Proxmox VM module with..."
- Design "load balancer/HAProxy/networking infrastructure"
- Optimize "for home lab resource constraints"

## Standard Module Structure

Every Terraform module should follow this structure:

```
terraform/modules/{module-name}/
├── main.tf              # Primary resource definitions
├── variables.tf         # Input variables with validation
├── outputs.tf           # Output values for chaining
├── versions.tf          # Provider version constraints
├── terraform.tfvars     # Example/default values
├── README.md            # Auto-generated documentation
├── examples/
│   └── basic/
│       ├── main.tf      # Usage example
│       └── variables.tf # Example variables
└── tests/
    └── module_test.go   # Terratest or similar
```

## Core Patterns

### Pattern 1: Variable Design with Validation

```hcl
# variables.tf

variable "cluster_name" {
  type        = string
  description = "Name of the infrastructure cluster (lowercase alphanumeric with hyphens)"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,63}$", var.cluster_name))
    error_message = "Cluster name must be 1-63 lowercase alphanumeric characters or hyphens"
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "master_nodes" {
  type = map(object({
    name        = string
    node        = string  # Proxmox node
    cores       = number
    memory      = number  # MB
    disk_size   = number  # GB
    ip_address  = string
  }))
  description = "Master node configurations for HA cluster"

  validation {
    condition     = length(var.master_nodes) >= 3 && length(var.master_nodes) % 2 != 0
    error_message = "Must have odd number of master nodes (3, 5, 7) for quorum"
  }
}

variable "worker_nodes" {
  type = map(object({
    name       = string
    node       = string
    cores      = number
    memory     = number
    disk_size  = number
    ip_address = string
  }))
  description = "Worker node configurations"
  default     = {}
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default = {
    ManagedBy = "Terraform"
    Project   = "HomeLab"
  }
}
```

### Pattern 2: High Availability Implementation

#### Multi-Master Kubernetes Cluster

```hcl
# main.tf

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

locals {
  # Calculate anti-affinity distribution
  proxmox_nodes = distinct([for k, v in var.master_nodes : v.node])
  node_count    = length(local.proxmox_nodes)

  # Merged tags for all resources
  resource_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      Cluster     = var.cluster_name
    }
  )
}

# Master nodes with HA configuration
resource "proxmox_vm_qemu" "k3s_master" {
  for_each = var.master_nodes

  name        = each.value.name
  target_node = each.value.node
  clone       = var.template_name

  # Resource allocation
  cores   = each.value.cores
  memory  = each.value.memory
  sockets = 1

  # Disk configuration
  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "${each.value.disk_size}G"
    ssd     = 1
    cache   = "writeback"
  }

  # Network configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_id
  }

  # Static IP via cloud-init
  ipconfig0 = "ip=${each.value.ip_address}/24,gw=${var.gateway}"

  # Cloud-init configuration
  cicustom  = "user=local:snippets/k3s-master-cloud-init.yml"
  nameserver = var.dns_servers

  # HA features
  hastate = "started"
  hagroup = "${var.cluster_name}-masters"

  # Lifecycle management
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      network,
      disk,
    ]
  }

  # Resource tagging
  tags = join(";", [
    for k, v in merge(local.resource_tags, { Role = "k3s-master" }) :
    "${k}=${v}"
  ])

  # Boot order and startup
  boot       = "order=scsi0"
  onboot     = true
  startup    = "order=1,up=60,down=60"

  # Enable QEMU guest agent
  agent = 1
}

# Worker nodes
resource "proxmox_vm_qemu" "k3s_worker" {
  for_each = var.worker_nodes

  name        = each.value.name
  target_node = each.value.node
  clone       = var.template_name

  cores   = each.value.cores
  memory  = each.value.memory
  sockets = 1

  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "${each.value.disk_size}G"
    ssd     = 1
    cache   = "writeback"
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_id
  }

  ipconfig0 = "ip=${each.value.ip_address}/24,gw=${var.gateway}"

  cicustom  = "user=local:snippets/k3s-worker-cloud-init.yml"
  nameserver = var.dns_servers

  lifecycle {
    create_before_destroy = true
  }

  tags = join(";", [
    for k, v in merge(local.resource_tags, { Role = "k3s-worker" }) :
    "${k}=${v}"
  ])

  boot    = "order=scsi0"
  onboot  = true
  startup = "order=2,up=60,down=60"
  agent   = 1

  # Workers depend on masters being ready
  depends_on = [proxmox_vm_qemu.k3s_master]
}
```

### Pattern 3: Load Balancer with HA

```hcl
# HAProxy load balancer pair for HA
resource "proxmox_vm_qemu" "haproxy" {
  count = 2  # HA pair

  name        = "haproxy-${count.index + 1}"
  target_node = element(local.proxmox_nodes, count.index % local.node_count)
  clone       = var.template_name

  cores  = 2
  memory = 2048

  disk {
    type    = "scsi"
    storage = var.storage_pool
    size    = "20G"
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
    tag    = var.vlan_id
  }

  ipconfig0 = "ip=${var.haproxy_ips[count.index]}/24,gw=${var.gateway}"

  cicustom  = "user=local:snippets/haproxy-cloud-init.yml"
  nameserver = var.dns_servers

  # Enable keepalived for VIP
  hastate = "started"
  hagroup = "${var.cluster_name}-loadbalancers"

  tags = join(";", [
    for k, v in merge(local.resource_tags, { Role = "load-balancer" }) :
    "${k}=${v}"
  ])

  onboot  = true
  startup = "order=0,up=30,down=30"  # Start before cluster
  agent   = 1
}
```

### Pattern 4: Output Design for Module Chaining

```hcl
# outputs.tf

output "master_nodes" {
  description = "Master node details including IPs for cluster bootstrapping"
  value = {
    for k, v in proxmox_vm_qemu.k3s_master : k => {
      id         = v.id
      name       = v.name
      ip_address = v.default_ipv4_address
      node       = v.target_node
    }
  }
}

output "worker_nodes" {
  description = "Worker node details"
  value = {
    for k, v in proxmox_vm_qemu.k3s_worker : k => {
      id         = v.id
      name       = v.name
      ip_address = v.default_ipv4_address
      node       = v.target_node
    }
  }
}

output "master_ips" {
  description = "List of master node IP addresses for etcd clustering"
  value       = [for k, v in proxmox_vm_qemu.k3s_master : v.default_ipv4_address]
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint (via load balancer VIP)"
  value       = var.haproxy_vip
}

output "cluster_config" {
  description = "Cluster configuration for Ansible inventory generation"
  value = {
    cluster_name = var.cluster_name
    environment  = var.environment
    master_ips   = [for k, v in proxmox_vm_qemu.k3s_master : v.default_ipv4_address]
    worker_ips   = [for k, v in proxmox_vm_qemu.k3s_worker : v.default_ipv4_address]
    api_endpoint = var.haproxy_vip
  }

  # Don't expose in console output
  sensitive = false
}

output "ansible_inventory" {
  description = "Generate Ansible inventory format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    master_nodes = proxmox_vm_qemu.k3s_master
    worker_nodes = proxmox_vm_qemu.k3s_worker
    cluster_name = var.cluster_name
  })
}
```

### Pattern 5: Resource Tagging Strategy

```hcl
locals {
  # Common tags for all resources
  common_tags = {
    ManagedBy   = "Terraform"
    Project     = "HomeLab"
    Environment = var.environment
    Cluster     = var.cluster_name
    Owner       = "Infrastructure Team"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  }

  # Service-specific tags
  master_tags = merge(local.common_tags, {
    Role       = "k3s-master"
    Component  = "control-plane"
    CostCenter = "infrastructure"
  })

  worker_tags = merge(local.common_tags, {
    Role       = "k3s-worker"
    Component  = "compute"
    CostCenter = "workloads"
  })
}

# Apply tags consistently
resource "proxmox_vm_qemu" "example" {
  tags = join(";", [for k, v in local.master_tags : "${k}=${v}"])
}
```

## Home Lab Optimizations

### Resource Constraints

```hcl
# Right-size for home lab power/cooling
variable "vm_sizing" {
  type = map(object({
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    small = {
      cores  = 2
      memory = 4096   # 4GB
      disk   = 40
    }
    medium = {
      cores  = 4
      memory = 8192   # 8GB
      disk   = 100
    }
    large = {
      cores  = 8
      memory = 16384  # 16GB
      disk   = 200
    }
  }
}

# Use efficient resource allocation
resource "proxmox_vm_qemu" "node" {
  cores  = var.vm_sizing[var.node_size].cores
  memory = var.vm_sizing[var.node_size].memory

  # Enable memory ballooning for efficient RAM usage
  balloon = 2048

  # CPU limits to prevent resource starvation
  cpu = "host"  # Use host CPU features for efficiency
}
```

### Network Segmentation

```hcl
# VLAN segmentation for security and traffic isolation
variable "vlans" {
  type = map(number)
  default = {
    management = 10
    services   = 20
    storage    = 30
    dmz        = 40
  }
}

resource "proxmox_vm_qemu" "service" {
  network {
    model  = "virtio"
    bridge = "vmbr1"
    tag    = var.vlans[var.service_type]
  }
}
```

### Cost Optimization

```hcl
# Prevent accidental resource deletion
resource "proxmox_vm_qemu" "production" {
  lifecycle {
    prevent_destroy = true
  }
}

# Use count for conditional creation
resource "proxmox_vm_qemu" "optional" {
  count = var.enable_feature ? 1 : 0
  # ... configuration
}

# Efficient storage allocation
disk {
  type     = "scsi"
  storage  = var.storage_pool
  size     = "${var.disk_size}G"
  ssd      = 1
  cache    = "writeback"  # Better performance
  discard  = "on"         # Thin provisioning
}
```

## Testing Patterns

### Validation Tests

```hcl
# Test module with validation
terraform {
  experiments = [module_variable_optional_attrs]
}

# Ensure odd number of masters
variable "master_count" {
  validation {
    condition     = var.master_count >= 3 && var.master_count % 2 != 0
    error_message = "Master count must be odd (3, 5, 7) for quorum"
  }
}

# Ensure valid environment
variable "environment" {
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}
```

### Example Usage

```hcl
# examples/basic/main.tf

module "k3s_cluster" {
  source = "../../"

  cluster_name  = "homelab-k3s"
  environment   = "prod"
  template_name = "ubuntu-22-04-template"
  storage_pool  = "local-lvm"
  network_bridge = "vmbr1"
  vlan_id       = 20

  master_nodes = {
    master1 = {
      name       = "k3s-master-1"
      node       = "proxmox-node-1"
      cores      = 4
      memory     = 8192
      disk_size  = 100
      ip_address = "10.2.0.11"
    }
    master2 = {
      name       = "k3s-master-2"
      node       = "proxmox-node-2"
      cores      = 4
      memory     = 8192
      disk_size  = 100
      ip_address = "10.2.0.12"
    }
    master3 = {
      name       = "k3s-master-3"
      node       = "proxmox-node-1"
      cores      = 4
      memory     = 8192
      disk_size  = 100
      ip_address = "10.2.0.13"
    }
  }

  worker_nodes = {
    worker1 = {
      name       = "k3s-worker-1"
      node       = "proxmox-node-2"
      cores      = 8
      memory     = 16384
      disk_size  = 200
      ip_address = "10.2.0.21"
    }
    worker2 = {
      name       = "k3s-worker-2"
      node       = "proxmox-node-1"
      cores      = 8
      memory     = 16384
      disk_size  = 200
      ip_address = "10.2.0.22"
    }
  }

  haproxy_ips = ["10.2.0.5", "10.2.0.6"]
  haproxy_vip = "10.2.0.10"

  gateway     = "10.2.0.1"
  dns_servers = "10.2.0.1"

  common_tags = {
    Project     = "HomeLab"
    Environment = "prod"
    Team        = "Infrastructure"
  }
}

output "cluster_info" {
  value = {
    master_ips   = module.k3s_cluster.master_ips
    api_endpoint = module.k3s_cluster.cluster_endpoint
  }
}
```

## Documentation Generation

```bash
# Install terraform-docs
brew install terraform-docs

# Generate README.md automatically
terraform-docs markdown table . > README.md

# Or configure in CI/CD
terraform-docs --config .terraform-docs.yml .
```

## Security Best Practices

### Secrets Management

```hcl
# NEVER hardcode secrets
# ❌ BAD
variable "db_password" {
  default = "changeme123"
}

# ✅ GOOD - Use environment variables
variable "db_password" {
  type        = string
  description = "Database password (set via TF_VAR_db_password)"
  sensitive   = true
}

# ✅ GOOD - Use Bitwarden provider
data "bitwarden_item_login" "db" {
  id = var.bitwarden_secret_id
}

resource "kubernetes_secret" "db" {
  data = {
    password = data.bitwarden_item_login.db.password
  }
}
```

### Least Privilege

```hcl
# Minimal resource permissions
resource "proxmox_vm_qemu" "service" {
  # Only necessary resources
  cores  = 2
  memory = 4096

  # Network isolation
  network {
    tag = var.service_vlan  # Isolated VLAN
  }
}
```

## Key Takeaways

1. **Structure**: Follow standard module layout for consistency
2. **Variables**: Use validation to catch errors early
3. **HA**: Always use odd number of masters for quorum
4. **Outputs**: Design for module chaining and Ansible integration
5. **Tags**: Consistent tagging for organization and cost tracking
6. **Optimization**: Right-size for home lab constraints
7. **Security**: Never hardcode secrets, use Bitwarden integration
8. **Testing**: Include validation and example usage
9. **Documentation**: Auto-generate with terraform-docs

This skill provides the foundation for building production-grade Terraform modules optimized for home lab environments.