# DEVELOPMENT PLAN: Ansible Playbook for Anyone Protocol Anon Relay Deployment

## Project Overview

**Project Name:** anon-relay-ansible-deployment
**Version:** 2.0.0
**Purpose:** Automate the deployment of Anyone Protocol Anon Relay nodes (Relay, Exit Relay, and SOCKS Proxy) via Docker using Ansible
**Target Platforms:** Ubuntu, Debian, Fedora (amd64 and arm64 architectures)
**Documentation Reference:** https://docs.anyone.io/relay/start/install-anon-on-linux/docker

## Project Context

The Anyone Protocol (formerly ATOR) is a decentralized, privacy-first relay network that provides censorship-resistant, anonymous internet routing[41][42][43][44][45]. This project automates the deployment of three types of Anon nodes using Ansible, enabling operators to quickly set up and manage relay infrastructure that contributes to the Anyone network.

### Relay Types Supported

1. **Standard Relay (Middle/Guard Relay)**[41][43]
   - Routes encrypted traffic through the Anyone network
   - Does not expose operator's IP to destination sites
   - Lower maintenance requirements
   - Suitable for home or datacenter hosting

2. **Exit Relay**[42][44][45]
   - Final hop where traffic exits the Anyone network to public internet
   - Operator's IP visible to destination sites
   - Requires careful legal and hosting considerations
   - **NOT recommended** for home or private premises[42]
   - Higher maintenance and abuse complaint handling required[42][44]

3. **SOCKS Proxy**[46]
   - Local proxy server routing LAN traffic through Anyone network
   - Enables devices on local network to use Anyone for anonymity
   - Experimental configuration[46]
   - Suitable for private network use

### Key Features
- **Privacy Network Infrastructure:** Deploy relay nodes that facilitate anonymous internet routing[41]
- **Token Incentivization:** Relay operators earn ANYONE tokens for bandwidth contribution[41]
- **Docker-Based Deployment:** Containerized approach for portability and ease of management[41]
- **Multi-Architecture Support:** Compatible with amd64 and arm64 systems including Raspberry Pi[41]
- **Automated Configuration:** Eliminates manual setup steps and reduces human error
- **Security Hardening:** Implements VPS hardening and security best practices[47]
- **Multi-Role Support:** Deploy standard relays, exit relays, or SOCKS proxies[41][42][46]

## Development Phases

### Phase 1: Project Structure & Documentation (Week 1)

**Objectives:**
- Set up Ansible project directory structure following best practices
- Create comprehensive AI agent instruction files
- Initialize version control with appropriate .gitignore
- Document all three relay types and their requirements

**Deliverables:**
- [ ] Project directory structure
- [ ] AGENTS.md with universal coding agent instructions
- [ ] CLAUDE.md with Claude-specific configuration
- [ ] README.md with project overview and usage instructions
- [ ] .gitignore configured for Ansible projects
- [ ] ansible.cfg with project-specific settings
- [ ] requirements.yml for Ansible Galaxy dependencies
- [ ] Documentation for relay types (Standard, Exit, SOCKS)

**Tasks:**
1. Create base directory structure following Ansible best practices
2. Document project architecture and design decisions for all relay types
3. Define coding standards and conventions for the team
4. Set up Git repository with proper branch protection
5. Create AI agent instruction files for consistent development
6. Research and document legal considerations for exit relays[42][44]
7. Document security hardening requirements[47]

### Phase 2: Docker Installation Role (Week 1-2)

**Objectives:**
- Create reusable Ansible role for Docker installation
- Support multiple Linux distributions (Ubuntu/Debian, Fedora)
- Implement idempotent tasks with proper error handling

**Deliverables:**
- [ ] `roles/docker_setup/` complete role structure
- [ ] Distribution-specific installation tasks
- [ ] Docker repository configuration
- [ ] Docker Compose plugin installation
- [ ] Service startup and validation
- [ ] Handler for Docker service restarts
- [ ] Comprehensive role documentation

**Technical Requirements:**
- Install Docker CE, Docker CLI, containerd.io[41]
- Install Docker Compose plugin[41]
- Configure Docker daemon for security best practices
- Create docker group and add specified users
- Validate Docker socket availability
- Support both systemd and non-systemd init systems

**Tasks:**
1. Create role scaffolding with `ansible-galaxy init docker_setup`
2. Define default variables for Docker version, repository URLs
3. Write tasks for Ubuntu/Debian distributions[41]
4. Write tasks for Fedora/RHEL distributions[41]
5. Create handlers for service management
6. Add pre-flight checks and validation tasks
7. Document role variables and usage examples
8. Write unit tests using Molecule (optional but recommended)

### Phase 3: Base Anon Relay Deployment Role (Week 2-3)

**Objectives:**
- Create Ansible role for base Anon relay node deployment (shared by all types)
- Implement directory structure preparation
- Template configuration files for flexibility
- Deploy Docker containers using docker_container module

**Deliverables:**
- [ ] `roles/anon_relay_base/` complete role structure
- [ ] Directory creation and permission management
- [ ] Base configuration templates
- [ ] Docker Compose file deployment
- [ ] Container lifecycle management tasks
- [ ] Configuration file download and templating
- [ ] User and group creation

**Technical Requirements:**
- Create required directories: `/opt/compose-files/`, `/opt/anon/etc/anon/`, `/opt/anon/run/anon/`, `/root/.nyx/`[41]
- Set proper ownership (UID 100, GID 101 for anon user)[41]
- Template and deploy relay.yaml Docker Compose configuration[41]
- Template and deploy base anonrc configuration[41][43]
- Template and deploy Nyx config file[41]
- Pull Docker image: `svforte/anon:latest`[41]
- Create and start anon-relay container[41]
- Implement terms and conditions acceptance (required since v0.4.9.7-live)[41]

**Configuration Templates:**
1. **relay.yaml.j2** - Docker Compose configuration[41]
2. **anonrc_base.j2** - Base Anon relay configuration with variables for:
   - Relay nickname[41][43]
   - Contact information[43]
   - Bandwidth limits[43]
   - Port configuration[43][48]
   - MyFamily declaration[43]
3. **config.j2** - Nyx monitor configuration[41]

**Tasks:**
1. Create role scaffolding with `ansible-galaxy init anon_relay_base`
2. Define comprehensive default variables
3. Write directory creation tasks with proper permissions[41]
4. Create Jinja2 templates for all configuration files
5. Implement file download tasks with error handling
6. Write Docker container deployment tasks
7. Add validation tasks to verify deployment
8. Create handlers for container restart
9. Document all role variables with examples
10. Add pre-deployment checks for system requirements

### Phase 4: Standard Relay Configuration Role (Week 3)

