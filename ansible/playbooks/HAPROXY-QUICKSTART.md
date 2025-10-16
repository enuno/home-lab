# HAProxy + keepalived High Availability Load Balancer - Quick Start Guide

## Overview

This deployment creates a highly available load balancer using:
- **HAProxy**: Running in Docker containers for easy management and portability
- **keepalived**: Installed via package manager for Virtual IP (VIP) management and failover

## Architecture

```
                    Internet
                        |
                  Virtual IP (VIP)
                 10.2.0.200 (example)
                        |
            +-----------+-----------+
            |                       |
    HAProxy Primary          HAProxy Backup(s)
    (keepalived MASTER)      (keepalived BACKUP)
    10.2.0.110               10.2.0.111, 10.2.0.112
    Priority: 100            Priority: 90, 80
            |                       |
    +-------+-------+-------+-------+-------+
    |               |               |
Web Server 1   Web Server 2   Web Server 3
10.2.0.101     10.2.0.102     10.2.0.103
```

## Features

- **High Availability**: Automatic failover using VRRP protocol
- **Load Balancing**: Distribute traffic across multiple backend servers
- **Health Checks**: Automatic backend server health monitoring
- **Stats Interface**: Real-time monitoring and statistics
- **SSL/TLS Support**: HTTPS termination (optional)
- **Compression**: Automatic content compression
- **Rate Limiting**: DDoS protection (optional)
- **Custom Error Pages**: Branded error responses
- **Security Headers**: Modern security headers

## Prerequisites

### Software Requirements
- Ansible 2.14 or later
- Python 3.8 or later
- SSH access to target servers
- Servers running Ubuntu 20.04+, Debian 11+, or RHEL/CentOS 8+

### Network Requirements
- At least 2 servers for HA (1 primary + 1 backup)
- One available IP address for the Virtual IP (VIP)
- All servers on the same Layer 2 network segment
- Firewall rules allowing:
  - TCP ports 80, 443, 8080 (HAProxy frontends)
  - TCP port 8404 (HAProxy stats)
  - VRRP protocol (IP protocol 112)

### Server Requirements
- Minimum 2 CPU cores
- Minimum 2GB RAM
- Minimum 10GB disk space
- SSH key authentication configured

## Quick Start

### 1. Configure Inventory

Edit `ansible/inventory/haproxy-cluster.ini`:

```ini
[haproxy_primary]
haproxy-lb-01 ansible_host=10.2.0.110 ansible_user=ansible haproxy_keepalived_priority=100

[haproxy_backup]
haproxy-lb-02 ansible_host=10.2.0.111 ansible_user=ansible haproxy_keepalived_priority=90

[haproxy_cluster:children]
haproxy_primary
haproxy_backup

[haproxy_cluster:vars]
haproxy_network_interface=eth0
haproxy_virtual_ip=10.2.0.200
```

**Important:** Replace IP addresses and network interface with your actual values.

### 2. Configure Variables

Edit `ansible/group_vars/haproxy.yml`:

```yaml
# Virtual IP configuration
haproxy_virtual_ip: "10.2.0.200"
haproxy_network_interface: "eth0"
haproxy_virtual_router_id: 51

# Backend servers
haproxy_backend_servers:
  - name: "web1"
    address: "10.2.0.101"
    port: 80
    check: true
  - name: "web2"
    address: "10.2.0.102"
    port: 80
    check: true
```

### 3. Configure Secrets

Edit `ansible/group_vars/haproxy_vault.yml` and encrypt it:

```bash
# Edit the vault file
nano ansible/group_vars/haproxy_vault.yml

# Change default passwords, then encrypt
ansible-vault encrypt ansible/group_vars/haproxy_vault.yml
```

### 4. Test Connectivity

```bash
cd ansible
ansible haproxy_cluster -i inventory/haproxy-cluster.ini -m ping
```

### 5. Deploy

#### Option A: Using the deployment script (recommended)

```bash
cd ansible
./deploy-haproxy.sh --deploy
```

#### Option B: Using ansible-playbook directly

```bash
cd ansible
ansible-playbook -i inventory/haproxy-cluster.ini \
  playbooks/haproxy-keepalived-deploy.yml \
  --ask-vault-pass
```

### 6. Verify Deployment

Check HAProxy stats interface:
```bash
# Access via browser
http://10.2.0.200:8404/stats

# Or via curl
curl -u admin:password http://10.2.0.200:8404/stats
```

Check Virtual IP assignment:
```bash
ssh ansible@10.2.0.110 "ip addr show eth0 | grep 10.2.0.200"
```

Test load balancing:
```bash
curl http://10.2.0.200/
```

