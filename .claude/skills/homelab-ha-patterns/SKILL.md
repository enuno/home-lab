---
name: "homelab-ha-patterns"
description: "High-availability architecture patterns for home lab infrastructure including multi-master Kubernetes, etcd clustering, HAProxy load balancing, database replication, network redundancy, and failover mechanisms. Use when designing HA systems, implementing cluster quorum, optimizing for 99.9% uptime, or building resilient infrastructure with automatic failover."
allowed-tools: ["Read", "Search", "Edit"]
version: "1.0.0"
author: "Home Lab Infrastructure Team"
---

# Home Lab High Availability Patterns

## When to Use This Skill

Claude automatically applies this skill when you:
- Ask to "design a highly available..." system
- Request "multi-master Kubernetes cluster"
- Need "load balancing and failover"
- Want "database replication and HA"
- Implement "etcd clustering with quorum"
- Design "network redundancy"
- Build "resilient infrastructure"
- Optimize "for 99.9% uptime"

## Core HA Principles

### The Rule of Three (Quorum-Based HA)

**Golden Rule**: Always use **odd numbers** (3, 5, 7) of nodes for quorum-based systems.

```
✅ CORRECT:
- 3 master nodes (tolerates 1 failure)
- 5 master nodes (tolerates 2 failures)
- 7 master nodes (tolerates 3 failures)

❌ WRONG:
- 2 master nodes (no quorum if 1 fails)
- 4 master nodes (same fault tolerance as 3)
- 6 master nodes (same fault tolerance as 5, wastes resources)
```

**Quorum Formula**: `(n / 2) + 1`

```
3 nodes: quorum = 2 (tolerates 1 failure)
5 nodes: quorum = 3 (tolerates 2 failures)
7 nodes: quorum = 4 (tolerates 3 failures)
```

### HA Stack Layers

```
┌─────────────────────────────────────────┐
│         Application Layer                │
│     (Pods, Deployments, Services)        │
├─────────────────────────────────────────┤
│       Orchestration Layer                │
│   (K8s Control Plane, etcd cluster)      │
├─────────────────────────────────────────┤
│         Network Layer                    │
│  (Load Balancers, VIPs, Keepalived)      │
├─────────────────────────────────────────┤
│         Storage Layer                    │
│    (Distributed storage, Replication)    │
├─────────────────────────────────────────┤
│         Compute Layer                    │
│     (VMs distributed across hosts)       │
├─────────────────────────────────────────┤
│        Hardware Layer                    │
│   (Multiple Proxmox nodes, redundant     │
│    power, networking, storage)           │
└─────────────────────────────────────────┘
```

## Pattern 1: Multi-Master Kubernetes (K3s)

### Architecture

```
                    ┌─────────────┐
                    │  HAProxy    │
                    │  VIP: .10   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐       ┌────▼────┐      ┌────▼────┐
    │ Master1 │       │ Master2 │      │ Master3 │
    │ .11     │◄─────►│ .12     │◄────►│ .13     │
    └────┬────┘       └────┬────┘      └────┬────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                    (etcd cluster)
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐       ┌────▼────┐      ┌────▼────┐
    │ Worker1 │       │ Worker2 │      │ Worker3 │
    │ .21     │       │ .22     │      │ .23     │
    └─────────┘       └─────────┘      └─────────┘
```

### Implementation

#### Terraform: Multi-Master Setup

```hcl
variable "master_nodes" {
  type = map(object({
    name       = string
    node       = string  # Distribute across Proxmox hosts
    ip_address = string
  }))

  # Enforce odd number with validation
  validation {
    condition     = length(var.master_nodes) >= 3 && length(var.master_nodes) % 2 != 0
    error_message = "Must have odd number of masters (3, 5, or 7) for quorum"
  }

  default = {
    master1 = {
      name       = "k3s-master-1"
      node       = "proxmox-1"  # Proxmox host 1
      ip_address = "10.2.0.11"
    }
    master2 = {
      name       = "k3s-master-2"
      node       = "proxmox-2"  # Proxmox host 2
      ip_address = "10.2.0.12"
    }
    master3 = {
      name       = "k3s-master-3"
      node       = "proxmox-1"  # Back to host 1
      ip_address = "10.2.0.13"
    }
  }
}

# Anti-affinity: Distribute masters across Proxmox nodes
locals {
  proxmox_nodes = distinct([for k, v in var.master_nodes : v.node])
}

resource "proxmox_vm_qemu" "k3s_master" {
  for_each = var.master_nodes

  name        = each.value.name
  target_node = each.value.node  # Explicit node assignment

  # HA configuration
  hastate = "started"
  hagroup = "k3s-masters"

  lifecycle {
    create_before_destroy = true  # Ensures smooth failover
  }
}
```

