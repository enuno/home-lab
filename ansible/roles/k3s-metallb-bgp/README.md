# K3s MetalLB BGP Role

This Ansible role configures MetalLB with BGP for true anycast load balancing across all cluster nodes, eliminating the need for static routes to specific nodes.

## Problem Solved

**Before**: MetalLB in L2 mode requires static routes pointing to specific worker nodes, limiting high availability and creating single points of failure.

**After**: BGP anycast routing allows traffic to any cluster node, with automatic failover and load distribution.

## Architecture

```
Internet/Router (ASN 65000)
    ↓ BGP Sessions
┌─────────────────────────────────┐
│ K3s Cluster (ASN 65001-65004)  │
│ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ │
│ │Node1│ │Node2│ │Node3│ │Node4│ │
│ │65001│ │65002│ │65003│ │65004│ │
│ └─────┘ └─────┘ └─────┘ └─────┘ │
└─────────────────────────────────┘
    ↓ Anycast IP: 10.41.0.0/16
LoadBalancer Services (Pi-hole, etc.)
```

## Supported Router Types

| Router Type | Template | Configuration Method |
|-------------|----------|---------------------|
| **UniFi UDM Pro** | `unifi-cli-config.j2` | SSH CLI commands |
| **FRR** | `frr-bgp-config.j2` | Configuration file |
| **BIRD** | `bird-bgp-config.j2` | Configuration file |
| **Cisco** | `cisco-bgp-config.j2` | Manual configuration |
| **Juniper** | `juniper-bgp-config.j2` | Manual configuration |

## Configuration Variables

### Required Variables

```yaml
# Router configuration
metallb_bgp_router_ip: "10.2.0.1"  # Your router IP
metallb_bgp_asn: 65000             # Router ASN
metallb_router_type: "unifi"       # Router type

# Cluster configuration
metallb_node_asn_base: 65001       # Starting ASN for cluster nodes
```

### Optional Variables

```yaml
# BGP authentication
metallb_bgp_password: "secure-password"

# IP pool configuration
metallb_bgp_ip_pools:
  - name: "default"
    addresses: ["10.41.0.0/16"]
    auto_assign: true

# Monitoring
metallb_bgp_monitoring_enabled: true
metallb_prometheus_enabled: true
```

## Usage

### 1. Basic Deployment

```bash
# Deploy BGP configuration
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-metallb-bgp.yml
```

### 2. UniFi UDM Pro Configuration

```bash
# SSH to your UDM Pro
ssh admin@10.2.0.1

# Enter configuration mode
configure

# Apply the generated commands
# (Copy from /tmp/metallb-router-config/unifi-cli-commands.txt)

# Commit and save
commit && save

# Verify BGP status
show bgp summary
```

### 3. FRR Configuration

```bash
# Copy configuration file
sudo cp /tmp/metallb-router-config/frr-bgp.conf /etc/frr/frr.conf

# Restart FRR
sudo systemctl restart frr

# Verify BGP status
vtysh -c "show bgp summary"
```

## Generated Configuration Files

The role generates configuration files in `/tmp/metallb-router-config/`:

- `unifi-bgp.json` - UniFi JSON configuration
- `unifi-cli-commands.txt` - UniFi CLI commands
- `frr-bgp.conf` - FRR configuration
- `bird-bgp.conf` - BIRD configuration
- `cisco-bgp.conf` - Cisco configuration
- `juniper-bgp.conf` - Juniper configuration
- `deploy-router-config.sh` - Deployment script

## Monitoring

### BGP Status Verification

```bash
# Check BGP peers
kubectl get bgppeer -n metallb-system

# Check IP address pools
kubectl get ipaddresspool -n metallb-system

# Check BGP advertisements
kubectl get bgpadvertisement -n metallb-system

# Check MetalLB speaker logs
kubectl logs -n metallb-system -l app=metallb -l component=speaker
```

### Prometheus Metrics

If monitoring is enabled, metrics are available at:

- `http://bgp-monitoring.metallb-monitoring.svc.cluster.local:9100/metrics`
- `http://bgp-monitoring.metallb-monitoring.svc.cluster.local:8080/health`

## Troubleshooting

### Common Issues

#### 1. BGP Sessions Not Establishing

**Symptoms**: No BGP peers in `show bgp summary`

