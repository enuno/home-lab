# DEVELOPMENT PLAN: Bitwarden Secrets Manager Migration

## Project Overview

**Project Name:** Ansible Vault to Bitwarden Secrets Manager Migration
**Version:** 1.0.0
**Purpose:** Migrate all secrets from Ansible Vault files to Bitwarden Secrets Manager for centralized, secure secret management across the home-lab infrastructure
**Target Completion:** Q1 2026 (12-16 weeks)
**Current Status:** Planning Phase

## Executive Summary

This home lab infrastructure project is migrating from Ansible Vault-based secret management to Bitwarden Secrets Manager. This migration will provide:

- Centralized secret management across all services and environments
- Machine account-based authentication for automation
- Improved secret rotation and auditing capabilities
- Reduced risk of accidentally committing secrets to version control
- Better secret lifecycle management and organization
- Alignment with production-grade secret management practices

The migration follows a phased approach with parallel operation to ensure zero-downtime and safe rollback capabilities.

## Current State Assessment

### Existing Vault Files Inventory

Based on analysis of `/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible/group_vars/`:

#### Active Encrypted Vault Files
1. **all_vault.yml** (2,623 bytes) - Global secrets across all services
2. **k3s_cluster_vault.yml** (873 bytes) - Kubernetes cluster credentials
3. **pihole_vault.yml** (3,919 bytes) - Pi-hole admin credentials and configuration
4. **rancher_vault.yml** (1,456 bytes) - Rancher bootstrap credentials
5. **ts-recorder_vault.yml** (1,910 bytes) - Tailscale SSH recorder secrets

#### Unencrypted/Template Files
6. **haproxy_vault.yml** (329 bytes) - HAProxy stats password and keepalived auth (UNENCRYPTED)
7. **all_vault.yml.template** (522 bytes) - Template for global secrets
8. **pihole_vault.yml.template** (867 bytes) - Template for Pi-hole secrets
9. **rancher_vault.yml.template** (282 bytes) - Template for Rancher secrets
10. **ts-recorder_vault.yml.template** (1,060 bytes) - Template for Tailscale recorder
11. **tor_exit_nodes_vault.yml.template** (2,134 bytes) - Template for Tor exit nodes

### Secret Usage Patterns

Current variable reference pattern in playbooks and group_vars:
```yaml
# Current Ansible Vault pattern
pihole_admin_password: "{{ vault_pihole_admin_password | default('changeme123') }}"
rancher_bootstrap_password: "{{ vault_rancher_bootstrap_password | default('changeme123') }}"
```

### Infrastructure Context

- **Ansible Version:** 2.19.3 (core)
- **Bitwarden Collection:** bitwarden.secrets v1.0.1 (already installed)
- **Vault Authentication:** `.vault_password` file (gitignored)
- **Deployment Targets:** K3s cluster, Pi-hole, HAProxy, Rancher, Tor relays, Nostr relays, Anon Protocol relays

### Security Gaps Identified

1. **Unencrypted Secrets:** `haproxy_vault.yml` contains plaintext secrets
2. **Vault Password File:** Single point of failure, must be manually distributed
3. **No Secret Rotation:** Difficult to rotate secrets without redeploying
4. **Limited Auditing:** No tracking of secret access or changes
5. **Template Files:** Risk of committing real secrets in template files

## Target Architecture

### Bitwarden Organization Structure

```
Home Lab Organization
├── Projects
│   ├── dev (Development Environment)
│   │   ├── k3s-dev
│   │   ├── services-dev
│   │   └── network-dev
│   ├── staging (Staging/Pre-Production)
│   │   ├── k3s-staging
│   │   ├── services-staging
│   │   └── network-staging
│   └── prod (Production Environment)
│       ├── k3s-prod
│       ├── services-prod
│       ├── network-prod
│       ├── privacy-relays (Tor, Nostr, Anon)
│       └── monitoring
└── Machine Accounts
    ├── ansible-automation (for playbook execution)
    ├── ci-cd-pipeline (for future CI/CD)
    └── backup-restore (for disaster recovery)
```

### Secret Naming Convention

Format: `{environment}-{service}-{secret-type}-{identifier}`

Examples:
- `prod-k3s-cluster-token`
- `prod-pihole-admin-password`
- `prod-rancher-bootstrap-password`
- `prod-haproxy-stats-password`
- `prod-tailscale-auth-key`
- `prod-nostr-relay-db-connection`
- `staging-k3s-cluster-token`

### Authentication Model

```yaml
# Development/Manual Execution
BWS_ACCESS_TOKEN: Set via `bw unlock` or environment variable

# CI/CD Automation
BWS_ACCESS_TOKEN: Injected via GitHub Secrets or environment

# Machine Accounts
- ansible-automation: Read access to prod/* and staging/*
- ci-cd-pipeline: Read access to staging/*, limited prod/*
- backup-restore: Read-only access to all secrets
```

## Migration Phases