**Objectives:**
- Create role for standard (middle/guard) relay configuration
- Implement relay-specific settings
- Configure bandwidth and network parameters

**Deliverables:**
- [ ] `roles/anon_relay_standard/` complete role structure
- [ ] Standard relay configuration template
- [ ] Bandwidth configuration
- [ ] Network connectivity validation

**Technical Requirements:**
- Configure ORPort for incoming connections[41][43][48]
- Set SocksPort to 0 (disable local SOCKS)[43]
- Configure bandwidth rate and burst limits[43]
- Implement port forwarding verification[48]
- Configure firewall rules (UFW)[47][49]
- Support IPv4 and IPv6 configuration[50]

**Configuration Parameters:**
```yaml
# Standard Relay Settings
anon_relay_type: "standard"
anon_relay_nickname: "MyRelay"
anon_relay_contact: "operator@example.com"
anon_relay_or_port: 9001
anon_relay_socks_port: 0
anon_relay_bandwidth_rate: "100 MBytes"
anon_relay_bandwidth_burst: "200 MBytes"
anon_relay_ipv6_enabled: true
anon_relay_myfamily: []  # List of related relay fingerprints
```

**Tasks:**
1. Create role scaffolding
2. Template standard relay anonrc configuration[43]
3. Implement port forwarding configuration[48]
4. Configure firewall rules for ORPort[47][49]
5. Add ORPort reachability checks[51]
6. Implement IPv4/IPv6 configuration[50]
7. Add MyFamily configuration support[43]
8. Document configuration options
9. Create validation tasks
10. Add troubleshooting documentation[51]

### Phase 5: Exit Relay Configuration Role (Week 3-4)

**Objectives:**
- Create role for exit relay configuration
- Implement exit policies and security measures
- Add abuse complaint handling documentation
- Implement reverse DNS configuration

**Deliverables:**
- [ ] `roles/anon_relay_exit/` complete role structure
- [ ] Exit relay configuration template with policies
- [ ] Exit notice HTML template deployment
- [ ] Reverse DNS setup documentation
- [ ] Abuse handling procedures documentation
- [ ] Legal considerations documentation

**Technical Requirements:**
- Configure as exit relay with ExitRelay setting[42]
- Implement restrictive exit policies (block high-risk ports)[42][44]
- Deploy Anyone exit notice HTML page[42]
- Configure DirPort for exit notice[42]
- Set up firewall rules for exit relay[42][47]
- Document reverse DNS (PTR and A record) setup[42]
- Implement DoS mitigation settings[52]

**Exit Policy Configuration:**[42][44]
```yaml
# Exit Relay Settings
anon_relay_type: "exit"
anon_relay_exit_policy:
  - "reject *:25"      # SMTP
  - "reject *:587"     # SMTP Submission
  - "reject *:465"     # SMTPS
  - "reject *:2525"    # SMTP Alternative
  - "reject *:3389"    # RDP
  - "reject *:23"      # Telnet
  - "reject *:3128"    # HTTP Proxy
  - "reject *:5900"    # VNC
  - "reject *:9999"    # Custom high-risk
  - "accept *:*"       # Accept everything else
```

**Security Considerations:**[42][44][47]
- Never host exit relay at home or private premises[42]
- Use relay-friendly ISP with abuse complaint handling[44]
- Set up proper reverse DNS (PTR and A records)[42]
- Implement disk encryption for relay keys[44]
- Configure SSH hardening (key auth, non-standard port)[47]
- Install and configure Fail2Ban[47]
- Regular security updates and monitoring[44][47]

**Legal Considerations:**[44]
- Consult legal expert before operation
- Understand intermediary liability laws in jurisdiction
- Consider creating legal entity (non-profit) for operation
- Proactively engage with law enforcement
- Prepare abuse complaint response templates
- Document legal protections available

**Tasks:**
1. Create role scaffolding
2. Template exit relay anonrc with restrictive policies[42]
3. Deploy exit notice HTML template[42]
4. Configure DirPort for exit notice serving[42]
5. Implement firewall rules (ORPort, DirPort, SSH)[42][47]
6. Add DoS mitigation configuration[52]
7. Create reverse DNS documentation[42]
8. Write abuse complaint handling guide[44]
9. Document legal considerations[44]
10. Create exit relay checklist[42][44]

### Phase 6: SOCKS Proxy Configuration Role (Week 4)

**Objectives:**
- Create role for SOCKS proxy configuration
- Implement local network proxy settings
- Configure network isolation and access control

**Deliverables:**
- [ ] `roles/anon_relay_socks/` complete role structure
- [ ] SOCKS proxy configuration template
- [ ] Network access policy configuration
- [ ] Client configuration documentation

**Technical Requirements:**
- Configure SocksPort with LAN IP binding[46]
- Implement SocksPolicy for subnet access control[46]
- Disable relay functionality (ORPort 0)
- Configure for local network use only[46]
- Document client configuration for various platforms[46]

**SOCKS Configuration:**[46]
```yaml
# SOCKS Proxy Settings
anon_relay_type: "socks"
anon_socks_port: 9050
anon_socks_bind_address: "192.168.1.10"
anon_socks_policy_accept: "192.168.1.0/24"
anon_or_port: 0  # Disable relay functionality
```

**Configuration Template:**
```
# SOCKS Proxy Configuration
SocksPort {{ anon_socks_bind_address }}:{{ anon_socks_port }}
SocksPolicy accept {{ anon_socks_policy_accept }}
ORPort 0
Log notice file /var/log/anon/notices.log
```

**Tasks:**
1. Create role scaffolding
2. Template SOCKS proxy anonrc configuration[46]
3. Implement network detection for LAN subnet
4. Configure firewall rules for LAN access only
5. Create client configuration documentation[46]
6. Add platform-specific proxy setup guides (Linux/macOS/Windows)[46]
7. Implement validation tests
8. Document experimental nature and limitations[46]
9. Create troubleshooting guide
10. Add security warnings about SOCKS proxy exposure

### Phase 7: Monitoring & Management Role (Week 4)

**Objectives:**
- Create role for Nyx monitor installation
- Implement log monitoring capabilities
- Add container health check tasks
- Implement relay performance monitoring

**Deliverables:**
- [ ] `roles/anon_relay_monitor/` complete role structure
- [ ] Nyx installation tasks
- [ ] Log monitoring configuration
- [ ] Container status verification
- [ ] Health check tasks
- [ ] ORPort reachability monitoring

**Technical Requirements:**
- Install Nyx monitoring tool (distribution-specific)[41]
- Configure log rotation for notices.log[41]
- Implement container health checks
- Add ORPort reachability verification[51]
- Create monitoring playbook for operational use
- Configure alerting hooks (optional)

