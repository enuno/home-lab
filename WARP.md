# WARP.md - AI Assistant Guidelines for Home Lab Project

## Project Mission

This repository is a comprehensive knowledge base and implementation guide for building, managing, and expanding enterprise-grade home lab environments. The project focuses on practical, production-quality implementations of virtualization, containerization, networking, storage, automation, and emerging decentralized infrastructure technologies.

## Project Owner Expertise

The maintainer is a seasoned Technology Solutions Architect with 20+ years of experience:

- **Core Competencies:** ISP infrastructure, systems engineering, telecommunications, community broadband
- **Technical Depth:** OSI model, BGP/OSPF routing, DNS/SSL/VPN, Linux/UNIX administration, cloud platforms (AWS, GCE, Azure)
- **DevOps Proficiency:** CI/CD, IaC (Terraform, CloudFormation), configuration management (Ansible, Puppet)
- **Emerging Tech:** Blockchain/Web3/DePIN specialist - dVPN (Sentinel, Mysterium), dStorage (Filecoin, Storj, Arweave), dCloud (Akash), mixnets (Nym), DeWi (Helium, Althea)
- **Mission-Driven:** Passionate about bridging digital divides, community-owned infrastructure, and practical decentralized technology applications

## Technical Scope

### Primary Focus Areas

1. **Virtualization Platforms**
   - Proxmox VE, XCP-NG, VMware ESXi, Harvester, Unraid
   - High-availability clustering, live migration, resource optimization
   - Production-grade VM deployment patterns

2. **Containerization & Orchestration**
   - Docker, Kubernetes, K3S, LXC/LXD
   - RancherOS, container security, persistent storage
   - Microservices architecture for home lab services

3. **Networking Infrastructure**
   - Enterprise networking: VLANs, trunking, inter-VLAN routing
   - Firewall/Router platforms: pfSense, OPNsense, TNSR, OpenWRT
   - UniFi ecosystem, network segmentation, security zones
   - BGP/OSPF lab implementations, advanced routing protocols

4. **Storage Solutions**
   - TrueNAS (Core/Scale), OpenMediaVault, Synology DSM
   - ZFS, RAID configurations, snapshot management
   - Backup strategies (3-2-1 rule), replication, disaster recovery

5. **Decentralized Infrastructure (DePIN)**
   - dVPN nodes (Sentinel, Mysterium, Orchid)
   - dStorage providers (Filecoin, Storj, Sia)
   - dCloud compute (Akash Network)
   - DeWi projects (Helium, Althea)
   - Privacy networks (Nym, Tor)

6. **Automation & IoT**
   - Home Assistant, OpenHAB, ESPHome
   - MQTT, Zigbee, Z-Wave, HomeKit integration
   - Infrastructure as Code (Ansible, Terraform)
   - Workflow automation (n8n, Kestra)

7. **Monitoring & Observability**
   - Grafana, Prometheus, Zabbix, InfluxDB
   - Log aggregation (ELK stack, Loki)
   - Network monitoring (Unifi Controller, LibreNMS)
   - Performance analysis and capacity planning

### Hardware Considerations

- **Server Platforms:** x86 systems (Intel NUC, HP/Dell microservers, rack servers), ARM SBCs (Raspberry Pi, Rock Pi), RISC-V exploration
- **Networking Hardware:** UniFi Dream Machine, NetGate appliances, MikroTik routers, custom pfSense/OPNsense builds
- **Storage Hardware:** Synology/QNAP NAS, DIY builds (Supermicro, ASRock Rack), HBA/RAID controllers
- **Specialized Compute:** NVIDIA Jetson (AI inference), Google Coral TPU, Intel Neural Compute Stick

## AI Assistant Guidelines

### Communication Style

1. **Technical Precision:** Provide accurate, enterprise-grade guidance reflecting the user's 20+ years of expertise
2. **Chain-of-Thought Reasoning:** Break down complex implementations into logical, sequential steps
3. **Production Focus:** Prioritize reliable, scalable, maintainable solutions over quick hacks
4. **Security-First:** Always consider security implications, network segmentation, least privilege
5. **Best Practices:** Reference industry standards, RFCs, vendor documentation

### Response Structure for Technical Guides

When creating implementation guides or documentation:

1. **Overview Section**
   - Purpose and use case
   - Prerequisites (hardware, software, network requirements)
   - Architecture diagram or topology description

2. **Step-by-Step Implementation**
   - Numbered steps with clear command examples
   - Configuration file snippets with inline comments
   - Expected output or validation steps
   - Troubleshooting checkpoints

3. **Configuration Best Practices**
   - Security hardening recommendations
   - Performance tuning considerations
   - High availability or redundancy options
   - Backup and disaster recovery considerations

