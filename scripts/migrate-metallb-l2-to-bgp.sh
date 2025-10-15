#!/bin/bash
#
# Quick MetalLB L2 to BGP Migration Script
#
# This script provides a quick way to migrate from L2 to BGP mode
# with minimal downtime and rollback capabilities.
#

set -euo pipefail

# Configuration
KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
BACKUP_DIR="/tmp/metallb-l2-backup-$(date +%Y%m%d_%H%M%S)"
ROUTER_TYPE="${ROUTER_TYPE:-unifi}"
ROUTER_IP="${ROUTER_IP:-10.2.0.1}"
ROUTER_ASN="${ROUTER_ASN:-65000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    # Check kubectl access
    if ! kubectl --kubeconfig="$KUBECONFIG" get nodes >/dev/null 2>&1; then
        log_error "Cannot access Kubernetes cluster"
        exit 1
    fi

    # Check MetalLB is installed
    if ! kubectl --kubeconfig="$KUBECONFIG" get namespace metallb-system >/dev/null 2>&1; then
        log_error "MetalLB namespace not found"
        exit 1
    fi

    # Check L2 configuration exists
    if ! kubectl --kubeconfig="$KUBECONFIG" get ipaddresspool,l2advertisement -n metallb-system >/dev/null 2>&1; then
        log_error "No L2 configuration found"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

# Create backup
create_backup() {
    log_step "Creating backup of current L2 configuration..."

    mkdir -p "$BACKUP_DIR"

    # Backup current configuration
    kubectl --kubeconfig="$KUBECONFIG" get ipaddresspool,l2advertisement -n metallb-system -o yaml > "$BACKUP_DIR/l2-config.yaml"
    kubectl --kubeconfig="$KUBECONFIG" get svc -A -o yaml --field-selector spec.type=LoadBalancer > "$BACKUP_DIR/loadbalancer-services.yaml"

    log_info "Backup created in: $BACKUP_DIR"
}

# Deploy BGP configuration
deploy_bgp_config() {
    log_step "Deploying BGP configuration..."

    # Create BGP peer
    cat <<EOF | kubectl --kubeconfig="$KUBECONFIG" apply -f -
---
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: router-peer
  namespace: metallb-system
spec:
  myASN: 65001
  peerASN: $ROUTER_ASN
  peerAddress: $ROUTER_IP
  peerPort: 179
  holdTime: 90s
  keepaliveTime: 30s
  routerID: $(kubectl --kubeconfig="$KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  gracefulRestart: true
EOF

    # Create BGP IP pool
    cat <<EOF | kubectl --kubeconfig="$KUBECONFIG" apply -f -
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: bgp-pool
  namespace: metallb-system
spec:
  addresses:
    - 10.41.0.0/16
  autoAssign: true
EOF

    # Create BGP advertisement
    cat <<EOF | kubectl --kubeconfig="$KUBECONFIG" apply -f -
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: bgp-adv
  namespace: metallb-system
spec:
  ipAddressPools:
    - bgp-pool
  communities:
    - 65535:65282
EOF

    log_info "BGP configuration deployed"
}

# Generate router configuration
generate_router_config() {
    log_step "Generating router configuration..."

    local router_config_dir="/tmp/metallb-router-config"
    mkdir -p "$router_config_dir"

    # Get cluster nodes
    local nodes=$(kubectl --kubeconfig="$KUBECONFIG" get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    local node_count=1

    case "$ROUTER_TYPE" in
        unifi)
            cat > "$router_config_dir/unifi-commands.txt" <<EOF
configure

router bgp $ROUTER_ASN
  bgp router-id $ROUTER_IP
  bgp graceful-restart

  address-family ipv4 unicast
EOF
            for node in $nodes; do
                cat >> "$router_config_dir/unifi-commands.txt" <<EOF
    neighbor $node remote-as $((65000 + node_count))
    neighbor $node description "K3s Node $node_count"
    neighbor $node timers 30 90
    neighbor $node activate
    neighbor $node next-hop-self
    neighbor $node route-reflector-client
EOF
                ((node_count++))
            done
            cat >> "$router_config_dir/unifi-commands.txt" <<EOF
    network 10.41.0.0/16
  exit-address-family
!

commit
save

show bgp summary
EOF
            log_info "UniFi commands generated: $router_config_dir/unifi-commands.txt"
            ;;
        frr)
            cat > "$router_config_dir/frr.conf" <<EOF
router bgp $ROUTER_ASN
  bgp router-id $ROUTER_IP
  no bgp default ipv4-unicast
  bgp graceful-restart

  address-family ipv4 unicast
EOF
            for node in $nodes; do
                cat >> "$router_config_dir/frr.conf" <<EOF
    neighbor $node remote-as $((65000 + node_count))
    neighbor $node description "K3s Node $node_count"
    neighbor $node activate
    neighbor $node next-hop-self
    neighbor $node route-reflector-client
EOF
                ((node_count++))
            done
            cat >> "$router_config_dir/frr.conf" <<EOF
    network 10.41.0.0/16
  exit-address-family
!
EOF
            log_info "FRR configuration generated: $router_config_dir/frr.conf"
            ;;
        *)
            log_error "Unsupported router type: $ROUTER_TYPE"
            exit 1
            ;;
    esac
}