### Phase 1: Infrastructure Setup (Week 1-2)

**Objectives:**
- Set up Bitwarden organization and project structure
- Create machine accounts with appropriate permissions
- Install and test Bitwarden CLI and SDK
- Document authentication workflows

**Deliverables:**
- [ ] Bitwarden organization created with projects
- [ ] Machine accounts created (ansible-automation, ci-cd-pipeline, backup-restore)
- [ ] Access tokens generated and securely stored
- [ ] Bitwarden CLI installed on control node
- [ ] Authentication testing completed
- [ ] Documentation: "Bitwarden Setup Guide"

**Tasks:**
1. Create Bitwarden organization (if not exists)
2. Set up projects: dev, staging, prod with sub-projects
3. Create machine accounts with scoped access:
   - ansible-automation: Read access to prod/staging
   - ci-cd-pipeline: Read access to staging, limited prod
   - backup-restore: Read-only all
4. Install Bitwarden CLI: `brew install bitwarden-cli` (macOS)
5. Test authentication: `bw login` and `bw unlock`
6. Verify Ansible collection: `ansible-galaxy collection list | grep bitwarden`
7. Create test secret and verify lookup works
8. Document authentication procedures for team

**Success Criteria:**
- Able to authenticate to Bitwarden from Ansible control node
- Test secret retrieval using `lookup('bitwarden.secrets.lookup', 'test-secret-id')` works
- Machine account tokens generated and tested
- Team members can authenticate manually

### Phase 2: Secret Inventory and Export (Week 2-3)

**Objectives:**
- Decrypt and inventory all Ansible Vault files
- Categorize secrets by environment and service
- Create mapping between vault variables and Bitwarden secret IDs
- Export secrets to secure staging location

**Deliverables:**
- [ ] Complete secret inventory spreadsheet
- [ ] Vault files decrypted to secure staging location
- [ ] Secret categorization by environment/service
- [ ] Mapping document: vault_var -> bitwarden_secret_id
- [ ] Encrypted backup of all current vault files

**Tasks:**
1. Create secure temporary directory: `/tmp/vault-migration/` (encrypted filesystem)
2. Decrypt all vault files:
   ```bash
   ansible-vault decrypt group_vars/all_vault.yml --output=/tmp/vault-migration/all_vault_decrypted.yml
   ansible-vault decrypt group_vars/k3s_cluster_vault.yml --output=/tmp/vault-migration/k3s_decrypted.yml
   ansible-vault decrypt group_vars/pihole_vault.yml --output=/tmp/vault-migration/pihole_decrypted.yml
   ansible-vault decrypt group_vars/rancher_vault.yml --output=/tmp/vault-migration/rancher_decrypted.yml
   ansible-vault decrypt group_vars/ts-recorder_vault.yml --output=/tmp/vault-migration/ts_recorder_decrypted.yml
   ```
3. Parse and inventory all secrets into structured format (CSV/YAML)
4. Categorize secrets:
   - Environment: dev/staging/prod
   - Service: k3s, pihole, rancher, haproxy, tailscale, tor, nostr, anon
   - Type: password, token, key, certificate, connection-string
5. Create mapping spreadsheet with columns:
   - Current vault variable name
   - Secret value (redacted in documentation)
   - Target Bitwarden project
   - Target Bitwarden secret name
   - Target Bitwarden secret ID (to be filled after import)
   - Playbooks/roles that reference this secret
6. Create encrypted backup:
   ```bash
   tar czf vault-backup-$(date +%Y%m%d).tar.gz group_vars/*_vault.yml
   gpg --encrypt --recipient your-email@example.com vault-backup-*.tar.gz
   ```
7. Store backup in secure location (NOT in git repo)

**Success Criteria:**
- All secrets inventoried and categorized
- Complete mapping document created
- Encrypted backup stored securely
- No secrets in plaintext outside secure staging area

### Phase 3: Bitwarden Secret Import (Week 3-4)

**Objectives:**
- Import all secrets into Bitwarden projects
- Assign appropriate access controls
- Generate secret IDs and update mapping document
- Verify all secrets accessible via Bitwarden CLI

**Deliverables:**
- [ ] All secrets imported to Bitwarden
- [ ] Secret IDs documented in mapping spreadsheet
- [ ] Access controls tested and verified
- [ ] Test playbook using Bitwarden lookups successful

**Tasks:**
1. Import secrets to Bitwarden using CLI or SDK:
   ```bash
   # Example secret creation
   bw create item \
     --name "prod-pihole-admin-password" \
     --notes "Pi-hole admin interface password" \
     --organizationid "org-id" \
     --collectionid "prod-services-collection-id" \
     <<< '{"type":1,"name":"prod-pihole-admin-password","notes":"Pi-hole admin password","login":{"password":"actual-password-here"}}'
   ```