**Monitoring Components:**
- ORPort reachability status[51]
- Bandwidth usage tracking
- Container uptime and restarts
- Log file analysis for warnings/errors
- Network connectivity status
- Relay descriptor publication

**Tasks:**
1. Create role scaffolding with `ansible-galaxy init anon_relay_monitor`
2. Write Nyx installation tasks for each distribution[41]
3. Configure log file monitoring
4. Implement container health verification
5. Add ORPort reachability checks[51]
6. Create operational monitoring playbook
7. Document monitoring procedures
8. Add relay troubleshooting automation[51]
9. Implement performance metrics collection
10. Create alerting integration documentation

### Phase 8: Security Hardening Role (Week 4-5)

**Objectives:**
- Implement VPS hardening best practices
- Configure SSH security
- Set up firewall and intrusion prevention
- Implement system monitoring

**Deliverables:**
- [ ] `roles/security_hardening/` complete role structure
- [ ] SSH hardening tasks
- [ ] UFW firewall configuration
- [ ] Fail2Ban installation and configuration
- [ ] System update automation
- [ ] Security audit tasks

**Technical Requirements:**[47]
- System updates and automatic update configuration
- Disable unnecessary services
- SSH hardening:
  - Change default SSH port
  - Disable root login
  - SSH key authentication only
  - Login banners
- UFW firewall:
  - Default deny incoming
  - Allow essential ports only
  - Custom SSH port support
- Fail2Ban:
  - SSH protection
  - Custom jail configuration
  - Ban time and retry limits
- Optional: Watchdog installation

**Security Checklist:**[44][47]
- [ ] SSH port changed from default 22
- [ ] Root login disabled
- [ ] Password authentication disabled (SSH keys only)
- [ ] UFW enabled with minimal port exposure
- [ ] Fail2Ban active and monitoring SSH
- [ ] System updates automated
- [ ] Unnecessary services disabled
- [ ] Disk encryption configured (for exit relays)
- [ ] Login banners configured
- [ ] Security audit logging enabled

**Tasks:**
1. Create role scaffolding
2. Implement system update tasks[47]
3. Create service audit and disable tasks[47]
4. Configure SSH hardening[47]
5. Implement UFW firewall configuration[47][49]
6. Install and configure Fail2Ban[47]
7. Add login banner configuration[47]
8. Implement security audit tasks
9. Create monitoring integration
10. Document security procedures[47]

### Phase 9: Network Configuration Role (Week 5)

**Objectives:**
- Automate port forwarding verification
- Configure IPv4/IPv6 settings
- Implement firewall rules for different relay types
- Add network troubleshooting automation

**Deliverables:**
- [ ] `roles/network_config/` complete role structure
- [ ] Port forwarding verification tasks
- [ ] IPv4/IPv6 configuration
- [ ] Firewall rule templates per relay type
- [ ] Network troubleshooting playbook

**Technical Requirements:**
- Port forwarding verification for relay operators[48]
- IPv4/IPv6 configuration options[50]
- UFW rules for:
  - Standard relay: ORPort[49]
  - Exit relay: ORPort, DirPort, SSH[42][49]
  - SOCKS proxy: LAN access only[46]
- ORPort reachability testing[51]
- CGNAT detection and warnings[51]

**Network Configuration Parameters:**
```yaml
# Port Forwarding
anon_port_forward_required: true  # For standard/exit relays
anon_or_port: 9001
anon_dir_port: 80  # Exit relays only

# IPv6 Configuration
anon_ipv6_enabled: true
anon_ipv6_exit: false  # Exit relays

# Firewall
anon_ssh_port: 22
anon_ufw_enabled: true
```

**Tasks:**
1. Create role scaffolding
2. Implement port forwarding documentation generation[48]
3. Configure IPv4/IPv6 settings[50]
4. Create firewall rule templates per relay type[49]
5. Add ORPort reachability verification[51]
6. Implement CGNAT detection[51]
7. Create network troubleshooting playbook[51]
8. Add router configuration guides[48]
9. Document port forwarding procedures[48]
10. Create verification tools integration

### Phase 10: Main Playbooks & Inventory (Week 5-6)

**Objectives:**
- Create main playbooks orchestrating all roles
- Define inventory structure for different relay types
- Implement group_vars and host_vars for configuration
- Create playbooks for different operational scenarios

**Deliverables:**
- [ ] site.yml - Main deployment playbook
- [ ] deploy_standard.yml - Standard relay deployment
- [ ] deploy_exit.yml - Exit relay deployment
- [ ] deploy_socks.yml - SOCKS proxy deployment
- [ ] inventory.ini - Sample inventory file
- [ ] group_vars/all.yml - Global variables
- [ ] group_vars/standard_relays.yml - Standard relay variables
- [ ] group_vars/exit_relays.yml - Exit relay variables
- [ ] group_vars/socks_proxies.yml - SOCKS proxy variables
- [ ] host_vars/ - Host-specific overrides
- [ ] update.yml - Update existing deployments
- [ ] remove.yml - Cleanup playbook
- [ ] harden.yml - Security hardening playbook

**Inventory Structure:**
```ini
[standard_relays]
relay1.example.com
relay2.example.com

[exit_relays]
exit1.example.com
exit2.example.com

[socks_proxies]
socks1.local

[relays:children]
standard_relays
exit_relays

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

**Playbook Structure:**
```yaml
# deploy_standard.yml - Standard Relay Deployment
---
- name: Deploy Standard Anon Relay
  hosts: standard_relays
  become: yes

  pre_tasks:
    - name: Verify system requirements
      include_role:
        name: preflight_checks

  roles:
    - docker_setup
    - anon_relay_base
    - anon_relay_standard
    - network_config
    - anon_relay_monitor
    - security_hardening

  post_tasks:
    - name: Verify relay is running
      include_role:
        name: health_checks

# deploy_exit.yml - Exit Relay Deployment
---
- name: Deploy Exit Anon Relay
  hosts: exit_relays
  become: yes

  pre_tasks:
    - name: Verify legal acknowledgment
      assert:
        that:
          - anon_exit_legal_acknowledged | default(false)
        fail_msg: "You must acknowledge legal considerations for exit relays"

    - name: Verify system requirements
      include_role:
        name: preflight_checks

  roles:
    - docker_setup
    - anon_relay_base
    - anon_relay_exit
    - network_config
    - anon_relay_monitor
    - security_hardening

  post_tasks:
    - name: Display exit relay warnings
      debug:
        msg: |
          Exit relay deployed. Important reminders:
          - Set up reverse DNS (PTR and A records)
          - Monitor abuse complaints regularly
          - Review firewall rules
          - Ensure legal compliance

    - name: Verify relay is running
      include_role:
        name: health_checks