# Wait for router configuration
wait_for_router_config() {
    log_step "Router configuration required..."

    case "$ROUTER_TYPE" in
        unifi)
            log_info "Please configure your UniFi UDM Pro:"
            log_info "1. SSH to: ssh admin@$ROUTER_IP"
            log_info "2. Apply commands from: /tmp/metallb-router-config/unifi-commands.txt"
            log_info "3. Verify with: show bgp summary"
            ;;
        frr)
            log_info "Please configure FRR:"
            log_info "1. Copy: /tmp/metallb-router-config/frr.conf to /etc/frr/frr.conf"
            log_info "2. Restart: systemctl restart frr"
            log_info "3. Verify with: vtysh -c 'show bgp summary'"
            ;;
    esac

    read -p "Press ENTER when router configuration is complete and BGP sessions are established..."
}

# Verify BGP sessions
verify_bgp_sessions() {
    log_step "Verifying BGP sessions..."

    # Check MetalLB speaker logs
    log_info "Checking MetalLB speaker logs..."
    kubectl --kubeconfig="$KUBECONFIG" logs -n metallb-system -l app=metallb -l component=speaker --tail=20

    # Check BGP configuration
    log_info "Current BGP configuration:"
    kubectl --kubeconfig="$KUBECONFIG" get bgppeer,ipaddresspool,bgpadvertisement -n metallb-system
}

# Update services to use BGP
update_services() {
    log_step "Updating services to use BGP pool..."

    # Update Pi-hole services
    kubectl --kubeconfig="$KUBECONFIG" patch svc pihole-dns -n pihole -p '{"metadata":{"annotations":{"metallb.universe.tf/address-pool":"bgp-pool"}}}' || true
    kubectl --kubeconfig="$KUBECONFIG" patch svc pihole-web -n pihole -p '{"metadata":{"annotations":{"metallb.universe.tf/address-pool":"bgp-pool"}}}' || true

    log_info "Services updated to use BGP pool"
}

# Cleanup L2 configuration
cleanup_l2() {
    log_step "Cleaning up L2 configuration..."

    # Remove L2 advertisements
    kubectl --kubeconfig="$KUBECONFIG" delete l2advertisement -n metallb-system --all --ignore-not-found=true

    # Remove old IP pool if different
    kubectl --kubeconfig="$KUBECONFIG" delete ipaddresspool -n metallb-system default --ignore-not-found=true

    log_info "L2 configuration cleaned up"
}

