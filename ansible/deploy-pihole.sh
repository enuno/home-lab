#!/bin/bash
# Pi-hole Deployment Script
# Quick deployment wrapper for Pi-hole to K3s cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================"
echo "Pi-hole Deployment to K3s Cluster"
echo "================================================"
echo ""

# Check if vault file is encrypted
if grep -q "ANSIBLE_VAULT" group_vars/pihole_vault.yml; then
    echo "✓ Vault file is encrypted"
else
    echo "⚠ WARNING: Vault file is not encrypted!"
    echo "  Run: ansible-vault encrypt group_vars/pihole_vault.yml"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check connectivity to K3s master
echo ""
echo "Checking connectivity to K3s master..."
ansible k3s_masters[0] -m ping -o

if [ $? -ne 0 ]; then
    echo "✗ Cannot connect to K3s master node"
    echo "  Check your inventory and SSH configuration"
    exit 1
fi

echo "✓ K3s master is reachable"
echo ""

# Deploy Pi-hole
echo "Deploying Pi-hole..."
echo ""

if grep -q "ANSIBLE_VAULT" group_vars/pihole_vault.yml; then
    # Vault is encrypted, ask for password
    ansible-playbook playbooks/pihole-deploy.yml --ask-vault-pass "$@"
else
    # Vault is not encrypted (development/testing)
    ansible-playbook playbooks/pihole-deploy.yml "$@"
fi

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "To view Pi-hole status:"
echo "  kubectl get all -n pihole"
echo ""
echo "To get LoadBalancer IPs:"
echo "  kubectl get svc -n pihole"
echo ""
echo "To view logs:"
echo "  kubectl logs -n pihole -l app=pihole -f"
echo ""
