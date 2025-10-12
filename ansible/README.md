# Ansible Automation for Home Lab Infrastructure

This directory contains Ansible playbooks, roles, and configurations for automated deployment and management of home lab infrastructure, with a focus on K3s Kubernetes cluster deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Quick Start](#quick-start)
- [Ansible Vault Setup](#ansible-vault-setup)
- [Running Playbooks](#running-playbooks)
- [Available Playbooks](#available-playbooks)
- [Available Roles](#available-roles)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Post-Deployment](#post-deployment)
- [Best Practices](#best-practices)

## 🎯 Overview

This Ansible automation provides:

- **K3s Kubernetes Cluster**: Automated deployment of production-ready K3s clusters
- **High Availability**: Support for multi-master HA configurations
- **Network Security**: UFW firewall configuration with K3s-specific rules
- **Package Management**: Helm v3.16.3 installation and configuration
- **VPN Integration**: Tailscale mesh VPN with SSH support
- **Load Balancing**: MetalLB for bare-metal LoadBalancer services
- **CNI Configuration**: Calico or Flannel network plugins
- **Ubuntu Baseline**: System hardening and baseline configuration

### Supported Environments

- **OS**: Ubuntu 24.04 LTS, Ubuntu 25.10
- **K3s**: v1.34.1+k3s1 (latest stable)
- **Ansible**: 2.19.3 (ansible-core), 12.1.0 (ansible-community)
- **Python**: 3.11+

## ✅ Prerequisites

### Control Machine (where you run Ansible)

```bash
# Install Ansible
pip install ansible==12.1.0 ansible-core==2.19.3

# Install additional tools
pip install ansible-lint yamllint

# Verify installation
ansible --version
```

### Target Nodes (managed hosts)

- Ubuntu 24.04 LTS or Ubuntu 25.10
- SSH access configured with key authentication
- Sudo privileges for the ansible user
- Python 3 installed
- Minimum resources:
  - **Master nodes**: 2 CPU, 4GB RAM, 20GB disk
  - **Worker nodes**: 2 CPU, 2GB RAM, 20GB disk

### SSH Setup

```bash
# Generate SSH key (if not already done)
ssh-keygen -t ed25519 -C "ansible@homelab"

# Copy key to all nodes
ssh-copy-id ansible@10.2.0.100  # master
ssh-copy-id ansible@10.2.0.101  # worker-01
ssh-copy-id ansible@10.2.0.102  # worker-02
ssh-copy-id ansible@10.2.0.103  # worker-03

# Test connectivity
ssh ansible@10.2.0.100
```

## 📁 Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── .vault_password             # Vault password file (gitignored)
├── .gitignore                  # Git ignore patterns
├── ansible.log                 # Ansible execution log
│
├── inventory/                  # Inventory files
│   └── k3s-cluster.ini        # K3s cluster hosts and groups
│
├── group_vars/                 # Group variables
│   ├── k3s_cluster.yml        # Unencrypted cluster variables
│   ├── k3s_cluster_vault.yml  # Encrypted secrets (Ansible Vault)
│   └── k3s_workers.yml        # Worker-specific variables
│
├── host_vars/                  # Host-specific variables (optional)
│
├── playbooks/                  # Ansible playbooks
│   ├── k3s-cluster.yml        # Main K3s cluster deployment
│   ├── ubuntu-baseline.yml    # Ubuntu baseline configuration
│   └── README-k3s.md          # K3s playbook documentation
│
├── roles/                      # Ansible roles
│   ├── k3s-master/            # K3s master node role
│   ├── k3s-worker/            # K3s worker node role
│   ├── k3s-firewall/          # UFW firewall role
│   ├── k3s-helm/              # Helm installation role
│   └── k3s-tailscale/         # Tailscale VPN role
│
└── kubeconfig/                 # Downloaded kubeconfig files
    └── k3s-homelab-k3s.yaml   # Generated kubeconfig
```

## 🚀 Quick Start

### 1. Configure Inventory

Edit the inventory file with your node IP addresses:

```bash
vim inventory/k3s-cluster.ini
```

```ini
[k3s_masters]
k3s-master-01 ansible_host=10.2.0.100 ansible_user=ansible

[k3s_workers]
k3s-worker-01 ansible_host=10.2.0.101 ansible_user=ansible
k3s-worker-02 ansible_host=10.2.0.102 ansible_user=ansible
k3s-worker-03 ansible_host=10.2.0.103 ansible_user=ansible
```

### 2. Set Up Ansible Vault

Create a vault password file:

```bash
echo "your-secure-vault-password" > .vault_password
chmod 600 .vault_password
```

Create encrypted variables file:

```bash
ansible-vault create group_vars/k3s_cluster_vault.yml
```

Add your secrets:

```yaml
---
# Tailscale Authentication
vault_tailscale_authkey: "tskey-auth-xxxxxxxxxxxxx"

# K3s Cluster Token (optional, auto-generated if not set)
vault_k3s_cluster_token: "your-secure-cluster-token"
```

### 3. Test Connectivity

```bash
# Ping all hosts
ansible -i inventory/k3s-cluster.ini k3s_cluster -m ping

# Check Python version on all hosts
ansible -i inventory/k3s-cluster.ini k3s_cluster -m shell -a "python3 --version"
```

### 4. Run Pre-flight Checks

```bash
# Check what would be changed (dry-run)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --check
```

### 5. Deploy K3s Cluster

```bash
# Full deployment
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml

# With verbose output
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml -v
```

### 6. Access Cluster

```bash
# Kubeconfig is automatically downloaded to kubeconfig/
export KUBECONFIG=$(pwd)/kubeconfig/k3s-homelab-k3s.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

## 🔐 Ansible Vault Setup

Ansible Vault encrypts sensitive data like passwords, API keys, and tokens.

### Creating Vault Password File

```bash
# Create password file (already configured in ansible.cfg)
echo "your-secure-vault-password" > .vault_password
chmod 600 .vault_password
```

**Important**: The `.vault_password` file is already in `.gitignore`. Never commit this file to version control.

### Vault Operations

#### Create New Encrypted File

```bash
ansible-vault create group_vars/k3s_cluster_vault.yml
```

This opens your editor to add encrypted content:

```yaml
---
# Tailscale Authentication
vault_tailscale_authkey: "tskey-auth-xxxxxxxxxxxxx"

# K3s Cluster Secrets
vault_k3s_cluster_token: "your-secure-cluster-token"

# Additional secrets
vault_api_tokens:
  github: "ghp_xxxxxxxxxxxxx"
  docker_hub: "dckr_pat_xxxxxxxxxxxxx"
```

#### Edit Encrypted File

```bash
ansible-vault edit group_vars/k3s_cluster_vault.yml
```

#### View Encrypted File

```bash
# View without decrypting to disk
ansible-vault view group_vars/k3s_cluster_vault.yml
```

#### Encrypt Existing File

```bash
ansible-vault encrypt group_vars/secrets.yml
```

#### Decrypt File

```bash
# Decrypt to plain text (use with caution)
ansible-vault decrypt group_vars/secrets.yml

# Re-encrypt after editing
ansible-vault encrypt group_vars/secrets.yml
```

#### Change Vault Password

```bash
# Rekey encrypted files with new password
ansible-vault rekey group_vars/k3s_cluster_vault.yml

# Update .vault_password file
echo "new-secure-password" > .vault_password
```

### Vault Variables Structure

**Encrypted File**: `group_vars/k3s_cluster_vault.yml`

```yaml
---
# Prefix all vault variables with 'vault_'
vault_tailscale_authkey: "tskey-auth-xxxxxxxxxxxxx"
vault_k3s_cluster_token: "your-secure-cluster-token"
```

**Unencrypted File**: `group_vars/k3s_cluster.yml`

```yaml
---
# K3s Configuration
k3s_version: "v1.34.1+k3s1"
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"

# Reference vault variables using Jinja2
tailscale_authkey: "{{ vault_tailscale_authkey }}"
k3s_cluster_token: "{{ vault_k3s_cluster_token }}"
```

### Vault Best Practices

1. **Strong Passwords**: Use 16+ characters with mixed case, numbers, and symbols
2. **Secure Storage**: Store vault password in a password manager
3. **Environment Separation**: Use separate vault files for dev/staging/prod
4. **Variable Naming**: Prefix vault variables with `vault_` for easy identification
5. **Reference Pattern**: Reference vault vars in unencrypted group_vars
6. **Never Commit**: Never commit `.vault_password` to version control
7. **Regular Rotation**: Rotate vault passwords periodically using `ansible-vault rekey`

## 🎮 Running Playbooks

### K3s Cluster Deployment

#### Basic Deployment

```bash
# Full cluster deployment (masters, workers, firewall, helm, tailscale)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml

# With verbose output (-v, -vv, -vvv, -vvvv for more detail)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml -v

# With extra variables
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  -e "k3s_version=v1.34.1+k3s1"

# Dry-run (check mode)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --check

# Show diffs for changed files
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --diff
```

#### Tag-Based Deployment

Run specific parts of the playbook using tags:

```bash
# Deploy only master nodes
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags master

# Deploy only worker nodes
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags worker

# Configure firewall only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags firewall

# Install Helm only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags helm

# Configure Tailscale only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags tailscale

# Update kubeconfig only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags kubeconfig

# Run preflight checks only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags preflight

# Multiple tags
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --tags "preflight,master,worker"

# Skip specific tags
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --skip-tags "tailscale,helm"
```

#### Host Limiting

Run playbook on specific hosts or groups:

```bash
# Run on specific host
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit k3s-master-01

# Run on specific group
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit k3s_workers

# Run on multiple hosts
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit "k3s-master-01,k3s-worker-01"

# Exclude specific hosts
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit 'all:!k3s-worker-03'
```

#### Advanced Options

```bash
# Step through tasks interactively
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --step

# Start at specific task
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --start-at-task="Install K3s on first master"

# Maximum verbosity for debugging
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml -vvvv

# Show task execution time
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --callback-whitelist profile_tasks

# Run with different user
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --user root --ask-become-pass
```

### Ubuntu Baseline Setup

```bash
# Configure baseline Ubuntu settings on all nodes
ansible-playbook -i inventory/k3s-cluster.ini playbooks/ubuntu-baseline.yml

# With specific tags
ansible-playbook -i inventory/k3s-cluster.ini playbooks/ubuntu-baseline.yml \
  --tags packages,security
```

### Useful Ansible Commands

```bash
# List all hosts
ansible -i inventory/k3s-cluster.ini all --list-hosts

# List all tasks in playbook
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --list-tasks

# List all tags in playbook
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --list-tags

# Check playbook syntax
ansible-playbook playbooks/k3s-cluster.yml --syntax-check

# Gather facts from hosts
ansible -i inventory/k3s-cluster.ini k3s_cluster -m setup
```

## 📚 Available Playbooks

| Playbook | Description | Tags Available |
|----------|-------------|----------------|
| `k3s-cluster.yml` | Full K3s cluster deployment with HA support | `preflight`, `master`, `worker`, `firewall`, `helm`, `tailscale`, `kubeconfig`, `verification` |
| `pihole-deploy.yml` | Pi-hole DNS ad-blocker deployment to K3s with MetalLB | `preflight`, `validation`, `deploy`, `service`, `storage`, `verify` |
| `ubuntu-baseline.yml` | Ubuntu system baseline configuration and hardening | `packages`, `security`, `users`, `sysctl`, `cron` |
| `longhorn-deploy.yml` | Longhorn distributed block storage deployment | `prerequisites`, `install`, `ingress` |

### k3s-cluster.yml

Deploys a production-ready K3s Kubernetes cluster with:

- Multi-master HA support (embedded etcd)
- Worker node deployment and auto-join
- UFW firewall configuration
- Helm v3.16.3 installation
- Tailscale VPN integration
- MetalLB load balancer
- Calico CNI (optional)
- Automatic kubeconfig download

### ubuntu-baseline.yml

Configures Ubuntu nodes with:

- Essential packages installation
- Security hardening
- User and group management
- Sysctl tuning for Kubernetes
- Cron job configuration
- SSH hardening

## 🔧 Available Roles

| Role | Description | Variables |
|------|-------------|-----------|
| `k3s-master` | K3s master node setup | `k3s_version`, `k3s_cluster_cidr`, `k3s_service_cidr`, `k3s_is_first_master` |
| `k3s-worker` | K3s worker node setup | `k3s_version`, `k3s_server_url` |
| `k3s-firewall` | UFW firewall configuration | `k3s_firewall_enabled`, `k3s_firewall_default_policy` |
| `k3s-helm` | Helm package manager | `k3s_helm_version` |
| `k3s-tailscale` | Tailscale VPN client | `tailscale_authkey`, `tailscale_ssh_enabled` |

### Role: k3s-master

Deploys K3s control plane on master nodes.

**Key Features:**
- First master: Cluster initialization with embedded etcd
- Additional masters: HA join to existing cluster
- Automatic token generation and distribution
- CNI configuration (Flannel or Calico)
- MetalLB installation (optional)
- Kubeconfig setup for ansible user

**Variables:**
```yaml
k3s_version: "v1.34.1+k3s1"
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"
k3s_flannel_backend: "vxlan"  # or "none" for Calico
k3s_is_first_master: true
k3s_taint_masters: true
k3s_install_metallb: true
k3s_metallb_ip_pool: "10.41.0.0/16"
```

### Role: k3s-worker

Joins worker nodes to K3s cluster.

**Key Features:**
- Auto-discovery of master node
- Automatic join using node token
- Worker-specific configuration
- Label and taint support

**Variables:**
```yaml
k3s_version: "v1.34.1+k3s1"
k3s_server_url: "https://{{ master_ip }}:6443"
k3s_node_labels: []
k3s_node_taints: []
```

### Role: k3s-firewall

Configures UFW firewall with K3s-specific rules.

**Opens Ports:**
- 22/tcp: SSH
- 6443/tcp: K3s API server
- 10250/tcp: Kubelet metrics
- 8472/udp: Flannel VXLAN
- 2379-2380/tcp: etcd (master only)
- 30000-32767/tcp,udp: NodePort range
- 41641/udp: Tailscale

### Role: k3s-helm

Installs Helm v3 package manager.

**Features:**
- Helm v3.16.3 installation
- Bash completion setup
- Repository configuration

### Role: k3s-tailscale

Installs and configures Tailscale VPN.

**Features:**
- Tailscale client installation
- SSH over Tailscale enabled
- Automatic authentication (uses vault key)

## ⚙️ Configuration

### ansible.cfg

Key configuration options:

```ini
[defaults]
inventory = ./inventory/hosts
host_key_checking = False
remote_user = ansible
private_key_file = ~/.ssh/id_ed25519
vault_password_file = .vault_password
forks = 10
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
callback_whitelist = profile_tasks, timer

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

### Group Variables

**k3s_cluster.yml** - Main cluster configuration:

```yaml
# K3s Version
k3s_version: "v1.34.1+k3s1"

# Network Configuration
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"
k3s_flannel_backend: "vxlan"  # or "none"

# MetalLB Configuration
k3s_install_metallb: true
k3s_metallb_version: "v0.14.8"
k3s_metallb_ip_pool: "10.41.0.0/16"
k3s_metallb_pool_name: "default"

# Helm Configuration
k3s_helm_version: "v3.16.3"

# Master Configuration
k3s_taint_masters: true
k3s_enable_ipv6: false

# Reference vault variables
tailscale_authkey: "{{ vault_tailscale_authkey }}"
```

## 🔍 Troubleshooting

### Vault Issues

**Problem**: Vault decryption failed

```bash
ERROR! Decryption failed (no vault secrets would be found that could decrypt)
```

**Solution**:
```bash
# Verify vault password file exists and contains correct password
cat .vault_password

# Test vault decryption
ansible-vault view group_vars/k3s_cluster_vault.yml

# If password is wrong, edit vault file with correct password
ansible-vault edit group_vars/k3s_cluster_vault.yml
```

### Connection Issues

**Problem**: Cannot connect to hosts

```bash
# Test connectivity
ansible -i inventory/k3s-cluster.ini k3s_cluster -m ping

# Test with specific user
ansible -i inventory/k3s-cluster.ini k3s_cluster -m ping -u ansible

# Verify SSH manually
ssh ansible@10.2.0.100

# Check SSH key
ssh-add -l

# Check inventory file
ansible-inventory -i inventory/k3s-cluster.ini --list
```

### Playbook Syntax Errors

```bash
# Check syntax
ansible-playbook playbooks/k3s-cluster.yml --syntax-check

# List all tasks
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --list-tasks

# List all tags
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --list-tags

# Check for linting issues
ansible-lint playbooks/k3s-cluster.yml
```

### K3s Deployment Issues

**Problem**: etcd token mismatch

```
bootstrap data already found and encrypted with different token
```

**Solution**: This is usually caused by config file changes. The playbook is designed to prevent this by only creating config files on initial installation.

```bash
# If you need to reinstall, clean up first:
ssh ansible@10.2.0.100 "sudo /usr/local/bin/k3s-uninstall.sh && sudo rm -rf /var/lib/rancher/k3s /etc/rancher/k3s"

# Then redeploy
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml
```

**Problem**: Worker nodes not joining

```bash
# Check master is accessible
ssh ansible@10.2.0.101 "curl -k https://10.2.0.100:6443"

# Check firewall
ssh ansible@10.2.0.100 "sudo ufw status"

# Check K3s service on master
ssh ansible@10.2.0.100 "sudo systemctl status k3s"

# Check node token
ssh ansible@10.2.0.100 "sudo cat /var/lib/rancher/k3s/server/node-token"

# Redeploy workers
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags worker
```

### Debugging

```bash
# Maximum verbosity
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml -vvvv

# Step through tasks
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --step

# Start at specific task
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --start-at-task="Install K3s on first master"

# Check gathered facts
ansible -i inventory/k3s-cluster.ini k3s_cluster -m setup | less

# Check logs
tail -f ansible.log
```

## ✅ Post-Deployment

### 1. Access Cluster

```bash
# Kubeconfig is automatically downloaded
export KUBECONFIG=$(pwd)/kubeconfig/k3s-homelab-k3s.yaml

# Verify cluster
kubectl get nodes
kubectl get pods -A
kubectl cluster-info
```

### 2. Verify Components

**K3s Service**:
```bash
ssh ansible@10.2.0.100 "sudo systemctl status k3s"
ssh ansible@10.2.0.100 "sudo journalctl -u k3s -f"
```

**Firewall**:
```bash
ssh ansible@10.2.0.100 "sudo ufw status verbose"
```

**Helm**:
```bash
ssh ansible@10.2.0.100 "helm version"
ssh ansible@10.2.0.100 "helm repo list"
```

**Tailscale**:
```bash
ssh ansible@10.2.0.100 "sudo tailscale status"
ssh ansible@10.2.0.100 "sudo tailscale netcheck"
```

**MetalLB**:
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
```

**Calico** (if enabled):
```bash
kubectl get pods -n calico-system
kubectl get installation -n calico-system
```

### 3. Deploy Test Application

```bash
# Create test deployment
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check LoadBalancer IP
kubectl get svc nginx

# Test access (from within cluster network)
ssh ansible@10.2.0.101 "curl http://<LOADBALANCER_IP>"

# Clean up
kubectl delete deployment nginx
kubectl delete service nginx
```

### 4. Install Additional Tools

**Install kubectl locally** (macOS):
```bash
brew install kubectl

# Or use downloaded kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig/k3s-homelab-k3s.yaml
kubectl get nodes
```

**Install k9s** (Kubernetes CLI UI):
```bash
brew install k9s
k9s
```

**Install Helm** (locally):
```bash
brew install helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## 📖 Best Practices

### 1. Idempotency

- All roles and tasks are designed to be idempotent
- Running playbooks multiple times should not cause issues
- Use `--check` mode to preview changes before applying

### 2. Version Pinning

- Pin all software versions in group_vars
- Test updates in dev environment first
- Document version changes in commits

### 3. Secrets Management

- Never commit unencrypted secrets
- Use Ansible Vault for all sensitive data
- Rotate vault passwords regularly
- Use strong, unique passwords

### 4. Inventory Management

- Keep inventory files in version control
- Use descriptive hostnames
- Document IP address changes
- Use groups for logical organization

### 5. Tagging

- Use tags for selective execution
- Tag related tasks together
- Document available tags
- Use consistent tag naming

### 6. Error Handling

- Use `block`/`rescue`/`always` for error handling
- Set appropriate `changed_when` and `failed_when`
- Use `ignore_errors` sparingly
- Log errors appropriately

### 7. Testing

- Test in development environment first
- Use `--check` mode for dry runs
- Verify manually after automation
- Keep rollback procedures ready

### 8. Documentation

- Document all custom variables
- Keep README files updated
- Comment complex logic
- Maintain runbooks for common tasks

## 🔄 Maintenance

### Update K3s Version

```bash
# Update version in group_vars/k3s_cluster.yml
k3s_version: "v1.35.0+k3s1"

# Run playbook (will update all nodes)
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml

# Or update one node at a time
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit k3s-worker-01
```

### Add New Worker Node

```bash
# Add to inventory
vim inventory/k3s-cluster.ini

# Deploy to new node
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml \
  --limit k3s-worker-04 --tags worker
```

### Remove Node

```bash
# Drain node
kubectl drain k3s-worker-03 --ignore-daemonsets --delete-emptydir-data

# Delete from cluster
kubectl delete node k3s-worker-03

# Uninstall K3s
ssh ansible@10.2.0.103 "sudo /usr/local/bin/k3s-agent-uninstall.sh"
```

### Backup

```bash
# Backup etcd (from master)
ssh ansible@10.2.0.100 "sudo k3s etcd-snapshot save"

# List snapshots
ssh ansible@10.2.0.100 "sudo k3s etcd-snapshot ls"

# Backup kubeconfig
cp kubeconfig/k3s-homelab-k3s.yaml ~/backups/
```

## 📞 Support

- **Documentation**: Check playbooks/README-k3s.md for detailed K3s info
- **Issues**: Review troubleshooting section above
- **Logs**: Check ansible.log for execution details
- **Community**: r/homelab, r/selfhosted, r/kubernetes

---

**Note**: This automation is designed for home lab environments. For production deployments, additional hardening and monitoring should be implemented.