# Final verification
final_verification() {
    log_step "Final verification..."

    # Wait for services to stabilize
    sleep 30

    # Check LoadBalancer services
    log_info "LoadBalancer services:"
    kubectl --kubeconfig="$KUBECONFIG" get svc -A -o wide --field-selector spec.type=LoadBalancer

    # Test connectivity
    log_info "Testing Pi-hole connectivity..."
    if curl -s -o /dev/null -w "%{http_code}" http://10.41.0.100/admin/ | grep -q "200"; then
        log_info "✅ Pi-hole web interface is accessible"
    else
        log_warn "⚠️  Pi-hole web interface may not be accessible yet"
    fi

    # Display final status
    log_info "Final MetalLB configuration:"
    kubectl --kubeconfig="$KUBECONFIG" get ipaddresspool,l2advertisement,bgppeer,bgpadvertisement -n metallb-system
}

# Create rollback script
create_rollback_script() {
    log_step "Creating rollback script..."

    cat > "$BACKUP_DIR/rollback.sh" <<EOF
#!/bin/bash
# MetalLB Rollback Script
set -euo pipefail

log_info() { echo -e "\033[0;32m[INFO]\033[0m \$1"; }
log_step() { echo -e "\033[0;34m[STEP]\033[0m \$1"; }

log_step "Rolling back MetalLB to L2 mode..."

# Remove BGP configuration
kubectl --kubeconfig="$KUBECONFIG" delete bgpadvertisement -n metallb-system --all --ignore-not-found=true
kubectl --kubeconfig="$KUBECONFIG" delete bgppeer -n metallb-system --all --ignore-not-found=true
kubectl --kubeconfig="$KUBECONFIG" delete ipaddresspool -n metallb-system bgp-pool --ignore-not-found=true

# Restore L2 configuration
kubectl --kubeconfig="$KUBECONFIG" apply -f "$BACKUP_DIR/l2-config.yaml"
kubectl --kubeconfig="$KUBECONFIG" apply -f "$BACKUP_DIR/loadbalancer-services.yaml"

log_info "Rollback completed"
EOF

    chmod +x "$BACKUP_DIR/rollback.sh"
    log_info "Rollback script created: $BACKUP_DIR/rollback.sh"
}

# Main function
main() {
    log_info "🚀 Starting MetalLB L2 to BGP migration..."
    log_info "Router Type: $ROUTER_TYPE"
    log_info "Router IP: $ROUTER_IP"
    log_info "Router ASN: $ROUTER_ASN"

    # Execute migration steps
    check_prerequisites
    create_backup
    deploy_bgp_config
    generate_router_config
    create_rollback_script

    log_info "📋 Manual steps required:"
    log_info "1. Configure your router with the generated configuration"
    log_info "2. Verify BGP sessions are established"
    log_info "3. Continue with the migration"

    read -p "Continue with router configuration step? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        wait_for_router_config
        verify_bgp_sessions
        update_services
        cleanup_l2
        final_verification

        log_info "🎉 Migration completed successfully!"
        log_info "MetalLB is now running in BGP mode with anycast routing"
        log_info "Rollback available: $BACKUP_DIR/rollback.sh"
    else
        log_info "Migration paused. You can continue later by running the router configuration steps."
        log_info "Configuration files are available in: /tmp/metallb-router-config/"
        log_info "Backup files are available in: $BACKUP_DIR/"
    fi
}

# Show usage if help requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
MetalLB L2 to BGP Migration Script

Usage: $0 [options]

Environment Variables:
  ROUTER_TYPE    Router type (unifi, frr) [default: unifi]
  ROUTER_IP      Router IP address [default: 10.2.0.1]
  ROUTER_ASN     Router ASN [default: 65000]

Examples:
  $0                                    # Use defaults (UniFi UDM Pro)
  ROUTER_TYPE=frr $0                    # Use FRR router
  ROUTER_IP=192.168.1.1 ROUTER_ASN=65001 $0  # Custom router config

EOF
    exit 0
fi

# Run main function
main "$@"