2. Organize secrets by project:
   - **prod/k3s-prod:** K3s cluster tokens, certificates
   - **prod/services-prod:** Pi-hole, Rancher, HAProxy credentials
   - **prod/network-prod:** Tailscale auth keys, VPN credentials
   - **prod/privacy-relays:** Tor, Nostr, Anon relay configurations
3. Record Bitwarden secret IDs in mapping spreadsheet
4. Test secret retrieval using Ansible:
   ```yaml
   - name: Test Bitwarden secret lookup
     ansible.builtin.debug:
       msg: "{{ lookup('bitwarden.secrets.lookup', 'secret-id-here') }}"
     no_log: true
   ```
5. Verify access controls by testing with different machine accounts
6. Create test playbook that uses Bitwarden for all secrets
7. Validate test playbook in isolated environment

**Success Criteria:**
- All secrets successfully imported to Bitwarden
- Secret IDs documented and mapped to vault variables
- Test playbook retrieves secrets successfully
- Access controls enforced correctly

### Phase 4: Playbook Migration - Pilot Service (Week 4-5)

**Objectives:**
- Migrate one pilot service (Nostr relay) to Bitwarden lookups
- Test parallel operation with Ansible Vault
- Validate rollback procedures
- Document migration patterns for other services

**Deliverables:**
- [ ] Nostr relay playbook migrated to Bitwarden
- [ ] Parallel operation tested (Bitwarden + Vault fallback)
- [ ] Rollback procedure validated
- [ ] Migration playbook pattern documented

**Tasks:**
1. Choose pilot service: **Nostr relay** (already has Bitwarden comment in config)
2. Update `group_vars/nostr_relay.yml`:
   ```yaml
   # OLD: Vault pattern (kept as fallback)
   # nostr_relay_admin_password: "{{ vault_nostr_admin_password | default('changeme123') }}"

   # NEW: Bitwarden pattern with Vault fallback
   nostr_relay_db_connection: "{{ lookup('bitwarden.secrets.lookup', 'prod-nostr-relay-db-connection', default=vault_nostr_db_connection | default('')) }}"
   ```
3. Update playbook to handle both patterns during transition
4. Test deployment with Bitwarden secrets
5. Test rollback by disabling Bitwarden and using vault fallback
6. Document migration process and any issues encountered
7. Create migration checklist for other services

**Success Criteria:**
- Nostr relay deploys successfully using Bitwarden secrets
- Fallback to Ansible Vault works if Bitwarden unavailable
- Rollback procedure tested and documented
- No service disruption during migration

### Phase 5: Playbook Migration - Core Services (Week 5-8)

**Objectives:**
- Migrate remaining services to Bitwarden lookups
- Maintain parallel operation with vault fallback
- Test all playbooks in staging environment
- Update templates and documentation

**Deliverables:**
- [ ] K3s cluster playbook migrated
- [ ] Pi-hole playbook migrated
- [ ] Rancher playbook migrated
- [ ] HAProxy playbook migrated
- [ ] Tailscale SSH recorder playbook migrated
- [ ] Tor exit node playbook migrated
- [ ] Anon relay playbook migrated
- [ ] All playbooks tested in staging
- [ ] Variable documentation updated

**Service Migration Order:**
1. **Week 5:** K3s cluster (critical infrastructure)
2. **Week 6:** Pi-hole, HAProxy (network services)
3. **Week 7:** Rancher, Tailscale recorder (management services)
4. **Week 8:** Tor, Anon relays (privacy services)

**Migration Pattern per Service:**
```yaml
# group_vars/{service}.yml

# Phase 1: Add Bitwarden lookup with Vault fallback
service_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-{service}-password', default=vault_{service}_password | default('')) }}"

# Phase 2: Set environment variable for BWS authentication
# export BWS_ACCESS_TOKEN="your-machine-account-token"

# Phase 3: Test deployment
# ansible-playbook -i inventory/{service}.ini playbooks/deploy-{service}.yml --check

# Phase 4: Deploy to staging
# ansible-playbook -i inventory/{service}.ini playbooks/deploy-{service}.yml --limit staging

# Phase 5: Deploy to production
# ansible-playbook -i inventory/{service}.ini playbooks/deploy-{service}.yml --limit production
```

**Tasks per Service:**
1. Identify all vault variables used
2. Create corresponding Bitwarden secrets
3. Update group_vars with Bitwarden lookups
4. Update playbooks if needed (add `no_log: true` to secret tasks)
5. Test in check mode
6. Deploy to staging
7. Validate functionality
8. Deploy to production
9. Monitor for issues

**Success Criteria:**
- All services deploy successfully with Bitwarden secrets
- Vault fallback mechanism works for each service
- No service disruptions
- All tests pass in staging before production deployment

### Phase 6: Vault Deprecation (Week 9-10)

**Objectives:**
- Remove vault fallback patterns
- Archive Ansible Vault files
- Update ansible.cfg to remove vault configuration
- Clean up templates and documentation

