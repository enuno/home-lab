# Anyone Protocol Relay Deployment

This Ansible playbook automates the deployment of an [Anyone Protocol](https://anyone.io) relay using Docker. The Anyone Protocol (formerly ATOR) is a privacy network that provides anonymous internet routing.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Post-Deployment](#post-deployment)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [References](#references)

## Overview

This playbook performs the following tasks:

1. Installs Docker and Docker Compose on Debian/Ubuntu or Fedora systems
2. Creates the required directory structure and sets permissions
3. Configures UFW firewall rules (optional)
4. Deploys the Anyone Protocol relay using Docker Compose
5. Configures the relay with customizable settings

### Features

- **Multi-distro support**: Works with Debian, Ubuntu, and Fedora
- **Idempotent**: Safe to run multiple times
- **Customizable**: Extensive configuration options via variables
- **Production-ready**: Follows security best practices
- **Tagged tasks**: Run specific parts of the playbook using tags

## Prerequisites

### Control Node (where you run Ansible)

- Ansible Core >= 2.19.3
- Python 3.11+
- Required Ansible collections:
  ```bash
  ansible-galaxy collection install community.general
  ansible-galaxy collection install community.docker
  ```

### Target Hosts (where the relay will run)

- Supported OS: Debian 11+, Ubuntu 20.04+, or Fedora 35+
- Minimum 2GB RAM
- Minimum 20GB disk space
- Root or sudo access
- SSH access configured
- Internet connectivity

### Network Requirements

- Static IP address or DDNS configured
- Port 9001 (or custom ORPort) available
- Router access for port forwarding configuration

## Quick Start

### 1. Install Ansible Collections

```bash
ansible-galaxy collection install community.general community.docker
```

### 2. Configure Inventory

Edit `inventory/anon_relay.ini` with your host details:

```ini
[anon_relay]
relay01.example.com ansible_host=192.168.1.100 ansible_user=admin

[anon_relay:vars]
ansible_user=admin
ansible_become=true
ansible_python_interpreter=/usr/bin/python3
```

### 3. Configure Variables

Edit `group_vars/anon_relay/vars.yml`:

```yaml
anon_relay_nickname: "MyHomeLabRelay"
anon_relay_contact_info: "your-email@example.com"
anon_relay_or_port: 9001
```

### 4. Run the Playbook

```bash
# Dry run (check mode)
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --check

# Full deployment
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml

# Deploy with custom variables
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml \
  -e "anon_relay_nickname=MyRelay" \
  -e "anon_relay_contact_info=contact@example.com"
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `anon_relay_nickname` | Relay nickname (max 19 chars, alphanumeric) | `"MyHomeLabRelay"` |
| `anon_relay_contact_info` | Contact information (email, Telegram, etc.) | `"admin@example.com"` |

### Network Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `anon_relay_or_port` | `9001` | ORPort for relay connections |
| `anon_relay_ipv4_only` | `false` | Disable IPv6 if ISP doesn't support it |

### Firewall Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `anon_relay_configure_firewall` | `true` | Automatically configure UFW firewall |

### Docker Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `anon_relay_pull_latest` | `true` | Always pull latest image on deployment |
| `anon_relay_use_custom_compose` | `false` | Use custom docker-compose file |
| `anon_relay_use_custom_config` | `false` | Use Jinja2 template for anonrc |
| `anon_relay_auto_restart` | `true` | Auto-restart relay on config changes |

### Advanced Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `anon_relay_my_family` | List of relay fingerprints if running multiple relays | `["$fingerprint1", "$fingerprint2"]` |
| `anon_relay_bandwidth_rate` | Bandwidth rate limit in KB/s | `1024` |
| `anon_relay_bandwidth_burst` | Bandwidth burst limit in KB/s | `2048` |
| `anon_relay_exit_policy` | Enable exit relay (WARNING: legal implications) | `false` |
| `anon_relay_log_level` | Log level (debug, info, notice, warn, err) | `"notice"` |

### Configuration Modes

The playbook supports two configuration modes:

#### Mode 1: Default Configuration with Line-by-Line Updates (Default)

```yaml
anon_relay_use_custom_config: false
```

Downloads the official anonrc from GitHub and updates specific lines with your variables.

#### Mode 2: Custom Template Configuration

```yaml
anon_relay_use_custom_config: true
```

Uses the Jinja2 template (`templates/anon_relay/anonrc.j2`) for complete control over configuration.

## Usage

### Running Specific Tasks with Tags

```bash
# Only install Docker
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --tags docker

# Only configure firewall
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --tags firewall

# Only update configuration
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --tags config

# Only deploy container
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --tags deploy
```

Available tags:
- `setup`: Installation and system setup tasks
- `docker`: Docker installation
- `directories`: Directory structure creation
- `users`: User creation
- `firewall`: Firewall configuration
- `config`: Configuration file management
- `docker-compose`: Docker Compose file handling
- `deploy`: Container deployment
- `verify`: Verification checks

### Running in Check Mode

```bash
# See what would change without making changes
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --check

# Check mode with diff to see exact changes
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --check --diff
```

### Multiple Relay Deployment

To deploy multiple relays, configure them in your inventory and set `anon_relay_my_family`:

```ini
[anon_relay]
relay01.example.com
relay02.example.com
relay03.example.com
```

In `group_vars/anon_relay/vars.yml`:

```yaml
# After first deployment, get fingerprints and configure MyFamily
anon_relay_my_family:
  - "$FINGERPRINT_RELAY_01"
  - "$FINGERPRINT_RELAY_02"
  - "$FINGERPRINT_RELAY_03"
```

## Post-Deployment

### 1. Configure Port Forwarding

Configure your router to forward traffic to your relay:

1. Access your router's admin panel
2. Navigate to port forwarding settings
3. Create a new rule:
   - **External Port**: 9001 (or your custom port)
   - **Internal IP**: Your relay server's IP
   - **Internal Port**: 9001 (or your custom port)
   - **Protocol**: TCP/UDP (or Both)
4. Save the rule

### 2. Verify Port is Open

Check if your port is accessible from the internet:

```bash
# Using online tool
# Visit: https://canyouseeme.org
# Enter your port number and check

# Or using nmap from another network
nmap -p 9001 your-public-ip
```

### 3. Monitor Container

```bash
# Check container status
docker ps | grep anon-relay

# View real-time logs
docker logs -f anon-relay

# View configuration
cat /opt/anon/etc/anon/anonrc

# Check notices log
tail -f /opt/anon/etc/anon/notices.log
```

### 4. Verify Relay Status

After 24-48 hours, your relay should appear in the network metrics:

- **Metrics Portal**: https://metrics.torproject.org/rs.html
- Search by your relay nickname or IP address

### 5. Get Your Relay Fingerprint

```bash
# From the container logs
docker logs anon-relay 2>&1 | grep -i fingerprint

# Or from the data directory
docker exec anon-relay cat /var/lib/anon/fingerprint
```

## Maintenance

### Updating the Relay

```bash
# Re-run the playbook to pull latest image and restart
ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml

# Or manually
docker pull ghcr.io/anyone-protocol/ator-protocol:latest
docker compose -f /opt/compose-files/relay.yaml up -d --force-recreate
```

### Viewing Logs

```bash
# Container logs
docker logs anon-relay
docker logs -f anon-relay --tail 100

# Notices log
tail -f /opt/anon/etc/anon/notices.log

# System journal (if using systemd)
journalctl -u docker -f
```

### Restarting the Relay

```bash
# Using Docker Compose
docker compose -f /opt/compose-files/relay.yaml restart

# Or using docker directly
docker restart anon-relay
```

### Stopping the Relay

```bash
# Stop the container
docker compose -f /opt/compose-files/relay.yaml stop

# Or permanently remove
docker compose -f /opt/compose-files/relay.yaml down
```

### Updating Configuration

1. Edit variables in `group_vars/anon_relay/vars.yml`
2. Re-run the playbook:
   ```bash
   ansible-playbook -i inventory/anon_relay.ini playbooks/deploy_anon_relay.yml --tags config
   ```
3. The relay will automatically restart if `anon_relay_auto_restart` is `true`

### Backup Important Data

```bash
# Backup relay keys and configuration
tar -czf anon-relay-backup-$(date +%Y%m%d).tar.gz \
  /opt/anon/etc/anon/ \
  /opt/anon/var/lib/anon/
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker ps -a | grep anon-relay

# View container logs
docker logs anon-relay

# Check if port is already in use
sudo ss -tulpn | grep 9001

# Verify configuration syntax
docker exec anon-relay anon --verify-config
```

### Port Not Accessible from Internet

1. Verify firewall rules:
   ```bash
   sudo ufw status
   sudo ufw status numbered
   ```

2. Check if Docker is listening:
   ```bash
   sudo ss -tulpn | grep 9001
   ```

3. Verify router port forwarding is configured correctly

4. Check if ISP blocks the port:
   ```bash
   # Test from external network
   nc -zv your-public-ip 9001
   ```

### Relay Not Showing in Metrics

- **Wait 24-48 hours**: New relays take time to be listed
- **Verify connectivity**: Ensure port is open and accessible
- **Check logs**: Look for connection attempts in logs
- **Verify configuration**: Ensure nickname and contact info are set

### Permission Errors

```bash
# Fix directory permissions
sudo chown -R 100:101 /opt/anon/run/anon/
sudo chmod -R 700 /opt/anon/run/anon/

# Fix log file permissions
sudo chown 100:101 /opt/anon/etc/anon/notices.log
```

### IPv6 Warnings

If you see IPv6-related warnings and your ISP doesn't support IPv6:

```yaml
# In vars.yml
anon_relay_ipv4_only: true
```

Then re-run the playbook.

### Docker Not Starting on Boot

```bash
# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Verify status
sudo systemctl status docker
```

## File Locations

| Path | Description |
|------|-------------|
| `/opt/compose-files/relay.yaml` | Docker Compose configuration |
| `/opt/anon/etc/anon/anonrc` | Main relay configuration |
| `/opt/anon/etc/anon/notices.log` | Relay log file |
| `/opt/anon/var/lib/anon/` | Relay data directory (keys, state) |
| `/opt/anon/run/anon/` | Runtime files (control socket) |
| `/root/.nyx/config` | Nyx monitor configuration |

## Security Considerations

1. **Firewall**: The playbook configures UFW to allow only SSH and ORPort
2. **Container Security**: Relay runs with restricted user (UID 100)
3. **Regular Updates**: Keep the relay software updated
4. **Key Protection**: Relay keys are stored in protected directories
5. **Contact Info**: Always provide valid contact information
6. **Exit Relay Warning**: Running an exit relay has legal implications; only enable if you understand the risks

## Standards and Guidelines

This deployment follows the [Anyone Protocol Relay Standards](https://docs.anyone.io/relay/guidelines/standards):

- Valid contact information is required
- MyFamily configuration for operators running multiple relays
- Do not alter the anon binary functionality
- Keep relay software updated
- Maintain consistent uptime
- Do not store or publish connection information

## References

### Official Documentation

- [Anyone Protocol Docs](https://docs.anyone.io)
- [Docker Installation Guide](https://docs.anyone.io/relay/start/install-anon-on-linux/docker)
- [Network Configuration](https://docs.anyone.io/relay/network/configure-ipv4-and-ipv6)
- [Port Forwarding](https://docs.anyone.io/relay/network/port-forward)
- [Firewall Setup](https://docs.anyone.io/relay/network/firewall)
- [Maintenance Guide](https://docs.anyone.io/relay/maintenance/updates)
- [Standards & Guidelines](https://docs.anyone.io/relay/guidelines/standards)

### Community Resources

- [Anyone Protocol GitHub](https://github.com/anyone-protocol)
- [Relay Metrics](https://metrics.torproject.org/rs.html)

### Project Files

- Playbook: `playbooks/deploy_anon_relay.yml`
- Variables: `group_vars/anon_relay/vars.yml`
- Template: `templates/anon_relay/anonrc.j2`
- Inventory: `inventory/anon_relay.ini`

## Contributing

If you find issues or have improvements:

1. Test changes in a safe environment
2. Follow the project's code quality standards
3. Document your changes
4. Consider adding your enhancements to the main repository

## License

This playbook is part of the Home Lab Infrastructure Automation project.
Refer to the project's LICENSE file for terms.

---

**Generated by**: Home Lab Infrastructure Team
**Version**: 1.0.0
**Last Updated**: October 2025