## Configuration Guide

### Backend Servers

Add backend servers in `group_vars/haproxy.yml`:

```yaml
haproxy_backend_servers:
  - name: "web1"
    address: "10.2.0.101"
    port: 80
    check: true          # Enable health checks
    backup: false        # Not a backup server
  - name: "web2"
    address: "10.2.0.102"
    port: 80
    check: true
    backup: false
  - name: "web3"
    address: "10.2.0.103"
    port: 80
    check: true
    backup: true         # Backup server (only used if others fail)
```

### Load Balancing Algorithms

Change the algorithm in `group_vars/haproxy.yml`:

```yaml
haproxy_balance_algorithm: "roundrobin"
```

Available algorithms:
- `roundrobin`: Simple round-robin
- `leastconn`: Least connections (best for long-lived connections)
- `source`: Client IP hash (session persistence)
- `uri`: URI hash
- `random`: Random selection

### SSL/TLS Configuration

Enable HTTPS in `group_vars/haproxy.yml`:

```yaml
haproxy_ssl_enabled: true
haproxy_ssl_certificate_path: "/etc/haproxy/certs/cert.pem"
haproxy_ssl_redirect_http: true
```

Copy your certificate to the HAProxy nodes:
```bash
# Certificate should be in PEM format with:
# - Private key
# - Certificate
# - Intermediate certificates (if any)

scp /path/to/cert.pem ansible@10.2.0.110:/etc/haproxy/certs/
```

### Health Check Configuration

Customize health checks in `group_vars/haproxy.yml`:

```yaml
haproxy_health_check_interval: "10s"
haproxy_health_check_timeout: "3s"
haproxy_health_check_rise: 2    # Consecutive successes before up
haproxy_health_check_fall: 3    # Consecutive failures before down
```

### Rate Limiting

Enable rate limiting to protect against DDoS:

```yaml
haproxy_enable_rate_limit: true
haproxy_rate_limit_period: "10s"
haproxy_rate_limit_requests: 100  # Max 100 requests per 10 seconds per IP
```

## Operations Guide

### Viewing Logs

HAProxy logs (Docker):
```bash
ssh ansible@10.2.0.110 "docker logs -f haproxy"
```

keepalived logs:
```bash
ssh ansible@10.2.0.110 "journalctl -u keepalived -f"
```

### Reloading Configuration

After modifying `group_vars/haproxy.yml`, redeploy:
```bash
./deploy-haproxy.sh --tags haproxy
```

Or reload manually:
```bash
ssh ansible@10.2.0.110 "docker restart haproxy"
```

### Testing Failover

1. Stop keepalived on primary:
   ```bash
   ssh ansible@10.2.0.110 "sudo systemctl stop keepalived"
   ```

2. Verify VIP moved to backup:
   ```bash
   ssh ansible@10.2.0.111 "ip addr show eth0 | grep 10.2.0.200"
   ```

3. Test connectivity:
   ```bash
   ping 10.2.0.200
   curl http://10.2.0.200:8404/health
   ```

4. Restore primary:
   ```bash
   ssh ansible@10.2.0.110 "sudo systemctl start keepalived"
   ```

### Checking HAProxy Status

Stats page (browser):
```
http://10.2.0.200:8404/stats
```

Health check endpoint:
```bash
curl http://10.2.0.200:8404/health
```

Backend server status:
```bash
curl -u admin:password http://10.2.0.200:8404/stats
```

### Maintenance Mode

Put a backend server in maintenance:
```bash
# Via stats page, or using socat:
echo "disable server http_back/web1" | \
  ssh ansible@10.2.0.110 "docker exec -i haproxy socat stdio /var/run/haproxy.sock"
```

Bring back online:
```bash
echo "enable server http_back/web1" | \
  ssh ansible@10.2.0.110 "docker exec -i haproxy socat stdio /var/run/haproxy.sock"
```

## Monitoring

### Prometheus Metrics

Enable Prometheus metrics in `group_vars/haproxy.yml`:

```yaml
haproxy_enable_prometheus: true
haproxy_prometheus_port: 9101
```

Access metrics:
```
http://10.2.0.200:9101/metrics
```

### Grafana Dashboards

Import HAProxy dashboard from Grafana:
- Dashboard ID: 12693 (HAProxy 2.x)
- Dashboard ID: 367 (HAProxy Full)

### Key Metrics to Monitor

- **Frontend Requests**: Total requests per second
- **Backend Response Time**: Average response time
- **Server Status**: Up/Down status of backend servers
- **Session Rate**: New sessions per second
- **Error Rate**: 4xx/5xx errors
- **Queue Length**: Requests waiting for backend