# deploy_socks.yml - SOCKS Proxy Deployment
---
- name: Deploy SOCKS Proxy
  hosts: socks_proxies
  become: yes

  pre_tasks:
    - name: Verify system requirements
      include_role:
        name: preflight_checks

  roles:
    - docker_setup
    - anon_relay_base
    - anon_relay_socks
    - anon_relay_monitor

  post_tasks:
    - name: Display proxy configuration
      debug:
        msg: |
          SOCKS proxy deployed at:
          {{ anon_socks_bind_address }}:{{ anon_socks_port }}
          Accessible from: {{ anon_socks_policy_accept }}
```

**Tasks:**
1. Create site.yml main playbook
2. Create relay-type-specific playbooks
3. Design inventory structure with example hosts
4. Define variable hierarchy (defaults → group_vars → host_vars)
5. Create group_vars/all.yml with common settings
6. Create group_vars for each relay type
7. Add host_vars examples for node-specific settings
8. Write update.yml for updating existing relays[41]
9. Write remove.yml for clean uninstallation[41]
10. Add tags to all tasks for selective execution
11. Document playbook execution examples
12. Create pre-flight check role
13. Create health check role

### Phase 11: Testing & Validation (Week 6)

**Objectives:**
- Test playbooks across different distributions and relay types
- Validate idempotency of all tasks
- Perform integration testing
- Document test results

**Deliverables:**
- [ ] Test environment setup with Vagrant/Docker
- [ ] Test cases for each role and relay type
- [ ] Integration test suite
- [ ] CI/CD pipeline configuration (GitHub Actions)
- [ ] Test documentation and results

**Testing Strategy:**
1. **Unit Testing:** Test individual roles in isolation using Molecule
2. **Integration Testing:** Test complete deployment workflow for each relay type
3. **Idempotency Testing:** Verify tasks can run multiple times safely
4. **Multi-Distribution Testing:** Test on Ubuntu, Debian, Fedora
5. **Multi-Architecture Testing:** Test on amd64 and arm64 (Raspberry Pi)
6. **Security Testing:** Verify hardening measures are applied correctly

**Test Matrix:**
| Distribution | Architecture | Relay Type | Status |
|--------------|--------------|------------|--------|
| Ubuntu 22.04 | amd64 | Standard | [ ] |
| Ubuntu 22.04 | amd64 | Exit | [ ] |
| Ubuntu 22.04 | amd64 | SOCKS | [ ] |
| Debian 11 | amd64 | Standard | [ ] |
| Debian 11 | arm64 | Standard | [ ] |
| Fedora 38 | amd64 | Standard | [ ] |
| Raspberry Pi OS | arm64 | Standard | [ ] |

**Tasks:**
1. Set up Vagrant/Docker test environments
2. Write Molecule scenarios for each role
3. Create test inventory with mock hosts
4. Test standard relay deployment
5. Test exit relay deployment with all security measures
6. Test SOCKS proxy deployment
7. Execute tests and document results
8. Configure GitHub Actions for CI/CD
9. Add linting with ansible-lint
10. Add syntax checking with ansible-playbook --syntax-check
11. Perform security scanning
12. Document test procedures and results
13. Create troubleshooting guide based on test findings

### Phase 12: Documentation & Examples (Week 6-7)

**Objectives:**
- Create comprehensive user documentation for all relay types
- Provide example configurations for common scenarios
- Document troubleshooting procedures
- Create deployment guides

**Deliverables:**
- [ ] Complete README.md with all relay types
- [ ] CONTRIBUTING.md for contributors
- [ ] SECURITY.md for security reporting
- [ ] CHANGELOG.md for version tracking
- [ ] examples/ directory with sample configurations
- [ ] docs/ directory with detailed guides
- [ ] Troubleshooting guide for each relay type
- [ ] FAQ document
- [ ] Legal considerations guide for exit relays
- [ ] Abuse complaint handling guide

**Documentation Sections:**
1. **Quick Start Guide:** Get running in 5 minutes for each relay type
2. **Installation Guide:** Detailed setup instructions
3. **Configuration Guide:** All available variables and options per relay type
4. **Standard Relay Guide:** Configuration and best practices
5. **Exit Relay Guide:** Legal, technical, and operational guidance[42][44]
6. **SOCKS Proxy Guide:** Setup and client configuration[46]
7. **Operations Guide:** Day-to-day management tasks
8. **Security Guide:** Hardening procedures and best practices[47]
9. **Network Guide:** Port forwarding and firewall configuration[48][49]
10. **Troubleshooting Guide:** Common issues and solutions[51]
11. **Architecture Guide:** Technical deep-dive
12. **Contributing Guide:** How to contribute code

**Example Configurations:**
```
examples/
├── standard-relay-basic.yml
├── standard-relay-ipv6.yml
├── standard-relay-myfamily.yml
├── exit-relay-basic.yml
├── exit-relay-hardened.yml
├── exit-relay-reduced-policy.yml
├── socks-proxy-home-network.yml
├── socks-proxy-office-network.yml
└── multi-relay-deployment.yml
```

**Tasks:**
1. Write comprehensive README.md with all relay types
2. Create quick start tutorials for each type
3. Document all role variables with examples
4. Create example inventory files
5. Document common deployment scenarios
6. Write comprehensive troubleshooting guides[51]
7. Create exit relay legal and operational guide[42][44]
8. Write abuse complaint handling procedures[44]
9. Create SOCKS proxy client configuration guide[46]
10. Write security hardening documentation[47]
11. Create network configuration guide[48][49]
12. Create FAQ based on common questions
13. Add inline code comments for clarity
14. Create architecture diagrams
15. Record video walkthrough (optional)

## Project File Structure

```
anon-relay-ansible-deployment/
├── .github/
│   └── workflows/
│       └── ci.yml                    # GitHub Actions CI/CD
├── .gitignore                        # Git ignore patterns
├── AGENTS.md                         # Universal AI agent instructions
├── CLAUDE.md                         # Claude-specific agent rules
├── COPILOT.md                        # GitHub Copilot instructions
├── DEVELOPMENT_PLAN.md               # This file
├── README.md                         # Project overview and usage
├── CONTRIBUTING.md                   # Contribution guidelines
├── SECURITY.md                       # Security policy
├── CHANGELOG.md                      # Version history
├── LICENSE                           # Project license
├── ansible.cfg                       # Ansible configuration
├── requirements.yml                  # Ansible Galaxy requirements
├── inventory.ini                     # Sample inventory file
├── site.yml                          # Main deployment playbook
├── deploy_standard.yml               # Standard relay playbook
├── deploy_exit.yml                   # Exit relay playbook
├── deploy_socks.yml                  # SOCKS proxy playbook
├── update.yml                        # Update playbook
├── remove.yml                        # Cleanup playbook
├── harden.yml                        # Security hardening playbook
├── monitor.yml                       # Monitoring playbook
├── group_vars/
│   ├── all.yml                       # Global variables
│   ├── standard_relays.yml           # Standard relay variables
│   ├── exit_relays.yml               # Exit relay variables
│   └── socks_proxies.yml             # SOCKS proxy variables
├── host_vars/
│   ├── relay1.example.com.yml        # Host-specific variables
│   └── exit1.example.com.yml         # Exit relay specific
├── roles/
│   ├── docker_setup/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── debian.yml            # Debian/Ubuntu tasks
│   │   │   └── redhat.yml            # RHEL/Fedora tasks
│   │   ├── handlers/
│   │   │   └── main.yml              # Service handlers
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   ├── vars/
│   │   │   └── main.yml              # Role variables
│   │   ├── meta/
│   │   │   └── main.yml              # Role metadata
│   │   └── README.md                 # Role documentation
│   ├── anon_relay_base/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── directories.yml       # Directory setup
│   │   │   ├── configuration.yml     # Config file deployment
│   │   │   └── container.yml         # Docker container tasks
│   │   ├── handlers/
│   │   │   └── main.yml              # Container handlers
│   │   ├── templates/
│   │   │   ├── relay.yaml.j2         # Docker Compose template
│   │   │   ├── anonrc_base.j2        # Base Anon config template
│   │   │   └── config.j2             # Nyx config template
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   ├── vars/
│   │   │   └── main.yml              # Role variables
│   │   ├── meta/
│   │   │   └── main.yml              # Role metadata
│   │   └── README.md                 # Role documentation
│   ├── anon_relay_standard/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── configure.yml         # Standard relay config
│   │   │   └── validate.yml          # Validation tasks
│   │   ├── templates/
│   │   │   └── anonrc_standard.j2    # Standard relay config
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   └── README.md                 # Role documentation
│   ├── anon_relay_exit/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── configure.yml         # Exit relay config
│   │   │   ├── exit_notice.yml       # Exit notice deployment
│   │   │   ├── dos_mitigation.yml    # DoS protection
│   │   │   └── validate.yml          # Validation tasks
│   │   ├── templates/
│   │   │   ├── anonrc_exit.j2        # Exit relay config
│   │   │   └── exit-notice.html.j2   # Exit notice template
│   │   ├── files/
│   │   │   └── abuse_response.txt    # Abuse complaint template
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   └── README.md                 # Role documentation
│   ├── anon_relay_socks/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── configure.yml         # SOCKS config
│   │   │   └── validate.yml          # Validation tasks
│   │   ├── templates/
│   │   │   └── anonrc_socks.j2       # SOCKS proxy config
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   └── README.md                 # Role documentation
│   ├── anon_relay_monitor/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── install_nyx.yml       # Nyx installation
│   │   │   ├── health_check.yml      # Health verification
│   │   │   └── orport_check.yml      # ORPort reachability
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   ├── meta/
│   │   │   └── main.yml              # Role metadata
│   │   └── README.md                 # Role documentation
│   ├── security_hardening/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── system_updates.yml    # Update configuration
│   │   │   ├── ssh_hardening.yml     # SSH security
│   │   │   ├── firewall.yml          # UFW configuration
│   │   │   ├── fail2ban.yml          # Intrusion prevention
│   │   │   └── services.yml          # Service management
│   │   ├── templates/
│   │   │   ├── sshd_config.j2        # SSH configuration
│   │   │   ├── jail.local.j2         # Fail2Ban config
│   │   │   └── issue.net.j2          # Login banner
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   └── README.md                 # Role documentation
│   ├── network_config/
│   │   ├── tasks/
│   │   │   ├── main.yml              # Main task file
│   │   │   ├── port_forward.yml      # Port forwarding setup
│   │   │   ├── ipv6.yml              # IPv6 configuration
│   │   │   ├── firewall_rules.yml    # Firewall configuration
│   │   │   └── validation.yml        # Network validation
│   │   ├── defaults/
│   │   │   └── main.yml              # Default variables
│   │   └── README.md                 # Role documentation
│   ├── preflight_checks/
│   │   ├── tasks/
│   │   │   └── main.yml              # System requirement checks
│   │   └── README.md                 # Role documentation
│   └── health_checks/
│       ├── tasks/
│       │   └── main.yml              # Post-deployment validation
│       └── README.md                 # Role documentation
├── examples/
│   ├── standard-relay-basic.yml      # Basic standard relay
│   ├── standard-relay-ipv6.yml       # IPv6 enabled relay
│   ├── standard-relay-myfamily.yml   # Family configuration
│   ├── exit-relay-basic.yml          # Basic exit relay
│   ├── exit-relay-hardened.yml       # Hardened exit relay
│   ├── exit-relay-reduced-policy.yml # Reduced exit policy
│   ├── socks-proxy-home.yml          # Home SOCKS proxy
│   ├── socks-proxy-office.yml        # Office SOCKS proxy
│   └── multi-relay.yml               # Multiple relay deployment
├── docs/
│   ├── architecture.md               # Architecture overview
│   ├── configuration.md              # Configuration guide
│   ├── standard-relay-guide.md       # Standard relay guide
│   ├── exit-relay-guide.md           # Exit relay guide
│   ├── socks-proxy-guide.md          # SOCKS proxy guide
│   ├── security-hardening.md         # Security guide
│   ├── network-configuration.md      # Network setup guide
│   ├── legal-considerations.md       # Legal guide (exit relays)
│   ├── abuse-handling.md             # Abuse complaint guide
│   ├── troubleshooting.md            # Troubleshooting guide
│   └── faq.md                        # Frequently asked questions
└── tests/
    ├── inventory/
    │   ├── test_standard.ini         # Standard relay tests
    │   ├── test_exit.ini             # Exit relay tests
    │   └── test_socks.ini            # SOCKS proxy tests
    ├── test_standard.yml             # Standard relay test playbook
    ├── test_exit.yml                 # Exit relay test playbook
    └── test_socks.yml                # SOCKS proxy test playbook