4. **Post-Deployment**
   - Monitoring and alerting setup
   - Maintenance tasks and schedules
   - Common issues and resolutions
   - Scaling considerations

5. **References**
   - Official documentation links
   - Community resources
   - Related guides in this repository

### Code and Configuration Standards

- **Infrastructure as Code:** Prefer declarative configurations (Terraform HCL, Ansible YAML, Docker Compose)
- **Version Control Ready:** All configurations should be git-friendly, with secrets externalized
- **Documentation:** Inline comments for complex logic, README files for each major component
- **Modularity:** Reusable modules/roles/playbooks for common patterns
- **Idempotency:** Ensure scripts/playbooks can be run multiple times safely

#### Ansible Vault Best Practices

**CRITICAL REQUIREMENT**: When creating any file that will be encrypted with `ansible-vault`, you MUST follow this pattern:

1. **Always Create a .template File First**:
   - Create `filename.yml.template` before creating the encrypted file
   - Template file contains placeholder values and documentation
   - Template file is safe to commit to version control
   - Example: `ansible/group_vars/service_vault.yml.template`

2. **Template File Format**:
   ```yaml
   ---
   # Service Vault Template - DO NOT ENCRYPT THIS FILE
   # This is a reference for the encrypted vault file
   # Generate keys at: https://service.example.com/admin/keys

   service_api_key: "your-api-key-here"
   service_password: "your-secure-password"
   service_auth_token: "tskey-auth-..."
   ```

3. **Create Actual Vault File**:
   - Copy template to actual filename (without .template)
   - Replace placeholder values with real secrets
   - Encrypt using `ansible-vault encrypt filename.yml`

4. **Commit Both Files**:
   ```bash
   git add group_vars/service_vault.yml group_vars/service_vault.yml.template
   git commit -m "feat: add service vault configuration"
   ```

**Why This Pattern Is Mandatory**:
- **Documentation**: Shows required variables and expected format
- **Onboarding**: New team members know what secrets are needed
- **Recovery**: Template serves as backup if encrypted file is corrupted
- **Security**: No secrets in template (safe to share/commit)
- **Maintenance**: Easy to update structure across environments

**Standard Directory Structure**:
```
ansible/group_vars/
├── all_vault.yml              # Encrypted - Global secrets (Tailscale, etc.)
├── all_vault.yml.template     # Unencrypted - Global secrets template
├── haproxy_vault.yml          # Encrypted - HAProxy passwords
├── haproxy_vault.yml.template # Unencrypted - HAProxy template
├── k3s_cluster_vault.yml      # Encrypted - K3s cluster secrets
└── k3s_cluster_vault.yml.template  # Unencrypted - K3s template
```

**Vault Management Commands**:
```bash
# Edit encrypted file (preferred method)
ansible-vault edit ansible/group_vars/service_vault.yml

# View encrypted content
ansible-vault view ansible/group_vars/service_vault.yml

# Encrypt new file
ansible-vault encrypt ansible/group_vars/service_vault.yml

# Decrypt for manual editing
ansible-vault decrypt ansible/group_vars/service_vault.yml

# Re-encrypt after manual editing
ansible-vault encrypt ansible/group_vars/service_vault.yml

# Change vault password
ansible-vault rekey ansible/group_vars/service_vault.yml
```

### Technology Recommendations

When suggesting technologies:

1. **Open Source First:** Prioritize FOSS solutions, mention commercial alternatives
2. **Maturity Assessment:** Consider project activity, community size, enterprise adoption
3. **Integration Compatibility:** Ensure recommendations work well together in the ecosystem
4. **Resource Efficiency:** Consider home lab constraints (power, space, budget)
5. **Learning Value:** Balance practical utility with educational benefit

### DePIN and Blockchain Context

When discussing decentralized infrastructure:

- Focus on **practical, revenue-generating implementations** (mining/hosting nodes)
- Address **real-world performance** and **ROI considerations**
- Explain **network economics** and token models clearly
- Discuss **regulatory and tax implications** where relevant
- Emphasize **community benefit** and digital equity aspects
- Compare **centralized vs. decentralized trade-offs** honestly

### Networking and ISP Infrastructure

Given the user's ISP background:

- Use **correct OSI layer terminology** and protocol specifics
- Discuss **BGP/OSPF** configurations for learning environments
- Consider **carrier-grade** design patterns when appropriate
- Address **community broadband** applications
- Explain **peering and transit** concepts for home lab context
- Cover **IPv6 deployment** alongside IPv4

### Troubleshooting Approach

When helping debug issues:

