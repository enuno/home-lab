# Pi-hole Deployment for K3s

This Ansible role deploys Pi-hole DNS server with ad-blocking capabilities to a K3s Kubernetes cluster using MetalLB for load balancing.

## Overview

Pi-hole is a network-wide ad blocker that acts as a DNS sinkhole, protecting your devices from unwanted content without installing client-side software. This deployment leverages Kubernetes for container orchestration and MetalLB for exposing services with LoadBalancer IPs.

## Features

- **Network-wide Ad Blocking**: Block ads and trackers at the DNS level
- **MetalLB Integration**: Automatic LoadBalancer IP assignment
- **Persistent Storage**: Uses Longhorn for data persistence
- **Customizable DNS**: Configure upstream DNS servers and custom records
- **Web Interface**: Full-featured web interface for management
- **Health Checks**: Kubernetes liveness and readiness probes
- **Resource Limits**: Configurable CPU and memory limits
- **DNSSEC Support**: Optional DNSSEC validation
- **Custom Blocklists**: Support for additional blocklist sources

## Requirements

### Kubernetes Cluster
- K3s cluster running and accessible
- MetalLB installed and configured with an IP pool
- Longhorn or another storage class available (if using persistent storage)

### Ansible
- Ansible 2.14 or higher
- Access to K3s master node(s)
- kubectl configured on master nodes

### Network
- Available IP address(es) in MetalLB pool for LoadBalancer services
- Firewall rules allowing DNS (UDP/TCP 53) and HTTP/HTTPS (80/443)

## Installation

### 1. Configure Variables

Edit `group_vars/pihole.yml` to customize your deployment:

```yaml
# Essential settings
pihole_namespace: "pihole"
pihole_timezone: "America/New_York"
pihole_dns_servers: "1.1.1.1;1.0.0.1"

# Storage
pihole_storage_enabled: true
pihole_storage_class: "longhorn"
pihole_storage_size: "10Gi"

# Custom DNS records
pihole_custom_dns_records:
  - domain: "homelab.local"
    ip: "192.168.1.100"
```

### 2. Set Admin Password

Edit `group_vars/pihole_vault.yml` and set a secure password:

```yaml
vault_pihole_admin_password: "YourSecurePasswordHere"
```

Then encrypt the vault file:

```bash
ansible-vault encrypt group_vars/pihole_vault.yml
```

### 3. Deploy Pi-hole

Run the playbook:

```bash
# Without vault encryption
ansible-playbook -i inventory/production playbooks/pihole-deploy.yml

# With vault encryption
ansible-playbook -i inventory/production playbooks/pihole-deploy.yml --ask-vault-pass
```

### 4. Verify Deployment

Check the deployment status:

```bash
export KUBECONFIG=kubeconfig/k3s-pihole-access.yaml
kubectl get all -n pihole
kubectl get svc -n pihole
```

## Configuration

### Variables Reference

#### Basic Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `pihole_namespace` | `pihole` | Kubernetes namespace |
| `pihole_image` | `pihole/pihole` | Container image |
| `pihole_image_tag` | `latest` | Image tag |
| `pihole_timezone` | `America/New_York` | Timezone for logs |
| `pihole_admin_password` | `changeme123` | Admin password (set in vault) |

#### DNS Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `pihole_dns_servers` | `1.1.1.1;1.0.0.1` | Upstream DNS servers |
| `pihole_dnssec` | `true` | Enable DNSSEC |
| `pihole_ipv6` | `true` | Enable IPv6 |
| `pihole_query_logging` | `true` | Enable query logging |

#### Network Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `pihole_service_type` | `LoadBalancer` | Service type |
| `pihole_loadbalancer_ip` | `""` | Specific IP (empty for auto) |
| `pihole_server_ip` | `""` | Server IP (auto-detected if empty) |

#### Storage Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `pihole_storage_enabled` | `true` | Enable persistent storage |
| `pihole_storage_class` | `longhorn` | Storage class name |
| `pihole_storage_size` | `10Gi` | Storage size |