#### Ansible: Bootstrap First Master

```yaml
---
- name: Bootstrap K3s first master
  hosts: k3s_master[0]
  become: yes

  tasks:
    - name: Install K3s on first master
      ansible.builtin.shell: |
        curl -sfL https://get.k3s.io | sh -s - server \
          --cluster-init \
          --tls-san {{ hostvars[inventory_hostname]['ansible_host'] }} \
          --tls-san {{ k3s_vip }} \
          --disable servicelb \
          --disable traefik
      environment:
        INSTALL_K3S_VERSION: "{{ k3s_version }}"

    - name: Get K3s token
      ansible.builtin.slurp:
        src: /var/lib/rancher/k3s/server/node-token
      register: k3s_token

    - name: Save token for other masters
      ansible.builtin.set_fact:
        cluster_token: "{{ k3s_token.content | b64decode | trim }}"
      delegate_to: localhost
      delegate_facts: yes
```

#### Ansible: Join Additional Masters

```yaml
---
- name: Join additional K3s masters
  hosts: k3s_master[1:]
  become: yes
  serial: 1  # Join one at a time for stability

  tasks:
    - name: Join cluster as master
      ansible.builtin.shell: |
        curl -sfL https://get.k3s.io | sh -s - server \
          --server https://{{ hostvars[groups['k3s_master'][0]]['ansible_host'] }}:6443 \
          --token {{ hostvars['localhost']['cluster_token'] }} \
          --tls-san {{ hostvars[inventory_hostname]['ansible_host'] }} \
          --tls-san {{ k3s_vip }}
      environment:
        INSTALL_K3S_VERSION: "{{ k3s_version }}"
```

### etcd Cluster Health

```bash
# Check etcd cluster status
kubectl exec -n kube-system etcd-k3s-master-1 -- \
  etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key

# Expected output (3-member cluster):
# a1b2c3d4, started, k3s-master-1, https://10.2.0.11:2380, https://10.2.0.11:2379
# e5f6g7h8, started, k3s-master-2, https://10.2.0.12:2380, https://10.2.0.12:2379
# i9j0k1l2, started, k3s-master-3, https://10.2.0.13:2380, https://10.2.0.13:2379
```

## Pattern 2: HAProxy Load Balancing with Keepalived

### Architecture

```
                   Virtual IP (VIP)
                   10.2.0.10
                        │
          ┌─────────────┴─────────────┐
          │       Keepalived          │
     MASTER (Pri:100)         BACKUP (Pri:50)
          │                           │
    ┌─────▼─────┐              ┌──────▼──────┐
    │ HAProxy-1 │              │ HAProxy-2   │
    │ 10.2.0.5  │              │ 10.2.0.6    │
    └─────┬─────┘              └──────┬──────┘
          │                           │
          └─────────────┬─────────────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐    ┌────▼────┐   ┌────▼────┐
    │ Master1 │    │ Master2 │   │ Master3 │
    │  :6443  │    │  :6443  │   │  :6443  │
    └─────────┘    └─────────┘   └─────────┘
```

### HAProxy Configuration