```

## Variable Structure

### Global Variables (group_vars/all.yml)
```yaml
---
# Docker Configuration
docker_edition: 'ce'
docker_package: "docker-{{ docker_edition }}"
docker_compose_version: "latest"

# User Configuration
anon_user: "anond"
anon_uid: 100
anon_gid: 101

# Base Directories
anon_base_dir: "/opt/anon"
compose_dir: "/opt/compose-files"

# Common Settings
anon_accept_terms: true  # Required for v0.4.9.7-live+
anon_docker_image: "svforte/anon:latest"
```

### Standard Relay Variables (group_vars/standard_relays.yml)
```yaml
---
# Relay Type
anon_relay_type: "standard"

# Standard Relay Configuration
anon_relay_nickname: "MyStandardRelay"
anon_relay_contact: "operator@example.com"
anon_relay_or_port: 9001
anon_relay_socks_port: 0  # Disabled for relay
anon_relay_bandwidth_rate: "100 MBytes"
anon_relay_bandwidth_burst: "200 MBytes"

# IPv6 Configuration
anon_ipv6_enabled: true
anon_ipv6_only: false

# Family Configuration (optional)
anon_relay_myfamily: []  # List of fingerprints

# Network
anon_port_forward_required: true

# Firewall
anon_firewall_enabled: true
anon_ssh_port: 22
```

### Exit Relay Variables (group_vars/exit_relays.yml)
```yaml
---
# Relay Type
anon_relay_type: "exit"