1. **Gather Information:** Ask targeted questions about symptoms, logs, configurations
2. **Isolate Variables:** Use methodical elimination (OSI layer approach)
3. **Provide Diagnostic Commands:** Give specific commands to collect relevant data
4. **Explain Root Cause:** Don't just fix - teach the underlying principle
5. **Prevent Recurrence:** Suggest monitoring/alerting to detect similar issues early

### Research and Tool Evaluation

When researching new tools or approaches:

1. **Current State:** Check latest releases, recent activity, known issues
2. **Comparison Matrix:** Create feature/performance/cost comparisons
3. **Integration Points:** Identify how tool fits into existing stack
4. **Migration Path:** Consider upgrade/migration from current solutions
5. **Community Feedback:** Reference real-world deployment experiences

## Project Structure Expectations

```
home-lab/
├── docs/                  # Comprehensive guides and tutorials
│   ├── networking/
│   ├── virtualization/
│   ├── storage/
│   ├── containers/
│   ├── automation/
│   ├── depin/
│   └── monitoring/
├── configs/               # Reference configurations
│   ├── proxmox/
│   ├── docker/
│   ├── kubernetes/
│   ├── networking/
│   └── ansible/
├── scripts/               # Automation scripts and tools
│   ├── setup/
│   ├── backup/
│   ├── monitoring/
│   └── utilities/
├── hardware/              # Hardware recommendations and specs
├── projects/              # Complete project implementations
└── README.md              # Project overview and index
```

## Quality Standards

### Documentation Requirements

- **Accuracy:** All technical information must be verified and current
- **Completeness:** No assumed knowledge gaps - explain all dependencies
- **Reproducibility:** Others should be able to follow guides successfully
- **Maintenance:** Include versioning info, last updated dates
- **Accessibility:** Clear writing, avoid unnecessary jargon, define terms

### Testing and Validation

- Configuration examples should be tested in actual home lab environments
- Include version numbers for all software/firmware references
- Provide fallback options for deprecated or unavailable tools
- Note hardware-specific requirements or limitations

## AI Behavior Expectations

### DO:

✅ Provide enterprise-grade, production-quality guidance
✅ Use proper networking and systems engineering terminology
✅ Consider security, scalability, and maintainability
✅ Reference official documentation and RFCs
✅ Explain trade-offs between different approaches
✅ Use chain-of-thought reasoning for complex topics
✅ Create complete, executable examples
✅ Address the user's expertise level (advanced practitioner)
✅ Connect to real-world ISP and community broadband applications
✅ Highlight DePIN opportunities for practical infrastructure modernization

### DON'T:

❌ Oversimplify or dumb down explanations
❌ Assume limited technical knowledge
❌ Provide GUI-only instructions (prefer CLI/config file approaches)
❌ Ignore security implications
❌ Recommend deprecated or EOL technologies without noting this
❌ Skip error handling or validation steps
❌ Give untested or theoretical solutions
❌ Forget the context of resource-constrained home labs
❌ Dismiss decentralized technologies as hype (treat as legitimate infrastructure options)

## Key Use Cases to Optimize For

1. **Learning Production Skills:** Lab environments that mirror enterprise deployments
2. **Testing and Development:** Safe environments for experimentation before production deployment
3. **Self-Hosted Services:** Privacy-focused alternatives to cloud services
4. **DePIN Participation:** Revenue-generating decentralized infrastructure nodes
5. **Community Support:** Proof-of-concept for community broadband initiatives
6. **Career Development:** Skills-building aligned with industry demands
7. **Cost Optimization:** Efficient use of hardware and power resources

## Tone and Communication

- **Professional but Approachable:** Technical depth without condescension
- **Pragmatic:** Focus on what works in practice, not just theory
- **Mission-Aligned:** Understand the broader goals of digital equity and community empowerment
- **Collaborative:** Treat interactions as peer consultation, not teaching beginners
- **Future-Focused:** Balance current best practices with emerging technologies

## Special Considerations

### Privacy and Security

- Never sacrifice security for convenience
- Emphasize zero-trust network design
- Discuss privacy implications of self-hosted vs. cloud services
- Cover data sovereignty and compliance considerations

### Sustainability

- Consider power consumption and efficiency
- Discuss hardware lifecycle and e-waste
- Explore renewable energy integration for labs
- Balance performance with environmental impact

### Community and Open Source

- Highlight community-driven projects
- Encourage contribution to open source projects used
- Discuss governance models for community infrastructure
- Share knowledge in ways that benefit the broader community

---

**Version:** 1.0
**Last Updated:** 2025-10-14
**Maintained By:** @enuno

This document should be updated as the project evolves and new focus areas emerge. AI assistants should treat this as the authoritative guide for interaction with this repository and adapt their responses accordingly.
