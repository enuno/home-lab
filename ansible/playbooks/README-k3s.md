# K3s Cluster Deployment with Ansible

This playbook deploys a production-ready K3s Kubernetes cluster with support for High Availability (HA), automated backups, and customizable configurations.

## Overview

K3s is a lightweight, certified Kubernetes distribution designed for resource-constrained environments, edge computing, and IoT deployments. This playbook automates the complete deployment process.

### Features

- **High Availability**: Multi-master setup with embedded etcd
- **Automated Backups**: Scheduled etcd snapshots
- **Flexible Networking**: Multiple CNI options (Flannel, Calico, Cilium)
- **GPU Support**: Optional GPU worker node configuration
- **Security**: TLS encryption, secrets encryption, RBAC
- **Monitoring Ready**: Metrics server and prometheus integration
- **Production Patterns**: Node taints, labels, resource reservations

## Prerequisites

### Control Node (where Ansible runs)

- Ansible Core 2.19.3+
- Python 3.11+
- kubectl (optional, for verification)

### Target Nodes (K3s cluster nodes)

- **OS**: Ubuntu 20.04+, Debian 11+, RHEL/CentOS 8+, or compatible
- **RAM**: Minimum 1GB (2GB+ recommended for masters)
- **CPU**: 1 core minimum (2+ cores recommended)
- **Disk**: 10GB+ free space
- **Network**: All nodes must communicate on ports 6443, 10250, 2379-2380

### SSH Access

- SSH key authentication configured for all nodes
- Sudo/root privileges on target nodes
- User specified in inventory (default: `ansible`)

## Quick Start

### 1. Install Ansible Collections

```bash
cd /Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible

# Install required collections
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
```

### 2. Configure Inventory

Edit the inventory file with your node information:

```bash
vim inventory/k3s-cluster.ini
```

**Example HA Cluster (3 masters, 3 workers):**

```ini
[k3s_masters]
k3s-master-01 ansible_host=192.168.1.10
k3s-master-02 ansible_host=192.168.1.11
k3s-master-03 ansible_host=192.168.1.12

[k3s_workers]
k3s-worker-01 ansible_host=192.168.1.20
k3s-worker-02 ansible_host=192.168.1.21
k3s-worker-03 ansible_host=192.168.1.22

[k3s_cluster:children]
k3s_masters
k3s_workers
```

**Example Single-Node Cluster (testing):**

```ini
[k3s_masters]
k3s-single ansible_host=192.168.1.100

[k3s_workers]
# Empty - single node runs everything

[k3s_cluster:children]
k3s_masters
```

### 3. Configure Cluster Variables

Edit cluster configuration:

```bash
vim group_vars/k3s_cluster.yml
```

**Key variables to customize:**

```yaml
k3s_cluster_name: "homelab-k3s"
k3s_version: "v1.34.0+k3s1"
k3s_api_endpoint: "192.168.1.10"  # Master IP or LB VIP

# Network configuration
k3s_cluster_cidr: "10.42.0.0/16"
k3s_service_cidr: "10.43.0.0/16"

# Disable built-in components (optional)
k3s_disable_traefik: false
k3s_disable_servicelb: false
```

### 4. Verify Connectivity

Test SSH access to all nodes:

```bash
ansible -i inventory/k3s-cluster.ini k3s_cluster -m ping
```

Expected output:
```
k3s-master-01 | SUCCESS => {"ping": "pong"}
k3s-master-02 | SUCCESS => {"ping": "pong"}
...
```

### 5. Deploy Cluster

Run the playbook:

```bash
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml
```

**With tags (selective deployment):**

```bash
# Only deploy master nodes
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags master

# Only deploy worker nodes
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags worker

# Run pre-flight checks only
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags preflight
```

### 6. Access Cluster

The playbook automatically downloads the kubeconfig:

```bash
export KUBECONFIG=../kubeconfig/k3s-homelab-k3s.yaml
kubectl get nodes
```

Expected output:
```
NAME            STATUS   ROLES                  AGE   VERSION
k3s-master-01   Ready    control-plane,master   5m    v1.34.0+k3s1
k3s-master-02   Ready    control-plane,master   4m    v1.34.0+k3s1
k3s-master-03   Ready    control-plane,master   3m    v1.34.0+k3s1
k3s-worker-01   Ready    worker                 2m    v1.34.0+k3s1
k3s-worker-02   Ready    worker                 2m    v1.34.0+k3s1
k3s-worker-03   Ready    worker                 1m    v1.34.0+k3s1
```

## Architecture

### High Availability Setup