## Troubleshooting

### Virtual IP Not Assigned

Check keepalived status:
```bash
ssh ansible@10.2.0.110 "systemctl status keepalived"
```

Check VRRP advertisements:
```bash
ssh ansible@10.2.0.110 "tcpdump -i eth0 vrrp -n"
```

Verify network interface:
```bash
ssh ansible@10.2.0.110 "ip addr show"
```

### HAProxy Container Not Running

Check container status:
```bash
ssh ansible@10.2.0.110 "docker ps -a | grep haproxy"
```

View container logs:
```bash
ssh ansible@10.2.0.110 "docker logs haproxy"
```

Test configuration:
```bash
ssh ansible@10.2.0.110 "docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg"
```

### Backend Servers Down

Check health check configuration in HAProxy stats page.

Test backend server manually:
```bash
curl http://10.2.0.101/
```

Check HAProxy health check:
```bash
ssh ansible@10.2.0.110 "docker exec haproxy curl http://10.2.0.101/"
```

### Split-Brain Scenario

If both nodes think they're MASTER:

1. Check router ID is unique:
   ```bash
   grep virtual_router_id /etc/keepalived/keepalived.conf
   ```

2. Verify network connectivity:
   ```bash
   ping 10.2.0.111  # From primary
   ```

3. Check firewall allows VRRP (IP protocol 112)

4. Restart keepalived on backup nodes first:
   ```bash
   ssh ansible@10.2.0.111 "sudo systemctl restart keepalived"
   ```

## Security Best Practices

1. **Change Default Passwords**: Update stats password and keepalived auth password
2. **Use Ansible Vault**: Encrypt sensitive variables
3. **Restrict Stats Access**: Use firewall rules to limit stats page access
4. **Enable SSL/TLS**: Use HTTPS for all traffic
5. **Security Headers**: Enable custom security headers (already configured)
6. **Rate Limiting**: Enable rate limiting for DDoS protection
7. **Regular Updates**: Keep HAProxy image and keepalived package updated
8. **Network Segmentation**: Place load balancers in DMZ

## Advanced Configuration

### Multiple Virtual IPs

Add additional VIPs in `group_vars/haproxy.yml`:

```yaml
keepalived_additional_vips:
  - address: "10.2.0.201"
    interface: "eth0"
  - address: "10.2.0.202"
    interface: "eth0"
```

### TCP Load Balancing

Add TCP frontend in HAProxy config template:

```haproxy
listen mysql_cluster
    bind *:3306
    mode tcp
    balance leastconn
    option mysql-check user haproxy
    server mysql1 10.2.0.101:3306 check
    server mysql2 10.2.0.102:3306 check backup
```

### Custom Health Checks

Add custom health check script in `group_vars/haproxy.yml`:

```yaml
keepalived_vrrp_scripts:
  - name: "check_backend"
    script: "/usr/local/bin/check_backend.sh"
    interval: 5
    weight: -20
```

## Performance Tuning

### HAProxy Tuning

```yaml
haproxy_maxconn: 4096          # Maximum concurrent connections
haproxy_nbthread: 4            # Number of threads (match CPU cores)
haproxy_timeout_connect: "5s"  # Backend connection timeout
haproxy_timeout_client: "50s"  # Client inactivity timeout
haproxy_timeout_server: "50s"  # Server inactivity timeout
```

### System Tuning

Increase system limits on load balancer nodes:

```bash
# /etc/sysctl.conf
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
```

## Backup and Recovery

### Backup Configuration

```bash
# Backup HAProxy configuration
scp ansible@10.2.0.110:/etc/haproxy/haproxy.cfg ./backup/

# Backup keepalived configuration
scp ansible@10.2.0.110:/etc/keepalived/keepalived.conf ./backup/
```

### Disaster Recovery

1. Reinstall servers from scratch
2. Run deployment playbook
3. Restore SSL certificates if needed
4. Verify failover functionality

## Support and Resources

### Documentation
- HAProxy: https://www.haproxy.org/
- keepalived: https://www.keepalived.org/
- Ansible: https://docs.ansible.com/

### Community
- r/haproxy: https://reddit.com/r/haproxy
- HAProxy Discourse: https://discourse.haproxy.org/

### Troubleshooting
For issues, check:
1. HAProxy logs: `docker logs haproxy`
2. keepalived logs: `journalctl -u keepalived`
3. System logs: `journalctl -xe`

## Change Log

- **v1.0.0** (2025-10-16): Initial release
  - HAProxy 3.0 support
  - keepalived integration
  - High availability failover
  - Comprehensive monitoring

## License

MIT License - See project root for details.