**Deliverables:**
- [ ] Vault fallback patterns removed from all playbooks
- [ ] Vault files moved to archive directory
- [ ] ansible.cfg updated (vault_password_file removed)
- [ ] .gitignore updated
- [ ] Documentation updated to reflect Bitwarden-only approach

**Tasks:**
1. Verify all services running on Bitwarden secrets for at least 2 weeks
2. Remove vault fallback patterns:
   ```yaml
   # BEFORE
   service_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-password', default=vault_service_password | default('')) }}"

   # AFTER
   service_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-password') }}"
   ```
3. Create vault archive:
   ```bash
   mkdir -p ansible/archive/vault-$(date +%Y%m%d)
   mv group_vars/*_vault.yml ansible/archive/vault-$(date +%Y%m%d)/
   mv group_vars/*_vault.yml.template ansible/archive/vault-$(date +%Y%m%d)/
   ```
4. Update `ansible.cfg`:
   ```ini
   # REMOVE these lines:
   # vault_password_file = .vault_password

   # ADD comment:
   # Secrets now managed via Bitwarden Secrets Manager
   # Authentication via BWS_ACCESS_TOKEN environment variable
   ```
5. Update `.gitignore`:
   ```gitignore
   # OLD vault patterns (keep for safety)
   .vault_password
   *_vault.yml

   # NEW Bitwarden patterns
   .bws_token
   bws_access_token
   ```
6. Update all README.md and documentation to reference Bitwarden
7. Remove `.vault_password` file from all control nodes

**Success Criteria:**
- All vault files archived
- No references to vault variables in active playbooks
- ansible.cfg cleaned up
- Documentation reflects Bitwarden-only state

### Phase 7: Secret Rotation (Week 11-12)

**Objectives:**
- Rotate all migrated secrets
- Validate secret rotation procedures
- Document secret lifecycle management
- Test emergency secret rotation

**Deliverables:**
- [ ] All production secrets rotated
- [ ] Secret rotation playbook created
- [ ] Emergency rotation procedure documented
- [ ] Secret lifecycle policy defined

**Tasks:**
1. Create secret rotation playbook:
   ```yaml
   # playbooks/rotate-secrets.yml
   ---
   - name: Rotate service secrets
     hosts: localhost
     tasks:
       - name: Generate new secret
         ansible.builtin.set_fact:
           new_secret: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"

       - name: Update Bitwarden secret
         ansible.builtin.command:
           cmd: bw update item {{ secret_id }} --password {{ new_secret }}
         no_log: true

       - name: Deploy updated secret to services
         ansible.builtin.include_tasks: deploy-{{ service }}.yml
   ```
2. Rotate secrets in batches:
   - **Batch 1:** Non-critical services (Nostr, Anon relays)
   - **Batch 2:** Network services (Pi-hole, HAProxy)
   - **Batch 3:** Critical infrastructure (K3s, Rancher)
3. Validate service functionality after each rotation
4. Document rotation schedule:
   - Critical secrets: Every 90 days
   - Standard secrets: Every 180 days
   - Low-risk secrets: Every 365 days
5. Create emergency rotation procedure for compromised secrets
6. Test emergency rotation in staging

**Success Criteria:**
- All production secrets rotated successfully
- Services continue operating after rotation
- Rotation playbook works reliably
- Emergency procedures tested and documented

### Phase 8: Monitoring and Optimization (Week 13-14)

**Objectives:**
- Implement secret access monitoring
- Optimize Bitwarden lookup performance
- Create alerting for secret-related issues
- Document operational procedures

**Deliverables:**
- [ ] Secret access logging enabled
- [ ] Performance baseline established
- [ ] Alerts configured for secret access anomalies
- [ ] Operational runbook completed

**Tasks:**
1. Enable Bitwarden audit logging
2. Monitor secret access patterns:
   - Which secrets accessed most frequently
   - Access times and patterns
   - Failed access attempts
3. Optimize playbook performance:
   - Cache Bitwarden lookups where appropriate
   - Use `vars_files` for batch secret loading
   - Profile playbook execution times
4. Create alerts:
   - Failed secret lookups
   - Unauthorized access attempts
   - Machine account token expiration warnings
5. Document operational procedures:
   - Adding new secrets
   - Rotating existing secrets
   - Handling secret compromise
   - Troubleshooting lookup failures
   - Machine account token renewal
6. Create troubleshooting guide

**Success Criteria:**
- Secret access monitored and logged
- Performance baseline documented
- Alerts tested and verified
- Operational runbook complete and tested

### Phase 9: Training and Documentation (Week 15-16)

**Objectives:**
- Train team on Bitwarden workflows
- Create comprehensive documentation
- Update all playbook README files
- Conduct knowledge transfer sessions

**Deliverables:**
- [ ] Team training completed
- [ ] Bitwarden user guide published
- [ ] Playbook documentation updated
- [ ] FAQ document created
- [ ] Video walkthrough recorded (optional)

**Tasks:**
1. Create user documentation:
   - Getting started with Bitwarden
   - Authenticating for playbook execution
   - Adding/updating secrets
   - Secret rotation procedures
   - Troubleshooting common issues
