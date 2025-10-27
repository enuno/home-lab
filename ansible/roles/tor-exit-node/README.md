# Tor Exit Node Ansible Role

A comprehensive Ansible role for deploying secure, production-ready Tor exit nodes following best practices from the Tor Project and community recommendations.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Important Legal Considerations](#important-legal-considerations)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Security](#security)
- [Monitoring](#monitoring)
- [Backup and Recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

## Overview

This role automates the deployment and configuration of Tor exit nodes with enterprise-grade security, monitoring, and operational best practices. It implements recommendations from:

- [Tor Project Exit Node Guide](https://community.torproject.org/relay/setup/exit/)
- [Tor Project Abuse Handling](https://blog.torproject.org/tips-running-exit-node/)
- [EFF Tor Legal FAQ](https://community.torproject.org/relay/community-resources/eff-tor-legal-faq/)

## Features

### Core Functionality

- **Automated Tor Installation**: Installs Tor from official Tor Project repositories
- **Reduced Exit Policy**: Implements reduced exit policy to minimize abuse complaints
- **IPv6 Support**: Optional IPv6 configuration for dual-stack operation
- **DNS Resolution**: Local Unbound DNS resolver with DNSSEC validation

### Security Hardening

- **System Hardening**: Kernel parameter tuning, AppArmor profiles, audit logging
- **SSH Hardening**: Disabled password authentication, rate limiting, key-only access
- **Firewall Configuration**: UFW/firewalld with minimal attack surface
- **Fail2Ban Integration**: Automated intrusion prevention
- **Automatic Updates**: Unattended security updates with scheduled reboots

### Monitoring & Observability

- **Prometheus Metrics**: Node exporter and custom Tor metrics exporter
- **Health Checks**: Automated health monitoring with alerting
- **Log Management**: Centralized logging with rotation and retention
- **Performance Monitoring**: System resource tracking and reporting

### Operations

- **Backup Automation**: Automated backup of Tor keys and configuration
- **Management Scripts**: Helper scripts for common operations
- **Exit Notice Page**: Customizable HTML notice for abuse complaints
- **Documentation**: Comprehensive post-deployment documentation

## Requirements

### System Requirements

- **OS**: Ubuntu 22.04/24.04 LTS or Debian 11/12
- **CPU**: Minimum 2 cores (4+ recommended)
- **RAM**: Minimum 1GB (4GB+ recommended for high-bandwidth relays)
- **Disk**: 20GB minimum (more for logs and backups)
- **Network**: Dedicated public IP with unrestricted incoming/outgoing traffic

### Ansible Requirements

- **Ansible Version**: 2.19+ with community collections
- **Collections**:
  - community.general
  - ansible.posix
- **Python**: Python 3.11+ on control node

### Installation

Install required Ansible collections:

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix
```

### Network Requirements

- **Dedicated IP**: Do NOT run on shared infrastructure
- **Unrestricted Traffic**: No bandwidth caps or port restrictions
- **Reverse DNS**: Ability to configure PTR records
- **ISP Support**: ISP must be informed and supportive

## Important Legal Considerations

### Before You Deploy

**CRITICAL**: Running a Tor exit node has legal implications. You MUST:

1. **Inform Your ISP**: Contact your ISP/hosting provider BEFORE deployment
2. **Understand Local Laws**: Research Tor exit node legality in your jurisdiction
3. **Prepare for Complaints**: You will receive abuse complaints from law enforcement, copyright holders, and others
4. **Use Dedicated Hardware**: NEVER run an exit node on the same server as other services
5. **Consider Legal Entity**: High-capacity operators should consider forming an LLC

### Recommended Precautions

- Set up reverse DNS clearly identifying the server as a Tor exit node
- Update WHOIS records with accurate contact information
- Configure exit notice page (automatically deployed by this role)
- Prepare abuse complaint response templates
- Consider obtaining legal advice in your jurisdiction

### Not Recommended For

- Residential internet connections
- Shared hosting environments
- Jurisdictions with unclear legal status
- Personal servers with sensitive data

## Quick Start

### 1. Inventory Setup

Create an inventory file:

```ini
# inventory/production/hosts
[tor_exit_nodes]
tor-exit-1 ansible_host=203.0.113.10 ansible_user=ubuntu
tor-exit-2 ansible_host=203.0.113.11 ansible_user=ubuntu
```

### 2. Configure Variables

Create encrypted vault file:

```bash
cd ansible
cp group_vars/tor_exit_nodes_vault.yml.template group_vars/tor_exit_nodes_vault.yml
```

Edit with real values:

```bash
ansible-vault edit group_vars/tor_exit_nodes_vault.yml
```

Required variables:

```yaml
tor_contact_info_vault: "Your Name <email@example.com>"
tor_operator_name_vault: "Your Name"
tor_operator_email_vault: "operator@example.com"
tor_abuse_email_vault: "abuse@example.com"
tor_alert_email_vault: "alerts@example.com"
```

### 3. Deploy

```bash
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --ask-vault-pass
```

### 4. Post-Deployment

After deployment, complete these critical steps:

1. Configure reverse DNS (PTR record)
2. Update WHOIS information
3. Inform your ISP
4. Monitor relay status at https://metrics.torproject.org/

## Configuration

### Key Variables

#### Bandwidth Configuration

```yaml
# Set to ~80% of actual capacity for reliability
tor_bandwidth_rate: 10240      # 10 MB/s sustained
tor_bandwidth_burst: 20480     # 20 MB/s burst
```

#### Exit Policy

```yaml
# Use reduced exit policy (recommended)
tor_reduced_exit_policy: true

# Or define custom policy
tor_reduced_exit_policy: false
tor_custom_exit_policy:
  - "accept *:80"
  - "accept *:443"
  - "reject *:*"
```

#### Security Settings

```yaml
tor_enable_system_hardening: true
tor_enable_apparmor: true
tor_enable_fail2ban: true
tor_harden_ssh: true
tor_enable_automatic_updates: true
```

#### Monitoring

```yaml
tor_enable_monitoring: true
tor_enable_prometheus_exporter: true
tor_prometheus_exporter_port: 9130
tor_log_level: "notice"
```

#### Backup

```yaml
tor_enable_backups: true
tor_backup_dir: "/var/backups/tor"
tor_backup_retention_days: 7
tor_backup_schedule: "0 3 * * *"  # Daily at 3 AM
```

### All Variables

See `defaults/main.yml` for complete variable reference with detailed comments.

## Usage

### Playbook Execution

#### Standard Deployment

```bash
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --ask-vault-pass
```

#### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --check
```

#### Run Specific Tags

```bash
# Only configure firewall
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --tags firewall

# Skip hardening
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --skip-tags hardening
```

#### Limit to Specific Hosts

```bash
ansible-playbook -i inventory/production playbooks/deploy-tor-exit-node.yml --limit tor-exit-1
```

### Available Tags

- `prerequisites` - System updates and package installation
- `hardening` - Security hardening
- `dns` - DNS resolver configuration
- `tor` - Tor installation and configuration
- `install` - Installation tasks only
- `config` - Configuration tasks only
- `firewall` - Firewall configuration
- `monitoring` - Monitoring setup
- `backup` - Backup configuration

### Management Commands

After deployment, use these commands on the target server:

```bash
# Tor management
sudo tor-manage status       # Show status and recent logs
sudo tor-manage logs         # Follow logs in real-time
sudo tor-manage fingerprint  # Display relay fingerprint
sudo tor-manage reload       # Reload configuration
sudo tor-manage restart      # Restart Tor service
sudo tor-manage verify       # Verify configuration

# Health monitoring
sudo tor-health-check        # Run health check

# Backup management
sudo tor-backup              # Create manual backup
sudo tor-restore <file>      # Restore from backup
```

### Service Management

```bash
# Systemd commands
sudo systemctl status tor
sudo systemctl restart tor
sudo systemctl reload tor

# View logs
sudo journalctl -u tor -f
sudo journalctl -u tor -n 100
```

## Security

### Security Features

1. **SSH Hardening**
   - Password authentication disabled
   - Root login disabled
   - Key-based authentication only
   - Fail2Ban protection

2. **Kernel Hardening**
   - Network stack hardening
   - ASLR enabled
   - Kernel pointer hiding
   - IPv4/IPv6 security

3. **Application Security**
   - AppArmor profiles
   - Systemd service hardening
   - File descriptor limits
   - Minimal attack surface

4. **Network Security**
   - UFW/firewalld configured
   - Minimal open ports
   - Connection tracking
   - Rate limiting

### Firewall Rules

Default allowed ports:

- SSH: 22 (configurable)
- Tor ORPort: 9001
- Tor DirPort: 9030 (optional)

All other incoming traffic is denied by default.

### Automatic Updates

Security updates are automatically applied with:

- Daily update checks
- Automatic download and installation
- Scheduled reboots at 02:00 if required
- Email notifications (if configured)

## Monitoring

### Prometheus Metrics

The role installs two exporters:

1. **Node Exporter** (port 9100): System metrics
2. **Tor Exporter** (port 9130): Tor-specific metrics

Metrics available:

- Bandwidth usage (read/written)
- Connection count
- Circuit count
- Uptime
- Relay information

### Health Checks

Automated health checks run every 15 minutes and monitor:

- Tor service status
- ORPort availability
- DNS resolution
- Disk space
- Memory usage
- Load average
- Active connections

### Log Files

- Tor logs: `/var/log/tor/tor.log` or `journalctl -u tor`
- Health checks: `/var/log/tor/health-check.log`
- Backup logs: `/var/log/tor/backup.log`

## Backup and Recovery

### Automatic Backups

Backups run daily (configurable) and include:

- Tor configuration (`torrc`)
- Tor keys (critical for relay identity)
- Relay fingerprint
- State files
- System configuration

### Manual Backup

```bash
sudo tor-backup
```

Backups are stored in `/var/backups/tor/` by default.

### Restore from Backup

```bash
# List available backups
ls -l /var/backups/tor/

# Restore from specific backup
sudo tor-restore /var/backups/tor/tor-backup-20250101_030000.tar.gz
```

**IMPORTANT**: Your Tor keys are critical. Losing them means losing your relay's reputation and bandwidth allocation. Keep secure offsite backups!

## Troubleshooting

### Common Issues

#### Tor Won't Start

1. Check configuration:
   ```bash
   sudo tor --verify-config -f /etc/tor/torrc
   ```

2. Check logs:
   ```bash
   sudo journalctl -u tor -n 50
   ```

3. Check file permissions:
   ```bash
   ls -la /var/lib/tor/
   ```

#### Relay Not Appearing in Metrics

- Wait 3-4 hours for initial consensus
- Verify ORPort is accessible externally:
  ```bash
  telnet YOUR_IP 9001
  ```
- Check firewall allows incoming connections
- Verify correct configuration in torrc

#### DNS Resolution Failures

```bash
# Check Unbound status
sudo systemctl status unbound

# Test DNS resolution
dig @127.0.0.1 torproject.org

# Check Unbound logs
sudo journalctl -u unbound -n 50
```

#### High Memory Usage

- Normal for high-bandwidth relays
- Consider increasing system memory
- Monitor with: `free -h` and `htop`

### Getting Help

- Check logs: `sudo journalctl -u tor -f`
- Run health check: `sudo tor-health-check`
- Review documentation: `/etc/tor/README.exit-node`
- Tor Project support: https://support.torproject.org/
- Tor relay mailing list: tor-relays@lists.torproject.org

## Resources

### Official Documentation

- [Tor Project](https://www.torproject.org/)
- [Tor Relay Guide](https://community.torproject.org/relay/)
- [Exit Node Setup](https://community.torproject.org/relay/setup/exit/)
- [Tor Metrics](https://metrics.torproject.org/)

### Legal Resources

- [EFF Tor Legal FAQ](https://community.torproject.org/relay/community-resources/eff-tor-legal-faq/)
- [Abuse Response Templates](https://community.torproject.org/relay/community-resources/tor-abuse-templates/)

### Community

- Mailing List: tor-relays@lists.torproject.org
- IRC: #tor-relays on OFTC
- Telegram: https://t.me/TorRelays
- Forum: https://forum.torproject.net/

## Contributing

Improvements and bug fixes are welcome! Please follow these guidelines:

1. Test changes in a development environment
2. Follow Ansible best practices
3. Update documentation
4. Submit pull request with clear description

## License

MIT License - See LICENSE file for details

## Disclaimer

This role is provided as-is for educational and privacy-enhancement purposes. Operating a Tor exit node may have legal implications in your jurisdiction. The authors and contributors are not responsible for any legal issues, abuse complaints, or other consequences arising from use of this role.

Always consult with legal counsel and your ISP before operating a Tor exit node.

## Author

Created for the HomeLab Infrastructure Project
Maintained by the community

## Acknowledgments

- [The Tor Project](https://www.torproject.org/) for developing Tor and providing documentation
- [Electronic Frontier Foundation (EFF)](https://www.eff.org/) for legal guidance
- The Tor relay operator community for best practices and support
