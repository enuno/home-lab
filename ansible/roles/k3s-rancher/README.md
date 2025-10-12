# Rancher Deployment for K3s

This Ansible role deploys Rancher, a multi-cluster Kubernetes management platform, to a K3s cluster using Helm.

## Overview

Rancher is a complete software stack for teams adopting containers. It addresses the operational and security challenges of managing multiple Kubernetes clusters while providing DevOps teams with integrated tools for running containerized workloads.

## Features

- **Multi-Cluster Management**: Manage multiple Kubernetes clusters from a single UI
- **Helm Integration**: Deploy Rancher using Helm charts
- **Certificate Management**: Automated TLS certificate management with cert-manager
- **High Availability**: Support for multiple replicas and pod anti-affinity
- **Authentication**: Built-in and external authentication options (LDAP, SAML, OAuth)
- **RBAC**: Fine-grained role-based access control
- **Monitoring**: Integrated Prometheus and Grafana monitoring
- **Catalog**: Application catalog for easy deployment of Helm charts
- **GitOps**: Continuous delivery with Fleet

## Requirements

### Kubernetes Cluster
- K3s cluster running and accessible
- Helm 3.x installed on K3s master
- Ingress controller (nginx, traefik, etc.)
- Available storage class for cert-manager

**⚠️ IMPORTANT - K3s Version Compatibility:**
This deployment uses `--disable-openapi-validation` to bypass Helm's kubeVersion check for K3s 1.34.x. While Rancher 2.12.2 is documented to support K3s 1.34, the Helm chart constraints haven't been updated yet. This is a temporary workaround and should work correctly, but be aware:
- Rancher 2.12.2 is officially supported on K3s 1.34.x per SUSE support matrix
- The Helm chart will be updated to reflect this support in a future release
- For maximum compatibility, consider using K3s 1.33.x until the chart is updated

### Ansible
- Ansible 2.14 or higher
- Access to K3s master node(s)
- kubectl configured on master nodes

### Network
- DNS name or IP address for Rancher access
- Firewall rules allowing HTTPS (443)
- For Let's Encrypt: public DNS record required

## Installation

### 1. Configure Variables

Edit `group_vars/rancher.yml` to customize your deployment:

```yaml
# Essential settings
rancher_hostname: "rancher.lab.hashgrid.net"
rancher_bootstrap_password: "{{ vault_rancher_bootstrap_password }}"
rancher_replicas: 3

# TLS configuration
rancher_ingress_tls_source: "rancher"  # rancher, letsEncrypt, or secret

# Cert-manager
rancher_install_cert_manager: true
```

### 2. Set Bootstrap Password

Edit `group_vars/rancher_vault.yml` and set a secure password:

```yaml
vault_rancher_bootstrap_password: "YourSecurePasswordHere"
```

Then encrypt the vault file:

```bash
ansible-vault encrypt group_vars/rancher_vault.yml
```

### 3. Deploy Rancher

Run the deployment script:

```bash
cd ansible
./deploy-rancher.sh
```

Or run the playbook directly:

```bash
# With vault encryption
ansible-playbook -i inventory/production playbooks/rancher-deploy.yml --ask-vault-pass

# Without vault encryption (testing only)
ansible-playbook -i inventory/production playbooks/rancher-deploy.yml
```

### 4. Configure DNS

Add a DNS record or /etc/hosts entry pointing to your ingress controller IP:

```bash
# Find ingress IP
kubectl get svc -n kube-system | grep ingress

# Add to /etc/hosts or DNS
10.2.0.100  rancher.lab.hashgrid.net
```

### 5. Access Rancher

1. Navigate to: `https://rancher.lab.hashgrid.net`
2. Accept the self-signed certificate warning (if using rancher-generated certs)
3. Login with username `admin` and your bootstrap password
4. Set a new secure password when prompted

## Configuration

### Variables Reference

#### Basic Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `rancher_namespace` | `cattle-system` | Kubernetes namespace |
| `rancher_chart_version` | `2.10.2` | Rancher Helm chart version |
| `rancher_hostname` | `rancher.homelab.local` | Hostname for Rancher UI |
| `rancher_bootstrap_password` | `admin` | Initial admin password (set in vault) |
| `rancher_replicas` | `3` | Number of Rancher pod replicas |

#### TLS/Certificate Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `rancher_ingress_tls_source` | `rancher` | TLS cert source: rancher, letsEncrypt, secret |
| `rancher_letsencrypt_email` | `""` | Email for Let's Encrypt notifications |
| `rancher_letsencrypt_environment` | `production` | Let's Encrypt environment |

#### Cert-Manager Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `rancher_install_cert_manager` | `true` | Install cert-manager automatically |
| `rancher_cert_manager_version` | `v1.16.2` | Cert-manager version |

#### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `rancher_resources_requests_cpu` | `100m` | CPU request |
| `rancher_resources_requests_memory` | `256Mi` | Memory request |
| `rancher_resources_limits_cpu` | `1000m` | CPU limit |
| `rancher_resources_limits_memory` | `2Gi` | Memory limit |

### TLS Certificate Options

#### 1. Rancher-Generated Certificates (Default)

Best for: Homelab, development environments

```yaml
rancher_ingress_tls_source: "rancher"
```

- Rancher generates self-signed certificates
- Browser will show security warning
- No external dependencies

#### 2. Let's Encrypt

Best for: Production with public DNS

```yaml
rancher_ingress_tls_source: "letsEncrypt"
rancher_letsencrypt_email: "admin@example.com"
rancher_letsencrypt_environment: "production"  # or "staging" for testing
```

Requirements:
- Public DNS record pointing to ingress
- Port 80 accessible from internet
- Valid email address

#### 3. Bring Your Own Certificate

Best for: Enterprise with existing PKI

```yaml
rancher_ingress_tls_source: "secret"
rancher_tls_secret_name: "tls-rancher-ingress"
```

Create TLS secret before deployment:
```bash
kubectl create secret tls tls-rancher-ingress \
  --cert=tls.crt \
  --key=tls.key \
  -n cattle-system
```

## Usage

### Access Rancher UI

1. Navigate to: `https://<rancher_hostname>`
2. Login with admin credentials
3. Set new password on first login

### Import Local K3s Cluster

1. Click **Import Existing** in Rancher UI
2. Select **Generic Kubernetes**
3. Name your cluster (e.g., "homelab-k3s")
4. Copy the `kubectl apply` command
5. Run on your K3s master:
   ```bash
   kubectl apply -f <rancher-generated-url>
   ```
6. Wait for cluster to appear as "Active" in Rancher

### Create New Downstream Clusters

Rancher can provision new clusters on:
- Cloud providers (AWS, GCP, Azure, DigitalOcean)
- vSphere
- Custom nodes (bring your own infrastructure)

### Deploy Applications

1. Select your cluster in Rancher UI
2. Click **Apps & Marketplace**
3. Browse catalog and deploy Helm charts
4. Or use **kubectl** shell in UI

### Manage Access Control

1. Go to **Users & Authentication**
2. Configure authentication provider (Local, LDAP, SAML, OAuth)
3. Create users and assign roles
4. Set up global and cluster-level permissions

## Management Commands

### View Rancher Resources

```bash
# All resources in cattle-system namespace
kubectl get all -n cattle-system

# Rancher pods
kubectl get pods -n cattle-system -l app=rancher

# Rancher ingress
kubectl get ingress -n cattle-system
```

### View Logs

```bash
# Follow Rancher logs
kubectl logs -n cattle-system -l app=rancher -f

# Cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f
```

### Restart Rancher

```bash
kubectl rollout restart deployment/rancher -n cattle-system
```

### Check Certificate Status

```bash
# View certificates
kubectl get certificates -n cattle-system

# Certificate details
kubectl describe certificate rancher -n cattle-system
```

### Access Rancher Shell

```bash
kubectl exec -it -n cattle-system deployment/rancher -- /bin/bash
```

### Update Rancher

Update version in `group_vars/rancher.yml`:
```yaml
rancher_chart_version: "2.10.3"
```

Redeploy:
```bash
./deploy-rancher.sh
```

## Monitoring

### Check Rancher Health

```bash
# Pod status
kubectl get pods -n cattle-system

# Resource usage
kubectl top pods -n cattle-system

# Events
kubectl get events -n cattle-system --sort-by='.lastTimestamp'
```

### Enable Rancher Monitoring

1. In Rancher UI, go to **Cluster Tools**
2. Install **Monitoring**
3. Configure Prometheus and Grafana
4. Access Grafana dashboards

## Troubleshooting

### Rancher Pods Not Starting

Check pod status and events:
```bash
kubectl describe pod -n cattle-system -l app=rancher
kubectl logs -n cattle-system -l app=rancher
```

Common issues:
- Insufficient resources (increase limits)
- Image pull errors (check network/registry)
- Cert-manager not ready (verify cert-manager pods)

### Can't Access Rancher UI

Check ingress configuration:
```bash
kubectl get ingress -n cattle-system -o yaml
kubectl get svc -n kube-system | grep ingress
```

Verify:
- DNS/hosts entry points to ingress IP
- Ingress controller is running
- Firewall allows port 443
- Certificate is ready: `kubectl get certificates -n cattle-system`

### Certificate Issues