2. Update playbook README files with Bitwarden instructions
3. Create FAQ based on migration experience
4. Conduct team training sessions:
   - Overview of Bitwarden Secrets Manager
   - Authentication workflows
   - Secret management best practices
   - Hands-on exercises
5. Create quick reference guide
6. Record video walkthrough (optional)
7. Archive migration documentation for future reference

**Success Criteria:**
- All team members trained on Bitwarden
- Documentation complete and accessible
- FAQ addresses common questions
- Knowledge successfully transferred

## Technical Implementation Details

### Bitwarden Lookup Patterns

#### Basic Secret Lookup
```yaml
# Simple password lookup
database_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-db-password') }}"
```

#### Lookup with Default Fallback
```yaml
# Lookup with fallback during migration
api_key: "{{ lookup('bitwarden.secrets.lookup', 'prod-api-key', default=vault_api_key | default('')) }}"
```

#### Lookup with Error Handling
```yaml
# Fail explicitly if secret not found
- name: Get critical secret
  ansible.builtin.set_fact:
    cluster_token: "{{ lookup('bitwarden.secrets.lookup', 'prod-k3s-cluster-token') }}"
  no_log: true
  failed_when: cluster_token == ''
```

#### Batch Secret Loading
```yaml
# Load multiple secrets at once for performance
- name: Load all service secrets
  ansible.builtin.set_fact:
    service_secrets:
      admin_password: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-admin-pass') }}"
      api_token: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-api-token') }}"
      db_connection: "{{ lookup('bitwarden.secrets.lookup', 'prod-service-db-conn') }}"
  no_log: true
```

### Authentication Configuration

#### Local Development
```bash
# Option 1: Export token in shell
export BWS_ACCESS_TOKEN="your-machine-account-token-here"
ansible-playbook -i inventory/prod.ini playbooks/deploy-service.yml

# Option 2: Use environment file (gitignored)
echo "export BWS_ACCESS_TOKEN='your-token'" > ~/.bws_token
source ~/.bws_token
ansible-playbook -i inventory/prod.ini playbooks/deploy-service.yml

# Option 3: Pass as extra var (not recommended - visible in logs)
ansible-playbook -i inventory/prod.ini playbooks/deploy-service.yml \
  -e "ansible_env.BWS_ACCESS_TOKEN=your-token"
```

#### CI/CD Pipeline (GitHub Actions)
```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Bitwarden Secrets Manager SDK
        run: |
          ansible-galaxy collection install bitwarden.secrets

      - name: Deploy with Bitwarden secrets
        env:
          BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
        run: |
          ansible-playbook -i inventory/prod.ini playbooks/site.yml
```

### Security Best Practices

1. **Never commit BWS tokens to git**
   - Add to .gitignore: `.bws_token`, `bws_access_token`, `*.token`
   - Use environment variables or secure secret injection

2. **Use scoped machine accounts**
   - Separate accounts for different environments
   - Least privilege: only grant access to needed secrets
   - Rotate machine account tokens quarterly

3. **Enable audit logging**
   - Monitor secret access patterns
   - Alert on unusual access
   - Review logs monthly

4. **Use `no_log: true` for secret tasks**
   ```yaml
   - name: Deploy secret configuration
     ansible.builtin.template:
       src: config.j2
       dest: /etc/app/config.yml
     no_log: true
   ```

5. **Implement secret rotation**
   - Critical secrets: 90 days
   - Standard secrets: 180 days
   - Low-risk secrets: 365 days

## Secret Mapping Reference

### Global Secrets (all_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| vault_ssh_private_key | prod-global-ssh-private-key | prod/network-prod | Ansible SSH key |
| vault_sudo_password | prod-global-sudo-password | prod/services-prod | Sudo password for automation |
| vault_api_token | prod-global-api-token | prod/services-prod | General API access token |

### K3s Cluster (k3s_cluster_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| vault_k3s_token | prod-k3s-cluster-token | prod/k3s-prod | K3s cluster join token |
| vault_k3s_etcd_ca_cert | prod-k3s-etcd-ca-cert | prod/k3s-prod | etcd CA certificate |

### Pi-hole (pihole_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| vault_pihole_admin_password | prod-pihole-admin-password | prod/services-prod | Admin interface password |
| vault_pihole_api_token | prod-pihole-api-token | prod/services-prod | API authentication token |

### Rancher (rancher_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| vault_rancher_bootstrap_password | prod-rancher-bootstrap-password | prod/k3s-prod | Initial admin password |
| vault_rancher_admin_token | prod-rancher-admin-token | prod/k3s-prod | API token for automation |

### HAProxy (haproxy_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| haproxy_stats_password | prod-haproxy-stats-password | prod/network-prod | Stats page password |
| keepalived_auth_pass | prod-keepalived-auth-password | prod/network-prod | VRRP authentication (max 8 chars) |