**Solutions**:
```bash
# Check router configuration
show bgp neighbors

# Check MetalLB speaker logs
kubectl logs -n metallb-system -l app=metallb -l component=speaker

# Verify network connectivity
ping <cluster-node-ip>
telnet <cluster-node-ip> 179
```

#### 2. Routes Not Advertised

**Symptoms**: BGP sessions up but no routes

**Solutions**:
```bash
# Check IP address pools
kubectl get ipaddresspool -n metallb-system

# Check BGP advertisements
kubectl get bgpadvertisement -n metallb-system

# Verify LoadBalancer services
kubectl get svc -A -o wide | grep LoadBalancer
```

#### 3. Traffic Not Reaching Services

**Symptoms**: BGP routes present but services unreachable

**Solutions**:
```bash
# Check service endpoints
kubectl get endpoints -n <namespace> <service-name>

# Verify pod health
kubectl get pods -n <namespace>

# Check node connectivity
kubectl get nodes -o wide
```

### Router-Specific Troubleshooting

#### UniFi UDM Pro

```bash
# Check BGP configuration
show bgp summary
show bgp neighbors
show bgp ipv4 unicast

# Check routing table
show ip route bgp

# Monitor BGP events
show log | grep BGP
```

#### FRR

```bash
# Check BGP status
vtysh -c "show bgp summary"
vtysh -c "show bgp neighbors"
vtysh -c "show bgp ipv4 unicast"

# Check configuration
vtysh -c "show running-config"

# Monitor logs
tail -f /var/log/frr/bgp.log
```

## Security Considerations

### BGP Authentication

Always use BGP passwords in production:

```yaml
metallb_bgp_password: "your-secure-password"
```

### Network Segmentation

Ensure proper firewall rules:

```bash
# Allow BGP (TCP 179)
iptables -A INPUT -p tcp --dport 179 -j ACCEPT

# Allow cluster node communication
iptables -A INPUT -s 10.2.0.0/16 -j ACCEPT
```

### ASN Usage

Use private ASN ranges:
- **65001-65534**: Private ASNs (RFC 6996)
- **65000**: Common for home lab routers

## Performance Tuning

### BGP Timers

Adjust timers for your network:

```yaml
# Faster convergence (higher CPU usage)
metallb_bgp_hold_time: 30
metallb_bgp_keepalive: 10

# Slower convergence (lower CPU usage)
metallb_bgp_hold_time: 180
metallb_bgp_keepalive: 60
```

### Route Advertisement

Optimize route advertisements:

```yaml
metallb_bgp_advertisements:
  - name: "default"
    ip_address_pools: ["default"]
    aggregationLength: 24  # Summarize routes
    localPref: 100        # Route preference
```

## Migration from L2 Mode

### Step 1: Backup Current Configuration

```bash
# Backup current MetalLB configuration
kubectl get ipaddresspool,l2advertisement -n metallb-system -o yaml > metallb-l2-backup.yaml
```

### Step 2: Deploy BGP Configuration

```bash
# Deploy BGP role
ansible-playbook -i inventory/k3s-cluster.ini playbooks/k3s-metallb-bgp.yml
```

### Step 3: Update Router Configuration

```bash
# Apply router configuration
/tmp/metallb-router-config/deploy-router-config.sh
```

### Step 4: Verify Migration

```bash
# Check BGP sessions
show bgp summary

# Test anycast connectivity
curl http://10.41.0.100  # Pi-hole web interface
nslookup example.com 10.41.0.100  # DNS resolution
```

### Step 5: Cleanup

```bash
# Remove L2 advertisements
kubectl delete l2advertisement -n metallb-system --all

# Update static routes (remove specific node routes)
# Add anycast route: ip route add 10.41.0.0/16 via <router-ip>
```

## Best Practices

### 1. High Availability

- Use odd number of master nodes (3+)
- Distribute workers across availability zones
- Configure BGP graceful restart

### 2. Monitoring

- Enable Prometheus monitoring
- Set up BGP session alerts
- Monitor route advertisement counts

### 3. Security

- Use BGP authentication
- Implement proper firewall rules
- Regular security updates

### 4. Documentation

- Document ASN assignments
- Keep configuration backups
- Maintain runbooks for troubleshooting

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review MetalLB documentation: https://metallb.universe.tf/
3. Check router vendor documentation
4. Open an issue in the project repository

## License

This role is part of the home-lab infrastructure project and follows the same license terms.