```
┌─────────────────────────────────────────┐
│         Load Balancer (Optional)        │
│         API Endpoint: VIP/DNS           │
└─────────────┬───────────────────────────┘
              │
    ┌─────────┴──────────┐
    │                    │
┌───▼────┐  ┌────────┐  ┌────────┐
│Master 1│  │Master 2│  │Master 3│
│ (etcd) │  │ (etcd) │  │ (etcd) │
└───┬────┘  └───┬────┘  └───┬────┘
    │           │           │
    └───────┬───┴───┬───────┘
            │       │
      ┌─────▼───────▼─────┐
      │                   │
  ┌───▼────┐  ┌────────┐  ┌────────┐
  │Worker 1│  │Worker 2│  │Worker 3│
  └────────┘  └────────┘  └────────┘
```

### Network Ports

| Port(s)      | Protocol | Purpose                    | Direction      |
|--------------|----------|----------------------------|----------------|
| 6443         | TCP      | Kubernetes API             | All → Masters  |
| 10250        | TCP      | Kubelet metrics            | All → All      |
| 2379-2380    | TCP      | etcd client/peer           | Masters ↔ Masters |
| 8472         | UDP      | Flannel VXLAN              | All ↔ All      |
| 51820        | UDP      | Flannel WireGuard (opt)    | All ↔ All      |

## Configuration Guide

### Cluster Sizing

#### Development/Testing
- **Masters**: 1
- **Workers**: 0-2
- **RAM**: 2GB+ per master
- **CPU**: 1+ core per node

#### Small Production (High Availability)
- **Masters**: 3
- **Workers**: 3-5
- **RAM**: 4GB+ per master, 2GB+ per worker
- **CPU**: 2+ cores per master, 1+ core per worker

#### Large Production
- **Masters**: 3-5
- **Workers**: 10+
- **RAM**: 8GB+ per master, 4GB+ per worker
- **CPU**: 4+ cores per master, 2+ cores per worker

### Network Configuration

#### Custom Pod/Service CIDR

```yaml
# group_vars/k3s_cluster.yml
k3s_cluster_cidr: "10.42.0.0/16"  # Pod network
k3s_service_cidr: "10.43.0.0/16"  # Service network
```

#### CNI Options

**Flannel (Default)**
```yaml
k3s_flannel_backend: "vxlan"  # Options: vxlan, host-gw, wireguard-native
```

**Custom CNI (Calico, Cilium)**
```yaml
k3s_flannel_backend: "none"
# Deploy custom CNI after cluster creation
```

### Disable Built-in Components

Replace with custom components:

```yaml
k3s_disable_traefik: true        # Use Nginx Ingress
k3s_disable_servicelb: true      # Use MetalLB
k3s_disable_metrics_server: false  # Keep for HPA
```

### External Database (Alternative to Embedded etcd)

For very large clusters or specific requirements:

```yaml
k3s_datastore_endpoint: "postgres://user:pass@db-host:5432/k3s"
# Supported: PostgreSQL, MySQL, MariaDB
```

### Node Labels and Taints

**Label nodes for workload placement:**

```yaml
k3s_node_labels:
  environment: "production"
  zone: "us-east-1a"
  storage: "ssd"
```

**Taint nodes to control scheduling:**

```yaml
k3s_node_taints:
  - "dedicated=gpu:NoSchedule"
  - "experimental=true:NoExecute"
```

### Automated Backups

```yaml
k3s_etcd_snapshot_schedule: "0 */6 * * *"  # Every 6 hours
k3s_etcd_snapshot_retention: 10            # Keep 10 snapshots
k3s_etcd_snapshot_dir: "/backup/k3s-snapshots"
```

**Restore from backup:**

```bash
# On master node
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/snapshot-file
```

### Security Configuration

**Enable secrets encryption:**

```yaml
k3s_secrets_encryption: true
```

**Custom API server arguments:**

```yaml
k3s_kube_apiserver_args:
  - "enable-admission-plugins=NodeRestriction,PodSecurityPolicy"
  - "audit-log-path=/var/log/kubernetes/audit.log"
  - "audit-log-maxage=30"
```

## Advanced Scenarios

### GPU Worker Nodes

1. **Create GPU inventory group:**

```ini
[k3s_gpu_workers]
k3s-gpu-01 ansible_host=192.168.1.30

[k3s_cluster:children]
k3s_masters
k3s_workers
k3s_gpu_workers
```

2. **Configure GPU labels/taints:**