# Legal Acknowledgment (REQUIRED)
anon_exit_legal_acknowledged: false  # Must be set to true

# Exit Relay Configuration
anon_relay_nickname: "MyExitRelay"
anon_relay_contact: "abuse@example.com"  # Non-personal email
anon_relay_or_port: 9001
anon_relay_dir_port: 80
anon_relay_socks_port: 0
anon_relay_exit_relay: 1
anon_relay_ipv6_exit: 0

# Bandwidth
anon_relay_bandwidth_rate: "200 MBytes"
anon_relay_bandwidth_burst: "400 MBytes"

# Exit Policy (Reduced/Restrictive)
anon_relay_exit_policy:
  - "reject *:25"      # SMTP
  - "reject *:587"     # SMTP Submission
  - "reject *:465"     # SMTPS
  - "reject *:2525"    # SMTP Alternative
  - "reject *:3389"    # RDP
  - "reject *:23"      # Telnet
  - "reject *:3128"    # HTTP Proxy
  - "reject *:5900"    # VNC
  - "reject *:9999"    # Custom
  - "accept *:*"       # Accept everything else

# Exit Notice
anon_exit_notice_email: "abuse@example.com"
anon_exit_notice_enabled: true

# DoS Mitigation
anon_dos_circuit_creation_enabled: true
anon_dos_circuit_creation_burst: 30
anon_dos_circuit_creation_rate: 3
anon_dos_connection_enabled: true
anon_dos_stream_creation_enabled: true

# Reverse DNS
anon_reverse_dns_hostname: "anon-exit-1.example.com"

# Security Hardening (Enhanced for exit relays)
anon_ssh_port: 52231  # Non-standard port
anon_ssh_root_login: false
anon_ssh_password_auth: false
anon_fail2ban_enabled: true
anon_disk_encryption_required: true  # Document only
```

### SOCKS Proxy Variables (group_vars/socks_proxies.yml)
```yaml
---
# Relay Type
anon_relay_type: "socks"

# SOCKS Proxy Configuration
anon_socks_port: 9050
anon_socks_bind_address: "192.168.1.10"  # LAN IP
anon_socks_policy_accept: "192.168.1.0/24"  # LAN subnet

# Disable Relay Functionality
anon_relay_or_port: 0
anon_relay_dir_port: 0

# Experimental Warning
anon_socks_experimental: true

# Network (No port forwarding needed)
anon_port_forward_required: false

# Firewall (LAN access only)
anon_firewall_lan_only: true
```

## Technical Requirements

### System Requirements
- **Operating System:** Ubuntu 20.04+, Debian 10+, Fedora 35+
- **Architecture:** amd64 or arm64
- **RAM:**
  - Standard Relay: Minimum 512MB, Recommended 1GB+
  - Exit Relay: Minimum 1GB, Recommended 2GB+
  - SOCKS Proxy: Minimum 256MB, Recommended 512MB+
- **Disk Space:** Minimum 5GB free space
- **Network:**
  - Standard/Exit Relay: Public IP address with open ports (9001, optionally 80 for exit)
  - SOCKS Proxy: Local network only
- **Bandwidth:**
  - Standard Relay: Minimum 75 KBytes (600 kbits), Recommended 250 KBytes (2 mbits)+
  - Exit Relay: Minimum 250 KBytes (2 mbits), Recommended 1 MByte+
  - SOCKS Proxy: Depends on usage

### Software Requirements
- **Ansible:** 2.15+ (controller node)
- **Python:** 3.8+ on control node
- **SSH:** OpenSSH server on target nodes
- **Sudo:** Passwordless sudo access recommended

### Ansible Collections Required
- community.docker (for Docker modules)
- ansible.posix (for advanced file operations)

### Exit Relay Specific Requirements[42][44]
- Relay-friendly ISP or hosting provider
- Non-personal email for abuse complaints
- Legal consultation completed
- Reverse DNS (PTR and A records) configured
- Dedicated server (not shared/VPS without abuse handling)
- NOT hosted at home or private premises

## Testing Strategy

### Unit Tests
- Test each role independently using Molecule
- Verify task idempotency
- Test variable precedence
- Validate template rendering
- Test role for each relay type

### Integration Tests
- Full deployment workflow from clean system for each relay type
- Multi-node deployment scenarios
- Update and rollback procedures
- Removal and cleanup verification
- Security hardening validation

### Platform Tests
- Ubuntu 20.04 LTS (amd64) - All relay types
- Ubuntu 22.04 LTS (amd64) - All relay types
- Debian 11 (amd64) - Standard and exit relays
- Debian 11 (arm64) - Standard relay
- Fedora 38 (amd64) - Standard relay
- Raspberry Pi OS (arm64) - Standard relay and SOCKS proxy

### Security Tests
- SSH hardening verification
- Firewall rule validation
- Fail2Ban functionality
- Exit relay DoS mitigation
- Service disable verification

### Performance Tests
- Deployment time benchmarks per relay type
- Resource usage monitoring
- Concurrent deployment scaling
- ORPort reachability time

## CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  lint:
    - ansible-lint
    - yamllint
  test:
    matrix:
      relay_type: [standard, exit, socks]
      distribution: [ubuntu2204, debian11, fedora38]
    - Molecule test scenarios
    - Multi-distribution matrix
  security:
    - Security linting
    - Hardening validation
  deploy:
    - Test deployment on staging
```

## Success Criteria

### Phase Completion Criteria
- [ ] All tasks in each phase completed
- [ ] Code reviewed by at least one team member
- [ ] Documentation updated for all relay types
- [ ] Tests passing for all relay types
- [ ] No blocking issues
- [ ] Security requirements met