```haproxy
# /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

# Stats interface
listen stats
    bind *:9000
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats auth admin:{{ lookup('bitwarden.secrets.lookup', 'prod-haproxy-stats-password') }}

# K3s API Server (HA)
frontend k3s_api_frontend
    bind *:6443
    mode tcp
    option tcplog
    default_backend k3s_api_backend

backend k3s_api_backend
    mode tcp
    balance roundrobin
    option tcp-check

    # Health check
    tcp-check connect

    # Backend servers (all masters)
    server k3s-master-1 10.2.0.11:6443 check fall 3 rise 2
    server k3s-master-2 10.2.0.12:6443 check fall 3 rise 2
    server k3s-master-3 10.2.0.13:6443 check fall 3 rise 2

# HTTP/HTTPS Ingress (for application traffic)
frontend http_frontend
    bind *:80
    mode tcp
    default_backend http_backend

frontend https_frontend
    bind *:443
    mode tcp
    default_backend https_backend

backend http_backend
    mode tcp
    balance roundrobin
    option tcp-check

    # Worker nodes (where ingress runs)
    server k3s-worker-1 10.2.0.21:80 check
    server k3s-worker-2 10.2.0.22:80 check
    server k3s-worker-3 10.2.0.23:80 check

backend https_backend
    mode tcp
    balance roundrobin
    option ssl-hello-chk

    server k3s-worker-1 10.2.0.21:443 check
    server k3s-worker-2 10.2.0.22:443 check
    server k3s-worker-3 10.2.0.23:443 check
```

### Keepalived Configuration

**HAProxy-1 (MASTER)**:

```bash
# /etc/keepalived/keepalived.conf
vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100  # Higher priority = MASTER
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass {{ lookup('bitwarden.secrets.lookup', 'prod-keepalived-auth-password') }}
    }

    virtual_ipaddress {
        10.2.0.10/24  # VIP
    }

    track_script {
        check_haproxy
    }
}
```

**HAProxy-2 (BACKUP)**:

```bash
# /etc/keepalived/keepalived.conf
vrrp_script check_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 50   # Lower priority = BACKUP
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass {{ lookup('bitwarden.secrets.lookup', 'prod-keepalived-auth-password') }}
    }

    virtual_ipaddress {
        10.2.0.10/24  # Same VIP
    }

    track_script {
        check_haproxy
    }
}
```

### Testing Failover

```bash
# Check VIP location
ip addr show | grep "10.2.0.10"

# Simulate failure (on MASTER)
sudo systemctl stop haproxy

# VIP should move to BACKUP within ~2 seconds

# Verify VIP moved
ip addr show | grep "10.2.0.10"  # Now on BACKUP

# Restore MASTER
sudo systemctl start haproxy

# VIP moves back to MASTER
```

## Pattern 3: Database High Availability

### PostgreSQL with Patroni

```
         ┌──────────────┐
         │   etcd (K3s) │
         │   Cluster    │
         └───────┬──────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼───┐   ┌───▼───┐   ┌───▼───┐
│Patroni│   │Patroni│   │Patroni│
│   +   │   │   +   │   │   +   │
│ PG-1  │◄─►│ PG-2  │◄─►│ PG-3  │
│PRIMARY│   │STANDBY│   │STANDBY│
└───────┘   └───────┘   └───────┘
```

#### Patroni Configuration

```yaml
# /etc/patroni/config.yml
scope: postgres-cluster
namespace: /service/
name: postgres-1

restapi:
  listen: 0.0.0.0:8008
  connect_address: 10.2.0.31:8008

etcd3:
  hosts: 10.2.0.11:2379,10.2.0.12:2379,10.2.0.13:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576

    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
        wal_keep_segments: 8

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 10.2.0.31:5432
  data_dir: /var/lib/postgresql/14/main

  authentication:
    replication:
      username: replicator
      password: {{ lookup('bitwarden.secrets.lookup', 'prod-postgres-replication-password') }}
    superuser:
      username: postgres
      password: {{ lookup('bitwarden.secrets.lookup', 'prod-postgres-password') }}

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
```

### Automatic Failover

```bash
# Simulate primary failure
sudo systemctl stop patroni

# Patroni automatically:
# 1. Detects primary failure
# 2. Elects new primary from standbys
# 3. Promotes standby to primary
# 4. Reconfigures remaining standbys
# Total failover time: ~10-15 seconds

# Check cluster status
patronictl -c /etc/patroni/config.yml list

# Output:
# + Cluster: postgres-cluster (7123456789012345678) -----+----+-----------+
# | Member     | Host        | Role    | State   | TL | Lag in MB |
# +------------+-------------+---------+---------+----+-----------+
# | postgres-1 | 10.2.0.31   | Standby | running | 2  | 0         |
# | postgres-2 | 10.2.0.32   | Leader  | running | 2  | -         |
# | postgres-3 | 10.2.0.33   | Standby | running | 2  | 0         |
# +------------+-------------+---------+---------+----+-----------+
```