### Tailscale Recorder (ts-recorder_vault.yml)
| Vault Variable | Bitwarden Secret ID | Project | Notes |
|----------------|---------------------|---------|-------|
| vault_tailscale_auth_key | prod-tailscale-auth-key | prod/network-prod | Tailscale device auth key |
| vault_ssh_session_key | prod-tailscale-ssh-session-key | prod/network-prod | SSH session encryption key |

## Risk Management

### Migration Risks

| Risk | Impact | Likelihood | Mitigation Strategy |
|------|--------|------------|---------------------|
| **Service Disruption** | High | Medium | Parallel operation with vault fallback, staged rollout, comprehensive testing |
| **Secret Leakage During Migration** | Critical | Low | Encrypted staging area, secure communication channels, audit trail |
| **Bitwarden Service Outage** | High | Low | Vault fallback mechanism, local secret caching, documented rollback procedure |
| **Authentication Failure** | High | Medium | Multiple machine accounts, token backup, manual override procedures |
| **Performance Degradation** | Medium | Medium | Lookup caching, batch loading, performance testing before production |
| **Incomplete Secret Migration** | Medium | Medium | Comprehensive inventory, automated verification, checklist per service |
| **Team Resistance/Confusion** | Low | High | Thorough documentation, training sessions, ongoing support |
| **Machine Account Token Compromise** | High | Low | Token rotation, access logging, anomaly detection, incident response plan |

### Rollback Strategies

#### Emergency Rollback (Service Down)
1. **Identify failing service:** Check Ansible logs for secret lookup failures
2. **Restore vault fallback:**
   ```yaml
   # Temporarily enable vault-only mode
   service_password: "{{ vault_service_password }}"
   ```
3. **Redeploy service:** `ansible-playbook -i inventory deploy-service.yml`
4. **Verify functionality:** Test service endpoints
5. **Investigate root cause:** Check Bitwarden connectivity, authentication, secret IDs

#### Planned Rollback (Migration Issues)
1. **Announce rollback window:** Notify team of planned changes
2. **Revert playbook changes:** `git revert <migration-commit>`
3. **Restore vault files:** `cp ansible/archive/vault-*/group_vars/ ./group_vars/`
4. **Update ansible.cfg:** Re-enable `vault_password_file`
5. **Test in staging:** Verify vault-based deployment works
6. **Deploy to production:** Execute rollback playbooks
7. **Document lessons learned:** Update migration plan

#### Partial Rollback (Single Service)
1. **Identify problematic service:** e.g., Pi-hole secret lookup failing
2. **Restore vault pattern for that service only:**
   ```yaml
   # group_vars/pihole.yml
   pihole_admin_password: "{{ vault_pihole_admin_password }}"  # Vault-only
   ```
3. **Redeploy service:** `ansible-playbook -i inventory/pihole.ini playbooks/pihole-deploy.yml`
4. **Continue migration for other services:** Don't halt entire migration
5. **Debug and retry:** Fix Bitwarden issue, retry migration later

### Security Incident Response

#### Compromised Machine Account Token
1. **Immediately revoke token** in Bitwarden organization settings
2. **Generate new token** with same permissions
3. **Update token** in secure locations (environment variables, CI/CD secrets)
4. **Rotate all secrets** accessible by compromised token
5. **Review audit logs** for unauthorized access
6. **Document incident** and update security procedures

#### Accidental Secret Exposure
1. **Identify exposed secret** (e.g., committed to git, logged, shared publicly)
2. **Rotate secret immediately** in Bitwarden
3. **Redeploy affected services** with new secret
4. **Revoke old secret** (if applicable, e.g., API tokens)
5. **Scrub history** (if in git: BFG Repo-Cleaner, git-filter-repo)
6. **Notify stakeholders** if external exposure
7. **Post-mortem** to prevent recurrence

## Testing Strategy

### Test Environments

1. **Local Development:** Individual developer workstations
2. **Staging:** Separate infrastructure mirroring production
3. **Production:** Live home-lab services

### Test Matrix

| Test Type | Scope | Frequency | Automation |
|-----------|-------|-----------|------------|
| Unit Tests | Individual secret lookups | Per change | Automated |
| Integration Tests | Full playbook execution | Per service migration | Automated |
| Smoke Tests | Service health checks | Post-deployment | Automated |
| Performance Tests | Lookup latency, playbook runtime | Weekly during migration | Semi-automated |
| Security Tests | Access controls, audit logging | Per phase | Manual |
| Rollback Tests | Disaster recovery procedures | Per phase | Manual |

### Test Scenarios