```yaml
# host_vars/k3s-gpu-01.yml
k3s_worker_labels:
  nvidia.com/gpu: "true"
  gpu-type: "tesla-t4"

k3s_worker_taints:
  - "nvidia.com/gpu=true:NoSchedule"
```

3. **Install NVIDIA device plugin after deployment:**

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml
```

### Storage Nodes (Rook/Ceph)

```yaml
# host_vars/k3s-storage-*.yml
k3s_worker_labels:
  storage-node: "true"
  ceph-osd: "enabled"

# Larger kubelet max-pods for storage workloads
k3s_kubelet_args:
  - "max-pods=250"
```

### Multi-Region Clusters

Use latency-aware node labels:

```yaml
k3s_node_labels:
  topology.kubernetes.io/region: "us-east"
  topology.kubernetes.io/zone: "us-east-1a"
```

## Maintenance Operations

### Upgrade K3s Version

1. Update version in `group_vars/k3s_cluster.yml`:

```yaml
k3s_version: "v1.35.0+k3s1"
```

2. Run playbook (upgrades one master at a time):

```bash
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml
```

### Add Worker Nodes

1. Add to inventory:

```ini
[k3s_workers]
# ... existing workers ...
k3s-worker-04 ansible_host=192.168.1.24
```

2. Run playbook with worker tag:

```bash
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-cluster.yml --tags worker --limit k3s-worker-04
```

### Remove Worker Node

1. Drain node:

```bash
kubectl drain k3s-worker-04 --ignore-daemonsets --delete-emptydir-data
kubectl delete node k3s-worker-04
```

2. On worker node:

```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### Cluster Reset (Uninstall)

**Masters:**
```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

**Workers:**
```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

## Troubleshooting

### Nodes Not Ready

**Check K3s service:**
```bash
sudo systemctl status k3s         # Master
sudo systemctl status k3s-agent   # Worker
sudo journalctl -u k3s -f
```

**Check node logs:**
```bash
kubectl describe node <node-name>
kubectl get events --all-namespaces
```

### Network Issues

**Verify connectivity:**
```bash
# From worker, test master API
curl -k https://<master-ip>:6443

# Check CNI pods
kubectl get pods -n kube-system -l k8s-app=flannel
```

**Restart Flannel:**
```bash
kubectl rollout restart daemonset/kube-flannel-ds -n kube-system
```

### etcd Cluster Health

```bash
# On master node
sudo k3s kubectl get endpoints -n kube-system
sudo k3s etcd-snapshot ls
```

### Common Error: Token Mismatch

If nodes fail to join, regenerate token:

```bash
# On first master
sudo cat /var/lib/rancher/k3s/server/node-token

# Update group_vars/k3s_cluster.yml
k3s_cluster_token: "<new-token>"

# Re-run playbook
```

## Monitoring and Observability

### Built-in Metrics Server

```bash
kubectl top nodes
kubectl top pods -A
```

### Deploy Prometheus Stack (Optional)

```bash
# After cluster is ready
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/setup/
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/kube-prometheus/main/manifests/
```

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 (admin/admin)
```

## Security Best Practices

1. **Use private networks** for cluster nodes
2. **Enable firewall rules** to restrict access
3. **Rotate cluster token** periodically
4. **Enable secrets encryption** for sensitive data
5. **Use RBAC** for access control
6. **Regular backups** of etcd snapshots
7. **Update K3s regularly** for security patches
8. **Network policies** to restrict pod communication
9. **TLS everywhere** - verify certificate SANs
10. **Audit logging** for compliance requirements

## Performance Tuning

### High-Performance Networking

```yaml
k3s_flannel_backend: "host-gw"  # Faster than VXLAN, requires L2 adjacency
```

### Large Clusters

```yaml
k3s_kube_apiserver_args:
  - "max-requests-inflight=800"
  - "max-mutating-requests-inflight=400"

k3s_kubelet_args:
  - "max-pods=250"
  - "serialize-image-pulls=false"
```

## References

- **K3s Documentation**: https://docs.k3s.io
- **K3s GitHub**: https://github.com/k3s-io/k3s
- **Ansible Documentation**: https://docs.ansible.com
- **Kubernetes Documentation**: https://kubernetes.io/docs

## Support

For issues with this playbook:
1. Check the troubleshooting section
2. Review Ansible logs: `cat ansible.log`
3. Verify prerequisites are met
4. Consult K3s documentation

## License

MIT - This is open-source software for home lab and educational purposes.

---

**Project**: Home Lab Infrastructure
**Component**: K3s Cluster Deployment
**Maintainer**: Technology Solutions Architect
**Last Updated**: 2025-10-09
