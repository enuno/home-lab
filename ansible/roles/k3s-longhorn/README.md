# Longhorn Storage Role for K3s

This Ansible role deploys [Longhorn](https://longhorn.io) distributed block storage to a K3s Kubernetes cluster.

## Overview

Longhorn is a cloud-native distributed block storage system for Kubernetes that provides:
- Highly available persistent storage
- Volume snapshots and backups
- Cross-cluster disaster recovery
- Automated backup scheduling
- User-friendly web UI

## Requirements

### System Prerequisites
- K3s cluster already deployed and operational
- Helm 3.x installed on master nodes
- Minimum 10GB free disk space on each node
- Required packages: `open-iscsi`, `nfs-common`, `util-linux`, `curl`
- Required kernel modules: `iscsi_tcp`, `nbd`

### Ansible Prerequisites
- Ansible Core 2.19.3+
- Collections:
  - `kubernetes.core`
  - `community.general`

Install collections:
```bash
ansible-galaxy collection install kubernetes.core community.general
```

## Role Variables

All variables can be overridden in `group_vars/k3s_cluster.yml` or inventory variables.

### Core Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_version` | `v1.7.2` | Longhorn version to install |
| `longhorn_chart_version` | `1.7.2` | Helm chart version |
| `longhorn_namespace` | `longhorn-system` | Kubernetes namespace |
| `longhorn_default_data_path` | `/var/lib/longhorn` | Storage path on each node |
| `longhorn_default_replica_count` | `3` | Number of volume replicas |

### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_default_storage_class` | `true` | Create default StorageClass |
| `longhorn_storage_class_name` | `longhorn` | StorageClass name |
| `longhorn_storage_retain_policy` | `Delete` | Volume retain policy (Delete/Retain) |

### UI Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_ui_enable` | `true` | Enable Longhorn UI |
| `longhorn_ui_service_type` | `ClusterIP` | Service type (ClusterIP/NodePort/LoadBalancer) |

### Ingress Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_ingress_enabled` | `false` | Enable Ingress for UI |
| `longhorn_ingress_host` | `longhorn.example.com` | Ingress hostname |
| `longhorn_ingress_tls_enabled` | `false` | Enable TLS for Ingress |

### Backup Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_backup_target` | `""` | Backup target (S3, NFS, etc.) |
| `longhorn_backup_target_secret` | `""` | Secret for backup credentials |

### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `longhorn_manager_cpu_request` | `100m` | Manager CPU request |
| `longhorn_manager_memory_request` | `128Mi` | Manager memory request |
| `longhorn_driver_cpu_request` | `100m` | Driver CPU request |
| `longhorn_driver_memory_request` | `128Mi` | Driver memory request |

## Role Structure

```
k3s-longhorn/
├── defaults/
│   └── main.yml              # Default variables
├── tasks/
│   ├── main.yml              # Main orchestration
│   ├── prerequisites.yml     # System preparation
│   ├── install.yml           # Longhorn deployment
│   └── ingress.yml           # Optional Ingress setup
├── templates/
│   └── longhorn-values.yaml.j2  # Helm values template
└── README.md                 # This file
```

## Usage

### Standalone Deployment

Use the dedicated playbook:

```bash
cd ansible
ansible-playbook -i inventory/production playbooks/longhorn-deploy.yml
```

### Integrated with K3s Deployment

Add to your K3s cluster playbook:

```yaml
- name: Deploy Longhorn storage
  hosts: k3s_cluster
  become: true
  roles:
    - role: k3s-longhorn
```

### Deploy with Custom Variables

```bash
ansible-playbook -i inventory/production playbooks/longhorn-deploy.yml \
  -e "longhorn_default_replica_count=2" \
  -e "longhorn_ui_service_type=NodePort"
```

### Deploy Only Prerequisites

```bash
ansible-playbook -i inventory/production playbooks/longhorn-deploy.yml \
  --tags prerequisites
```

### Deploy Only Installation

```bash
ansible-playbook -i inventory/production playbooks/longhorn-deploy.yml \
  --tags install
```

## Post-Installation

### Access Longhorn UI

#### Using Port Forward (Default)
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Access at http://localhost:8080
```

#### Using NodePort
Set `longhorn_ui_service_type: NodePort` and access via:
```bash
http://<node-ip>:<node-port>
```

#### Using Ingress
Enable ingress in variables:
```yaml
longhorn_ingress_enabled: true
longhorn_ingress_host: "longhorn.yourdomain.com"
longhorn_ingress_tls_enabled: true
```

### Verify Installation

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system

# Check storage class
kubectl get storageclass

# Check Longhorn nodes
kubectl get nodes.longhorn.io -n longhorn-system
```

### Create a Test Volume

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

```bash
kubectl apply -f test-pvc.yaml
kubectl get pvc
kubectl get pv
```

### Use Longhorn in Deployments

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: nginx
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: test-pvc
```

## Backup Configuration

### S3 Backup Target

1. Create AWS S3 bucket or compatible storage
2. Create Kubernetes secret:

```bash
kubectl create secret generic longhorn-backup-secret \
  -n longhorn-system \
  --from-literal=AWS_ACCESS_KEY_ID=<access-key> \
  --from-literal=AWS_SECRET_ACCESS_KEY=<secret-key>
```

3. Set variables:

```yaml
longhorn_backup_target: "s3://bucket-name@region/path"
longhorn_backup_target_secret: "longhorn-backup-secret"
```

### NFS Backup Target

```yaml
longhorn_backup_target: "nfs://nfs-server:/export/longhorn-backups"
```

## Troubleshooting

### Check Prerequisites

The role includes an environment check script that validates:
- Required packages installed
- Kernel modules loaded
- iSCSI configuration
- Available disk space

View the check results in Ansible output or run manually:

```bash
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/scripts/environment_check.sh | bash
```

### Common Issues

#### Pods Not Starting
```bash
# Check pod logs
kubectl logs -n longhorn-system <pod-name>

# Check events
kubectl get events -n longhorn-system --sort-by='.lastTimestamp'
```

#### Volume Not Attaching
```bash
# Check node status
kubectl get nodes.longhorn.io -n longhorn-system

# Check volume status
kubectl get volumes.longhorn.io -n longhorn-system
```

#### iSCSI Issues
```bash
# Verify iSCSI service
sudo systemctl status iscsid

# Check iSCSI initiator
cat /etc/iscsi/initiatorname.iscsi

# Restart iSCSI
sudo systemctl restart iscsid
```

## Uninstallation

To remove Longhorn:

```bash
# Delete all volumes first
kubectl delete pvc --all -A

# Uninstall Longhorn
helm uninstall longhorn -n longhorn-system

# Delete namespace
kubectl delete namespace longhorn-system

# Clean up data directories on each node (CAUTION: Data loss!)
sudo rm -rf /var/lib/longhorn
```

## References

- [Longhorn Documentation](https://longhorn.io/docs/)
- [Longhorn GitHub](https://github.com/longhorn/longhorn)
- [Helm Chart Repository](https://github.com/longhorn/charts)
- [Best Practices](https://longhorn.io/docs/latest/best-practices/)
- [Troubleshooting Guide](https://longhorn.io/docs/latest/troubleshooting/)

## License

This role follows the same license as the parent Home Lab project.

## Author

Technology Solutions Architect with 20+ years experience in telecommunications and systems engineering.