#### Secret Lookup Tests
```yaml
# tests/test-bitwarden-lookup.yml
---
- name: Test Bitwarden Secret Lookup
  hosts: localhost
  tasks:
    - name: Test valid secret lookup
      ansible.builtin.set_fact:
        test_secret: "{{ lookup('bitwarden.secrets.lookup', 'test-secret-id') }}"
      no_log: true
      register: lookup_result

    - name: Verify secret retrieved
      ansible.builtin.assert:
        that:
          - test_secret is defined
          - test_secret | length > 0
        fail_msg: "Secret lookup failed"

    - name: Test invalid secret lookup (should fail gracefully)
      ansible.builtin.set_fact:
        invalid_secret: "{{ lookup('bitwarden.secrets.lookup', 'nonexistent-id', default='') }}"
      no_log: true
      register: invalid_lookup

    - name: Verify default returned for invalid secret
      ansible.builtin.assert:
        that:
          - invalid_secret == ''
        fail_msg: "Default fallback not working"
```

#### Service Deployment Tests
```yaml
# tests/test-service-deployment.yml
---
- name: Test Service Deployment with Bitwarden
  hosts: staging
  tasks:
    - name: Deploy service with Bitwarden secrets
      ansible.builtin.include_role:
        name: service-deploy
      vars:
        use_bitwarden: true

    - name: Verify service running
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:{{ service_port }}/health"
        status_code: 200
      register: health_check

    - name: Verify authentication works
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:{{ service_port }}/api/test"
        method: POST
        user: admin
        password: "{{ lookup('bitwarden.secrets.lookup', 'staging-service-admin-pass') }}"
        status_code: 200
      no_log: true
```

#### Rollback Tests
```bash
# tests/test-rollback.sh
#!/bin/bash
set -e

echo "Testing rollback procedure..."

# Deploy with Bitwarden
ansible-playbook -i tests/inventory/staging.ini playbooks/deploy-pihole.yml

# Verify deployment
curl -f http://staging-pihole.local/admin || exit 1

# Simulate Bitwarden failure
unset BWS_ACCESS_TOKEN

# Trigger rollback to vault
ansible-playbook -i tests/inventory/staging.ini playbooks/deploy-pihole.yml \
  -e "use_vault_fallback=true"

# Verify service still works
curl -f http://staging-pihole.local/admin || exit 1

echo "Rollback test successful"
```

## Success Metrics

### Technical Metrics
- [ ] 100% of secrets migrated from Ansible Vault to Bitwarden
- [ ] Zero service disruptions during migration
- [ ] Playbook execution time increase < 10% (due to Bitwarden lookups)
- [ ] All playbooks pass in check mode before production deployment
- [ ] Rollback procedure tested and documented for each service
- [ ] Secret rotation completed for all production secrets

### Security Metrics
- [ ] All vault files archived and removed from active use
- [ ] No secrets in plaintext in git repository (verified by pre-commit hooks)
- [ ] Machine account tokens rotated quarterly
- [ ] Audit logging enabled and monitored
- [ ] Access controls tested and enforced
- [ ] Incident response procedures documented and tested

### Operational Metrics
- [ ] All team members trained on Bitwarden workflows
- [ ] Documentation complete and up-to-date
- [ ] Secrets accessible via automated playbooks and manual CLI
- [ ] Secret rotation playbook working for all services
- [ ] Troubleshooting guide addresses common issues
- [ ] Knowledge transfer sessions completed

### Business Metrics
- [ ] Migration completed within 16-week timeline
- [ ] No production outages attributed to migration
- [ ] Secret management overhead reduced (easier rotation, better auditing)
- [ ] Team satisfaction with new secret management approach
- [ ] Compliance with security best practices improved

## Timeline and Milestones

| Week | Phase | Milestone | Status |
|------|-------|-----------|--------|
| 1-2 | Infrastructure Setup | Bitwarden org and accounts ready | Pending |
| 2-3 | Secret Inventory | All secrets inventoried and categorized | Pending |
| 3-4 | Bitwarden Import | All secrets in Bitwarden with IDs | Pending |
| 4-5 | Pilot Migration | Nostr relay on Bitwarden | Pending |
| 5-8 | Core Services | All services migrated | Pending |
| 9-10 | Vault Deprecation | Vault files archived | Pending |
| 11-12 | Secret Rotation | All secrets rotated | Pending |
| 13-14 | Monitoring | Logging and alerts configured | Pending |
| 15-16 | Training | Team trained and docs complete | Pending |

## Post-Migration Operations

### Secret Lifecycle Management

#### Adding New Secrets
1. Create secret in appropriate Bitwarden project
2. Document secret ID in mapping spreadsheet
3. Update playbook/group_vars with Bitwarden lookup
4. Test in staging before production
5. Update documentation

#### Rotating Secrets
1. Generate new secret value
2. Update secret in Bitwarden
3. Deploy updated secret to services using playbook
4. Verify service functionality
5. Document rotation in audit log