### Project Completion Criteria
- [ ] All playbooks execute successfully for all relay types
- [ ] Idempotent execution verified
- [ ] All distributions tested
- [ ] Documentation complete and accurate for all relay types
- [ ] CI/CD pipeline operational
- [ ] Security review completed
- [ ] Exit relay legal documentation complete
- [ ] Community feedback incorporated
- [ ] Example configurations working

## Risk Management

### Technical Risks
1. **Distribution Compatibility:** Different package managers and init systems
   - *Mitigation:* Abstract distribution-specific tasks into separate files

2. **Docker Version Conflicts:** Existing Docker installations may conflict
   - *Mitigation:* Add pre-flight checks and conflict resolution tasks

3. **Network Restrictions:** Firewalls blocking required ports
   - *Mitigation:* Include firewall configuration and verification tasks[49]

4. **Permission Issues:** Insufficient privileges on target systems
   - *Mitigation:* Clear documentation of required permissions

5. **Exit Relay Legal Risks:** Abuse complaints and legal challenges[44]
   - *Mitigation:* Comprehensive legal documentation, abuse response templates

6. **SOCKS Proxy Security:** Exposure beyond intended network[46]
   - *Mitigation:* Strict firewall rules, clear security warnings

### Operational Risks
1. **Configuration Errors:** Incorrect relay configuration could prevent operation
   - *Mitigation:* Comprehensive validation and health checks[51]

2. **Token Acceptance:** Terms and conditions must be accepted
   - *Mitigation:* Explicit variable requirement with documentation

3. **Resource Constraints:** Systems with insufficient resources
   - *Mitigation:* Pre-deployment resource verification

4. **Exit Relay Abuse:** High volume of abuse complaints[44]
   - *Mitigation:* Reduced exit policy, abuse response procedures

5. **ORPort Reachability:** Port forwarding or CGNAT issues[51]
   - *Mitigation:* Automated verification and troubleshooting guides

## Timeline

| Phase | Duration | Focus | End Goal |
|-------|----------|-------|----------|
| Phase 1: Structure & Docs | 1 week | Setup and planning | Complete project structure |
| Phase 2: Docker Role | 1 week | Docker installation | Working Docker role |
| Phase 3: Base Relay Role | 2 weeks | Base relay setup | Base relay deployment |
| Phase 4: Standard Relay | 1 week | Standard config | Standard relay working |
| Phase 5: Exit Relay | 1 week | Exit config + legal | Exit relay with security |
| Phase 6: SOCKS Proxy | 1 week | SOCKS config | SOCKS proxy working |
| Phase 7: Monitoring | 1 week | Health checks | Monitoring operational |
| Phase 8: Security | 1 week | Hardening | Security measures applied |
| Phase 9: Network Config | 1 week | Network setup | Network fully configured |
| Phase 10: Playbooks | 1 week | Main orchestration | All playbooks complete |
| Phase 11: Testing | 1 week | Validation | All tests passing |
| Phase 12: Documentation | 1 week | User guides | Complete documentation |

**Total Duration:** 12 weeks (3 months)

## Maintenance Plan

### Regular Updates
- Monthly Ansible version compatibility checks
- Quarterly security audits
- Review Anyone Protocol documentation for changes
- Monitor community feedback and abuse reports
- Annual documentation review

### Version Control
- Semantic versioning (MAJOR.MINOR.PATCH)
- Tagged releases for stable versions
- Maintain CHANGELOG.md with relay type changes
- Document breaking changes clearly

### Community Engagement
- Monitor GitHub issues and pull requests
- Respond to community feedback within 48 hours
- Monthly release cycle for non-breaking changes
- Maintain example configurations
- Support exit relay operators with legal/operational guidance[44]

## Resources