View certificate status:
```bash
kubectl get certificates -n cattle-system
kubectl describe certificate rancher -n cattle-system
kubectl get certificaterequest -n cattle-system
```

For Let's Encrypt issues:
- Check cert-manager logs
- Verify DNS record is public
- Ensure port 80 is accessible
- Try staging environment first

### Login Issues

Reset admin password:
```bash
kubectl exec -n cattle-system deployment/rancher -- reset-password
```

Or delete Rancher secret to trigger new bootstrap:
```bash
kubectl delete secret rancher-bootstrap-secret -n cattle-system
kubectl rollout restart deployment/rancher -n cattle-system
```

### High Memory Usage

Adjust resource limits:
```yaml
rancher_resources_limits_memory: "4Gi"
```

Or reduce replicas for resource-constrained environments:
```yaml
rancher_replicas: 1
```

## Security Considerations

### Authentication

- Change bootstrap password immediately
- Use strong, unique passwords
- Enable external authentication (LDAP, SAML, OAuth)
- Implement MFA if available

### Network Security

- Use HTTPS only (enforced by default)
- Restrict access to Rancher UI (firewall, VPN)
- Configure network policies
- Use private ingress for internal-only access

### RBAC

- Follow principle of least privilege
- Create role-based permissions
- Audit user access regularly
- Use project-level isolation

### Updates

- Pin Helm chart versions in production
- Test updates in staging first
- Review release notes and breaking changes
- Maintain backups before updates

## High Availability

### Rancher HA

For production HA setup:

```yaml
rancher_replicas: 3
rancher_anti_affinity: "required"
```

This ensures:
- 3 Rancher pods running
- Pods spread across different nodes
- Automatic failover if node fails

### Backup and Recovery

Rancher stores data in K3s etcd. Backup strategies:

1. **K3s etcd snapshots** (automated):
   ```yaml
   k3s_etcd_snapshot_schedule: "0 */12 * * *"
   k3s_etcd_snapshot_retention: 5
   ```

2. **Rancher Backup Operator** (recommended):
   - Install from Rancher UI
   - Configure backup schedule
   - Store backups externally (S3, NFS)

3. **Manual backup**:
   ```bash
   kubectl get all -n cattle-system -o yaml > rancher-backup.yaml
   ```

## Performance Tuning

### For Production Workloads

```yaml
rancher_replicas: 3
rancher_resources_requests_cpu: "500m"
rancher_resources_requests_memory: "1Gi"
rancher_resources_limits_cpu: "2000m"
rancher_resources_limits_memory: "4Gi"
```

### For Resource-Constrained Homelab

```yaml
rancher_replicas: 1
rancher_resources_requests_cpu: "100m"
rancher_resources_requests_memory: "256Mi"
rancher_resources_limits_cpu: "500m"
rancher_resources_limits_memory: "1Gi"
```

## Uninstallation

### Remove Rancher

```bash
# Delete Rancher Helm release
helm uninstall rancher -n cattle-system

# Delete namespace
kubectl delete namespace cattle-system

# Remove cert-manager (if no longer needed)
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
```

### Clean Up CRDs

```bash
# List Rancher CRDs
kubectl get crd | grep cattle.io

# Delete Rancher CRDs (careful - removes all resources)
kubectl get crd -o name | grep cattle.io | xargs kubectl delete
```

## Integration Examples

### GitOps with Fleet

Rancher includes Fleet for GitOps:

1. Navigate to **Continuous Delivery** in Rancher UI
2. Create Git repository
3. Define fleet.yaml for deployments
4. Fleet automatically syncs from Git to clusters

### CI/CD Integration

Use Rancher API for automation:

```bash
# Get Rancher API token
API_TOKEN="token-xxxxx:xxxxx"
RANCHER_URL="https://rancher.lab.hashgrid.net"

# Deploy via API
curl -k -X POST "$RANCHER_URL/v3/project/<project-id>/workload" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @deployment.json
```

## References

- [Rancher Documentation](https://ranchermanager.docs.rancher.com/)
- [Rancher GitHub](https://github.com/rancher/rancher)
- [Rancher Dashboard GitHub](https://github.com/rancher/dashboard)
- [Helm Charts](https://github.com/rancher/charts)
- [Community Forums](https://forums.rancher.com/)

## License

MIT

## Author

Home Lab Infrastructure Team

## Support

For issues and questions:
- Check troubleshooting section above
- Review Rancher logs: `kubectl logs -n cattle-system -l app=rancher`
- Consult Rancher documentation: https://ranchermanager.docs.rancher.com/
- Community forums: https://forums.rancher.com/
- GitHub issues: https://github.com/rancher/rancher/issues