#### Deprecating Secrets
1. Identify unused secrets via audit logs
2. Verify secret not referenced in any active playbooks
3. Archive secret in Bitwarden (don't delete immediately)
4. Remove references from documentation
5. Delete after 90-day retention period

### Troubleshooting Guide

#### Secret Lookup Fails
**Symptom:** Playbook fails with "Secret not found" error

**Resolution:**
1. Verify BWS_ACCESS_TOKEN set: `echo $BWS_ACCESS_TOKEN`
2. Test Bitwarden CLI access: `bw login` or `bw unlock`
3. Verify secret ID is correct: Check mapping spreadsheet
4. Test manual lookup: `bw get item <secret-id>`
5. Check machine account permissions in Bitwarden
6. Fallback to vault if critical: Enable vault fallback variable

#### Authentication Fails
**Symptom:** "Unauthorized" or "Invalid token" error

**Resolution:**
1. Verify token not expired: Check Bitwarden organization settings
2. Regenerate machine account token if needed
3. Update token in environment/CI-CD
4. Test authentication: `bw login --apikey`
5. Review audit logs for access patterns

#### Performance Issues
**Symptom:** Playbooks running significantly slower

**Resolution:**
1. Profile playbook execution: `ansible-playbook --profile`
2. Identify slow tasks (likely secret lookups)
3. Implement lookup caching:
   ```yaml
   - name: Cache secrets for performance
     ansible.builtin.set_fact:
       cached_secrets:
         password: "{{ lookup('bitwarden.secrets.lookup', 'secret-id') }}"
     no_log: true
   ```
4. Batch secret retrieval where possible
5. Consider local secret caching for frequently accessed secrets

## Maintenance Schedule

### Weekly
- Review Bitwarden audit logs for anomalies
- Check machine account token expiration dates
- Verify secret lookups working in CI/CD

### Monthly
- Review and update documentation
- Test rollback procedures in staging
- Analyze secret access patterns
- Update secret mapping spreadsheet

### Quarterly
- Rotate machine account tokens
- Rotate critical secrets (K3s, Rancher, etc.)
- Security audit of access controls
- Team training refresh

### Annually
- Comprehensive secret rotation
- Review and update secret lifecycle policies
- Evaluate Bitwarden Secrets Manager for new features
- Update disaster recovery procedures

## References and Resources

### Documentation
- [Bitwarden Secrets Manager Docs](https://bitwarden.com/help/secrets-manager/)
- [Bitwarden Ansible Collection](https://github.com/bitwarden/ansible-collection)
- [Ansible Vault to Bitwarden Migration Guide](https://docs.bitwarden.com/secrets-manager/migration/)
- Home Lab CLAUDE.md: Secret management architecture

### Tools
- **Bitwarden CLI:** `brew install bitwarden-cli`
- **Bitwarden Ansible Collection:** `ansible-galaxy collection install bitwarden.secrets`
- **Secret Scanner:** `detect-secrets` (pre-commit hook)
- **Encryption:** GPG for backup encryption

### Related Projects
- Home Lab Infrastructure: `/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/`
- Ansible Playbooks: `/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible/playbooks/`
- Group Variables: `/Users/elvis/Documents/Git/HomeLab-Apps/home-lab/ansible/group_vars/`

## Appendix

### Example Migration Commands

```bash
# Decrypt vault file for migration
ansible-vault decrypt group_vars/pihole_vault.yml --output=/tmp/pihole_vault_decrypted.yml

# Create Bitwarden secret via CLI
bw create item --name "prod-pihole-admin-password" \
  --organizationid "org-id" \
  --collectionid "prod-services" \
  --password "actual-password-here"

# Test Bitwarden lookup in Ansible
ansible localhost -m debug \
  -a "msg={{ lookup('bitwarden.secrets.lookup', 'secret-id') }}" \
  --extra-vars "ansible_env.BWS_ACCESS_TOKEN=your-token"

# Deploy with Bitwarden secrets
export BWS_ACCESS_TOKEN="your-machine-account-token"
ansible-playbook -i inventory/prod.ini playbooks/deploy-pihole.yml

# Verify secret accessible
bw get item prod-pihole-admin-password

# Rotate secret
bw edit item prod-pihole-admin-password --password "new-password"
ansible-playbook -i inventory/prod.ini playbooks/deploy-pihole.yml
```

### Decision Log

| Date | Decision | Rationale | Stakeholders |
|------|----------|-----------|--------------|
| 2025-10-31 | Use Bitwarden Secrets Manager over HashiCorp Vault | Better integration with existing Bitwarden usage, lower complexity for home lab | Elvis |
| 2025-10-31 | Phased migration with parallel operation | Minimize risk, allow rollback, zero downtime | Elvis |
| 2025-10-31 | Start with Nostr relay as pilot | Already has Bitwarden comment, non-critical service | Elvis |
| 2025-10-31 | Maintain vault fallback during migration | Safety net for Bitwarden outages, easier rollback | Elvis |

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-31
**Maintained By:** Elvis (Home Lab Infrastructure Team)
**Status:** Planning Phase - Ready for Phase 1 Execution

**Next Steps:**
1. Review and approve this development plan
2. Begin Phase 1: Infrastructure Setup
3. Create Bitwarden organization and machine accounts
4. Schedule kickoff meeting for migration project