### Documentation References
- [Anyone Protocol Documentation](https://docs.anyone.io)[41]
- [Docker Installation (Anyone Docs)](https://docs.anyone.io/relay/start/install-anon-on-linux/docker)[41]
- [Exit Relay Configuration](https://docs.anyone.io/relay/start/roles/exit)[42]
- [SOCKS Proxy Setup](https://docs.anyone.io/relay/network/socks)[46]
- [Port Forwarding Guide](https://docs.anyone.io/relay/network/port-forward)[48]
- [Firewall Configuration](https://docs.anyone.io/relay/network/firewall)[49]
- [IPv4/IPv6 Configuration](https://docs.anyone.io/relay/network/configure-ipv4-and-ipv6)[50]
- [VPS Hardening Guide](https://docs.anyone.io/security/vps-hardening-and-best-practices)[47]
- [Relay Standards](https://docs.anyone.io/relay/guidelines/standards)[43]
- [Exit Guidelines](https://docs.anyone.io/relay/guidelines/exit-guidelines)[44]
- [ORPort Troubleshooting](https://docs.anyone.io/relay/troubleshooting/orport)[51]
- [DoS Mitigation](https://docs.anyone.io/relay/troubleshooting/dos-mitigation)[52]
- [Anon Manual](https://docs.anyone.io/sdk-integrations/native-sdk/manual)[43]
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Docker Documentation](https://docs.docker.com/engine/install/)
- [Ansible Docker Modules](https://docs.ansible.com/ansible/latest/collections/community/docker/)

### Tools & Dependencies
- Ansible 2.15+
- Docker CE 20.10+
- Docker Compose V2
- Molecule (for testing)
- ansible-lint (for linting)
- yamllint (for YAML validation)
- Nyx (relay monitoring)[41]
- UFW (firewall)[47][49]
- Fail2Ban (intrusion prevention)[47]

### Community Resources
- Anyone Protocol GitHub: https://github.com/anyone-protocol
- Anyone Discord: VPS Relays discussion thread[44]
- DePINHub.io: Anyone Explorer Map[44]
- Ansible Galaxy: https://galaxy.ansible.com
- Docker Hub: https://hub.docker.com

## Appendix

### Key Commands Reference

```bash
# === STANDARD RELAY DEPLOYMENT ===
# Deploy standard relay
ansible-playbook -i inventory.ini deploy_standard.yml

# Deploy to specific host
ansible-playbook -i inventory.ini deploy_standard.yml --limit relay1.example.com

# === EXIT RELAY DEPLOYMENT ===
# Deploy exit relay (requires legal acknowledgment)
ansible-playbook -i inventory.ini deploy_exit.yml

# Deploy with extra vars
ansible-playbook -i inventory.ini deploy_exit.yml \
  -e "anon_exit_legal_acknowledged=true" \
  -e "anon_exit_notice_email=abuse@example.com"

# === SOCKS PROXY DEPLOYMENT ===
# Deploy SOCKS proxy
ansible-playbook -i inventory.ini deploy_socks.yml

# === GENERAL OPERATIONS ===
# Deploy only Docker role
ansible-playbook -i inventory.ini site.yml --tags docker

# Update existing relays
ansible-playbook -i inventory.ini update.yml

# Apply security hardening
ansible-playbook -i inventory.ini harden.yml

# Check configuration without changes
ansible-playbook -i inventory.ini site.yml --check

# Verbose output for debugging
ansible-playbook -i inventory.ini site.yml -vvv

# Remove relay deployment
ansible-playbook -i inventory.ini remove.yml

# === MONITORING ===
# Check ORPort reachability
ansible relays -i inventory.ini -m shell -a "docker logs anon-relay | grep 'Self-testing'"

# View relay status with Nyx
ssh relay1.example.com
sudo nyx -s /opt/anon/run/anon/control

# === TROUBLESHOOTING ===
# Check relay logs
ansible relays -i inventory.ini -m shell -a "docker logs anon-relay --tail 50"

# Check container status
ansible relays -i inventory.ini -m shell -a "docker ps | grep anon"

# Check firewall rules
ansible relays -i inventory.ini -m shell -a "sudo ufw status verbose"

# Test ORPort connectivity
ansible relays -i inventory.ini -m shell -a "nc -zv <relay_ip> 9001"
```

### Relay Type Comparison

| Feature | Standard Relay | Exit Relay | SOCKS Proxy |
|---------|----------------|------------|-------------|
| **Routes Anonymous Traffic** | ✅ Yes | ✅ Yes | ✅ Yes |
| **IP Visible to Destinations** | ❌ No | ✅ Yes | ❌ No (local use) |
| **Earns ANYONE Tokens** | ✅ Yes | ✅ Yes | ❌ No |
| **Public Internet Access** | ✅ Yes | ✅ Yes | ❌ No |
| **Home Hosting Suitable** | ✅ Yes | ❌ NO | ✅ Yes |
| **Legal Considerations** | Low | High | Low |
| **Abuse Complaints** | Rare | Common | None |
| **Port Forwarding Required** | ✅ Yes | ✅ Yes | ❌ No |
| **Reverse DNS Recommended** | Optional | **Required** | N/A |
| **Maintenance Level** | Low | High | Low |
| **Bandwidth Requirement** | 600 kbps+ | 2 mbps+ | Varies |
| **RAM Requirement** | 512MB+ | 1GB+ | 256MB+ |
| **Security Hardening** | Standard | Enhanced | Standard |
| **DoS Mitigation** | Optional | **Required** | Optional |

### Glossary

- **Anon:** The binary executable for Anyone Protocol relay nodes[41][43]
- **Relay:** A node in the Anyone network that routes encrypted traffic[41]
- **Exit Relay:** Final relay node where traffic exits to public internet[42][44]
- **Middle Relay:** Standard relay that routes traffic within the network[43]
- **Guard Relay:** Entry point relay into the Anyone network[44]
- **SOCKS Proxy:** Local proxy server for LAN devices to use Anyone network[46]
- **Nyx:** A terminal-based monitoring tool for Anon relays[41]
- **anonrc:** Main configuration file for Anon relay settings[41][43]
- **ORPort:** Onion Router Port where relay listens for connections[41][43][51]
- **DirPort:** Directory Port for serving exit notice and relay information[42]
- **MyFamily:** Configuration declaring related relays under same operator[43]
- **Exit Policy:** Rules defining what traffic an exit relay will handle[42][44]
- **ANYONE Token:** Cryptocurrency token rewarding relay operators[41]
- **DePIN:** Decentralized Physical Infrastructure Networks[44]
- **UFW:** Uncomplicated Firewall for Linux systems[47][49]
- **Fail2Ban:** Intrusion prevention system for SSH and services[47]
- **CGNAT:** Carrier-Grade NAT that prevents direct public IP[51]
- **PTR Record:** Reverse DNS record mapping IP to domain[42]
- **A Record:** Forward DNS record mapping domain to IP[42]

### Exit Relay Operator Checklist

Before deploying an exit relay, complete this checklist:[42][44]

#### Legal & Administrative
- [ ] Consulted with legal expert familiar with intermediary liability
- [ ] Understood local laws regarding exit relay operation
- [ ] Created legal entity (optional but recommended)
- [ ] Contacted local law enforcement (proactive education)
- [ ] Prepared abuse complaint response templates
- [ ] Set up non-personal email for abuse complaints
- [ ] Documented legal protections available

#### Technical Setup
- [ ] Selected relay-friendly ISP or hosting provider
- [ ] Confirmed dedicated IP range availability
- [ ] NOT hosting at home or private premises
- [ ] Configured reverse DNS (PTR and A records)
- [ ] Implemented restrictive exit policy
- [ ] Deployed exit notice HTML page
- [ ] Configured DoS mitigation settings
- [ ] Applied security hardening measures

#### Security Hardening
- [ ] SSH port changed from default 22
- [ ] Root login disabled via SSH
- [ ] SSH key authentication only (password disabled)
- [ ] UFW firewall configured and enabled
- [ ] Fail2Ban installed and monitoring
- [ ] Disk encryption configured
- [ ] System updates automated
- [ ] Unnecessary services disabled
- [ ] Login banners configured
- [ ] Security audit logging enabled

#### Network Configuration
- [ ] Port forwarding configured for ORPort (9001)
- [ ] Port forwarding configured for DirPort (80)
- [ ] Firewall rules allowing necessary ports
- [ ] ORPort reachability verified
- [ ] IPv6 configuration (if available)
- [ ] Bandwidth limits configured appropriately

#### Monitoring & Maintenance
- [ ] Nyx monitoring tool installed
- [ ] Log monitoring configured
- [ ] ORPort reachability monitoring setup
- [ ] Abuse complaint monitoring process established
- [ ] Regular update schedule defined
- [ ] Backup procedures documented
- [ ] Emergency contact information prepared

#### Documentation
- [ ] Abuse complaint procedures documented
- [ ] Legal response templates prepared
- [ ] Technical documentation maintained
- [ ] Emergency shutdown procedures documented
- [ ] ISP contact information documented

---

**Document Version:** 2.0.0
**Last Updated:** 2025-10-27
**Maintained By:** Development Team
**Status:** Active Development

**Major Changes from v1.0.0:**
- Added exit relay support with comprehensive legal and security guidance
- Added SOCKS proxy support for local network use
- Expanded security hardening phase with VPS best practices
- Added network configuration phase for port forwarding and IPv6
- Restructured roles to support multiple relay types
- Added DoS mitigation configuration
- Enhanced documentation with relay type comparison
- Added exit relay operator checklist
- Expanded timeline to 12 weeks to accommodate new features
