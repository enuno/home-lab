# Pi-hole Quick Start Guide

This guide will help you quickly deploy Pi-hole to your K3s cluster.

## Prerequisites Checklist

- ✅ K3s cluster is running
- ✅ MetalLB is installed and configured
- ✅ Longhorn storage is available (or another storage class)
- ✅ Ansible is installed on your control machine
- ✅ kubectl access to K3s cluster

## Quick Deployment (5 Minutes)

### Step 1: Set Admin Password

Edit the vault file:
```bash
cd /Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible
vim group_vars/pihole_vault.yml
```

Change the password:
```yaml
vault_pihole_admin_password: "YourSecurePassword123!"
```

Encrypt the vault:
```bash
ansible-vault encrypt group_vars/pihole_vault.yml
# Enter a vault password when prompted
```

### Step 2: Customize Configuration (Optional)

Edit `group_vars/pihole.yml` to customize:
```bash
vim group_vars/pihole.yml
```

Key settings to review:
- `pihole_timezone`: Set your timezone
- `pihole_dns_servers`: Choose upstream DNS servers
- `pihole_custom_dns_records`: Add local DNS records
- `pihole_loadbalancer_ip`: Set specific IP (optional)

### Step 3: Deploy Pi-hole

Run the playbook:
```bash
ansible-playbook -i inventory/k3s-cluster.ini playbooks/pihole-deploy.yml --ask-vault-pass
```

Or simply (since ansible.cfg already specifies the inventory):
```bash
ansible-playbook playbooks/pihole-deploy.yml --ask-vault-pass
```

Enter your vault password when prompted.

### Step 4: Get Access Information

After deployment completes, the playbook will display:
- DNS Server IP
- Web Interface URL
- Admin Password

Example output:
```
DNS Server IP: 10.41.0.53
Web Interface: http://10.41.0.53/admin
Admin Password: YourSecurePassword123!
```

### Step 5: Configure Your Network

**Option A: Router-wide (Recommended)**
1. Log into your router
2. Navigate to DHCP/DNS settings
3. Set Primary DNS to Pi-hole IP (e.g., 10.41.0.53)
4. Save and reboot router

**Option B: Individual Device**
Set DNS manually on your device to Pi-hole IP.

### Step 6: Verify It's Working

1. Access web interface: `http://<PIHOLE-IP>/admin`
2. Login with your password
3. Browse the internet on configured devices
4. Check dashboard - you should see queries being processed

## Common Deployment Scenarios

### Scenario 1: Basic Home Network
```yaml
# group_vars/pihole.yml
pihole_dns_servers: "1.1.1.1;1.0.0.1"  # Cloudflare
pihole_storage_size: "5Gi"
pihole_custom_dns_records:
  - domain: "router.home"
    ip: "192.168.1.1"
```

### Scenario 2: Split DNS for Home Lab
```yaml
# group_vars/pihole.yml
pihole_conditional_forwarding: "true"
pihole_conditional_forwarding_domain: "homelab.local"
pihole_conditional_forwarding_target: "10.2.0.100"
pihole_conditional_forwarding_router: "10.2.0.1"

pihole_custom_dns_records:
  - domain: "k3s-master.homelab.local"
    ip: "10.2.0.100"
  - domain: "nas.homelab.local"
    ip: "10.2.0.50"
```

### Scenario 3: Privacy-Focused with DNSSEC
```yaml
# group_vars/pihole.yml
pihole_dns_servers: "9.9.9.9;149.112.112.112"  # Quad9
pihole_dnssec: "true"
pihole_query_logging: "false"
```

## Useful Commands

### Check Deployment Status
```bash
export KUBECONFIG=ansible/kubeconfig/k3s-pihole-access.yaml
kubectl get all -n pihole
kubectl get svc -n pihole
```

### View Logs
```bash
kubectl logs -n pihole -l app=pihole -f
```

### Get LoadBalancer IPs
```bash
kubectl get svc -n pihole -o wide
```

### Restart Pi-hole
```bash
kubectl rollout restart deployment/pihole -n pihole
```

### Access Pi-hole Shell
```bash
kubectl exec -it -n pihole deployment/pihole -- /bin/bash
```

### Update Pi-hole
```bash
# Edit image tag in group_vars/pihole.yml
vim group_vars/pihole.yml

# Redeploy
ansible-playbook playbooks/pihole-deploy.yml --ask-vault-pass
```

## Troubleshooting

### LoadBalancer IP is Pending
```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Check IP pool
kubectl get ipaddresspool -n metallb-system
```

### PVC Not Binding
```bash
# Check storage class
kubectl get storageclass

# Check Longhorn
kubectl get pods -n longhorn-system

# View PVC status
kubectl describe pvc -n pihole
```

### DNS Not Resolving
```bash
# Get DNS IP
DNS_IP=$(kubectl get svc pihole-dns -n pihole -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test DNS
dig @$DNS_IP google.com
nslookup google.com $DNS_IP

# Check firewall
sudo ufw status
```

### Can't Access Web Interface
```bash
# Get web IP
WEB_IP=$(kubectl get svc pihole-web -n pihole -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test connectivity
curl -I http://$WEB_IP/admin

# Check pod logs
kubectl logs -n pihole -l app=pihole | grep lighttpd
```

## Next Steps

1. **Add Blocklists**: Navigate to Group Management → Adlists
   - https://firebog.net/ (recommended lists)

2. **Configure Whitelist**: Add any legitimate domains blocked by Pi-hole

3. **Setup Monitoring**: Integrate with Prometheus/Grafana

4. **Enable HTTPS**: Add ingress with TLS certificate

5. **High Availability**: Deploy second Pi-hole instance

6. **Regular Backups**: Use Longhorn snapshots or Teleporter

## Security Reminders

- ✅ Changed default admin password
- ✅ Encrypted vault file with ansible-vault
- ✅ Limited network access to Pi-hole web interface
- ✅ Regularly update Pi-hole image
- ✅ Monitor query logs for suspicious activity

## Support Resources

- **Role Documentation**: `ansible/roles/k3s-pihole/README.md`
- **Pi-hole Docs**: https://docs.pi-hole.net/
- **Community Forum**: https://discourse.pi-hole.net/
- **GitHub Issues**: https://github.com/pi-hole/pi-hole/issues

## Uninstall

To remove Pi-hole:
```bash
kubectl delete namespace pihole
```

To remove with persistent data:
```bash
kubectl delete pvc -n pihole --all
kubectl delete namespace pihole
```

---

**Happy Ad-Blocking! 🛡️**