#### Resource Limits

| Variable | Default | Description |
|----------|---------|-------------|
| `pihole_resources_requests_cpu` | `100m` | CPU request |
| `pihole_resources_requests_memory` | `256Mi` | Memory request |
| `pihole_resources_limits_cpu` | `500m` | CPU limit |
| `pihole_resources_limits_memory` | `512Mi` | Memory limit |

### Custom DNS Records

Add custom A records:

```yaml
pihole_custom_dns_records:
  - domain: "router.home.local"
    ip: "192.168.1.1"
  - domain: "nas.home.local"
    ip: "192.168.1.50"
```

Add custom CNAME records:

```yaml
pihole_custom_cname_records:
  - domain: "plex.home.local"
    target: "nas.home.local"
```

### Conditional Forwarding

Forward local domain queries to your router:

```yaml
pihole_conditional_forwarding: "true"
pihole_conditional_forwarding_domain: "home.local"
pihole_conditional_forwarding_target: "192.168.1.1"
pihole_conditional_forwarding_router: "192.168.1.1"
```

## Usage

### Access Web Interface

1. Get the LoadBalancer IP:
```bash
kubectl get svc pihole-web -n pihole
```

2. Access the web interface:
```
http://<LOADBALANCER-IP>/admin
```

3. Login with your admin password

### Configure Devices

#### Router Configuration (Network-Wide)
Configure your router's DHCP settings to use Pi-hole as the DNS server:
- Primary DNS: `<Pi-hole LoadBalancer IP>`
- Secondary DNS: `<Backup DNS or another Pi-hole instance>`

#### Individual Device Configuration
Configure DNS on individual devices:
- **Windows**: Network Settings → Change adapter options → Properties → IPv4 → DNS
- **macOS**: System Preferences → Network → Advanced → DNS
- **Linux**: Edit `/etc/resolv.conf` or use NetworkManager
- **iOS/Android**: WiFi settings → Configure DNS

### Management Commands

View logs:
```bash
kubectl logs -n pihole -l app=pihole -f
```

Restart Pi-hole:
```bash
kubectl rollout restart deployment/pihole -n pihole
```

Access Pi-hole shell:
```bash
kubectl exec -it -n pihole deployment/pihole -- /bin/bash
```

Update Pi-hole:
```bash
# Update image tag in group_vars/pihole.yml, then:
ansible-playbook -i inventory/production playbooks/pihole-deploy.yml --ask-vault-pass
```

View resources:
```bash
kubectl get all -n pihole
kubectl describe deployment pihole -n pihole
```

### Adding Blocklists

1. Access web interface
2. Navigate to **Group Management** → **Adlists**
3. Add blocklist URLs (recommended sources):
   - https://firebog.net/ (curated lists)
   - https://github.com/blocklistproject/Lists

Popular lists:
```
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://mirror1.malwaredomains.com/files/justdomains
https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
```

4. Click **Tools** → **Update Gravity** to apply changes

### Whitelisting Domains

If Pi-hole blocks legitimate domains:

1. Via Web Interface:
   - Go to **Whitelist**
   - Add domain
   - Click **Add to Whitelist**

2. Via Command Line:
```bash
kubectl exec -n pihole deployment/pihole -- pihole -w example.com
```

### Backup and Restore

#### Backup via Web Interface
1. Go to **Settings** → **Teleporter**
2. Click **Backup** to download configuration

#### Backup via kubectl
```bash
# Backup configuration
kubectl exec -n pihole deployment/pihole -- tar czf /tmp/pihole-backup.tar.gz /etc/pihole
kubectl cp pihole/pihole-<pod-name>:/tmp/pihole-backup.tar.gz ./pihole-backup.tar.gz

# Using Longhorn snapshots
kubectl annotate pvc pihole-data -n pihole snapshot.longhorn.io/backup=true
```

#### Restore
1. Upload backup via **Settings** → **Teleporter** → **Restore**
2. Or restore from Longhorn snapshot