## Pattern 4: Storage Replication

### Longhorn Distributed Storage

```
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Worker-1  │  │  Worker-2  │  │  Worker-3  │
│            │  │            │  │            │
│ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │
│ │Replica1│ │  │ │Replica2│ │  │ │Replica3│ │
│ │  100GB │ │  │ │  100GB │ │  │ │  100GB │ │
│ └────────┘ │  │ └────────┘ │  │ └────────┘ │
└────────────┘  └────────────┘  └────────────┘
       │               │               │
       └───────────────┼───────────────┘
                  Sync Replication
                  (3 replicas)
```

#### Longhorn StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-ha
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"  # HA: 3 replicas
  staleReplicaTimeout: "2880"
  fromBackup: ""
  dataLocality: "best-effort"  # Try to keep replica on same node
```

## Pattern 5: Network Redundancy

### VLAN Segmentation

```
┌──────────────────────────────────────────┐
│         Management VLAN 10               │
│    (Infrastructure access only)          │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│         Services VLAN 20                 │
│    (K3s, databases, applications)        │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│         Storage VLAN 30                  │
│    (NFS, iSCSI, distributed storage)     │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│         DMZ VLAN 40                      │
│    (External-facing services)            │
└──────────────────────────────────────────┘
```

### Multiple Network Paths

```terraform
resource "proxmox_vm_qemu" "k3s_master" {
  # Primary network (services)
  network {
    model  = "virtio"
    bridge = "vmbr1"
    tag    = 20  # Services VLAN
  }

  # Storage network
  network {
    model  = "virtio"
    bridge = "vmbr2"
    tag    = 30  # Storage VLAN
  }
}
```

## Failure Scenarios and Recovery

### Scenario 1: Single Master Failure

```
Before:
Master1 (PRIMARY) + Master2 + Master3 = Quorum (3/3)

After Master1 fails:
Master2 + Master3 = Quorum (2/3) ✅ Cluster still operational

Recovery:
1. etcd automatically elects new leader
2. K3s API continues via remaining masters
3. HAProxy routes traffic to healthy masters
4. Fix/replace Master1
5. Rejoin to cluster
```

### Scenario 2: Two Masters Fail

```
Before:
Master1 + Master2 + Master3 = Quorum (3/3)

After Master1 and Master2 fail:
Master3 alone = NO QUORUM (1/3) ❌ Cluster read-only

Recovery:
1. Restore at least one failed master
2. Quorum restored (2/3)
3. Cluster operational again
```

### Scenario 3: HAProxy Primary Fails

```
Before:
HAProxy-1 (MASTER, holds VIP) + HAProxy-2 (BACKUP)

After HAProxy-1 fails:
1. Keepalived detects failure (2 seconds)
2. VIP fails over to HAProxy-2
3. HAProxy-2 becomes MASTER
4. Total downtime: ~2-3 seconds
```

## Monitoring and Alerting

### Health Checks

```yaml
# Kubernetes liveness probe
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 3

# Kubernetes readiness probe
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

### Prometheus Alerts

```yaml
# Alert on etcd cluster health
- alert: EtcdClusterUnhealthy
  expr: etcd_server_has_leader{} == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "etcd cluster has no leader"

# Alert on HAProxy backend down
- alert: HAProxyBackendDown
  expr: haproxy_backend_up{} == 0
  for: 30s
  labels:
    severity: warning
  annotations:
    summary: "HAProxy backend {{ $labels.backend }} is down"
```

## Key Takeaways

1. **Odd Numbers**: Always 3, 5, or 7 nodes for quorum
2. **Distribution**: Spread nodes across physical hosts
3. **Load Balancing**: Use HAProxy + Keepalived for VIP
4. **Storage**: 3+ replicas for data redundancy
5. **Network**: VLAN segmentation and multiple paths
6. **Monitoring**: Comprehensive health checks and alerts
7. **Testing**: Regular failover testing
8. **Documentation**: Document recovery procedures
9. **Automation**: Automate failover where possible
10. **Simplicity**: Don't over-engineer for home lab scale

This skill provides battle-tested HA patterns optimized for home lab environments while maintaining production-grade reliability.