## Monitoring

### Query Statistics
View statistics in the web dashboard:
- Total queries
- Queries blocked
- Percentage blocked
- Top domains and clients

### Kubernetes Monitoring
```bash
# Watch pod status
kubectl get pods -n pihole -w

# View events
kubectl get events -n pihole

# Check resource usage
kubectl top pod -n pihole
```

### Integration with Prometheus
Pi-hole exports metrics that can be scraped by Prometheus:
- Add exporter sidecar container
- Configure ServiceMonitor
- Create Grafana dashboards

## Troubleshooting

### Pi-hole Pod Not Starting

Check pod status and events:
```bash
kubectl describe pod -n pihole -l app=pihole
kubectl logs -n pihole -l app=pihole
```

Common issues:
- PVC not bound (check storage class availability)
- Resource limits too low
- Image pull errors

### LoadBalancer IP Pending

Check MetalLB:
```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl logs -n metallb-system -l app=metallb
```

Verify IP pool has available addresses.

### DNS Not Resolving

Test DNS resolution:
```bash
# Get DNS service IP
DNS_IP=$(kubectl get svc pihole-dns -n pihole -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test DNS query
dig @$DNS_IP google.com
nslookup google.com $DNS_IP
```

Check:
- Firewall rules allow UDP/TCP port 53
- Upstream DNS servers are reachable
- Pi-hole service is running

### Web Interface Inaccessible

Check web service:
```bash
kubectl get svc pihole-web -n pihole
kubectl logs -n pihole -l app=pihole | grep lighttpd
```

Verify:
- LoadBalancer IP assigned
- Port 80/443 accessible
- Health checks passing

### High Memory Usage

Adjust resource limits:
```yaml
pihole_resources_limits_memory: "1Gi"
```

Or disable query logging:
```yaml
pihole_query_logging: "false"
```

## Security Considerations

### Password Security
- Never use default password
- Use strong, unique passwords
- Store passwords in encrypted vault
- Rotate passwords regularly

### Network Security
- Restrict access to web interface (firewall rules, authentication proxy)
- Use HTTPS for web interface (add ingress with TLS)
- Limit DNS access to trusted networks
- Monitor query logs for suspicious activity

### Update Strategy
- Pin image versions in production
- Test updates in staging first
- Review changelog before updating
- Maintain backups before updates

## High Availability

For HA DNS resolution:

1. Deploy multiple Pi-hole instances:
```yaml
pihole_replicas: 2  # Use with caution - separate deployments recommended
```

2. Or deploy separate Pi-hole instances in different namespaces/clusters

3. Configure devices with multiple DNS servers:
   - Primary: Pi-hole 1 IP
   - Secondary: Pi-hole 2 IP

## Performance Tuning

### For High Query Volume
```yaml
pihole_resources_requests_cpu: "500m"
pihole_resources_requests_memory: "512Mi"
pihole_resources_limits_cpu: "1000m"
pihole_resources_limits_memory: "1Gi"
```

### For Low-Resource Environments
```yaml
pihole_resources_requests_cpu: "50m"
pihole_resources_requests_memory: "128Mi"
pihole_storage_size: "5Gi"
```

## Uninstallation

Remove Pi-hole deployment:
```bash
kubectl delete namespace pihole
```

Or use Ansible:
```bash
kubectl delete -k ansible/roles/k3s-pihole/templates/
```

To remove persistent data:
```bash
kubectl delete pvc -n pihole --all
```

## References

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Pi-hole Docker](https://github.com/pi-hole/docker-pi-hole)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [K3s Documentation](https://docs.k3s.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)

## License

MIT

## Author

Home Lab Infrastructure Team

## Support

For issues and questions:
- Check troubleshooting section above
- Review Pi-hole logs: `kubectl logs -n pihole -l app=pihole`
- Consult Pi-hole documentation: https://docs.pi-hole.net/
- Check GitHub issues: https://github.com/pi-hole/pi-hole/issues
