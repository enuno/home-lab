#!/bin/bash
# Rancher Deployment Script
# Quick deployment wrapper for Rancher to K3s cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================"
echo "Rancher Deployment to K3s Cluster"
echo "================================================"
echo ""

# Check if vault file exists and is encrypted
if [ -f group_vars/rancher_vault.yml ]; then
    if grep -q "ANSIBLE_VAULT" group_vars/rancher_vault.yml; then
        echo "✓ Vault file is encrypted"
    else
        echo "⚠ WARNING: Vault file is not encrypted!"
        echo "  Run: ansible-vault encrypt group_vars/rancher_vault.yml"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "⚠ WARNING: Vault file not found!"
    echo "  Create group_vars/rancher_vault.yml with your bootstrap password"
    echo "  Then encrypt it: ansible-vault encrypt group_vars/rancher_vault.yml"
    echo ""
    read -p "Continue with default password? (y/N): " -n 1 -r
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

# Deploy Rancher
echo "Deploying Rancher..."
echo ""
echo "This will:"
echo "  1. Install cert-manager (if not already installed)"
echo "  2. Deploy Rancher using Helm"
echo "  3. Configure ingress for Rancher UI access"
echo ""

if grep -q "ANSIBLE_VAULT" group_vars/rancher_vault.yml 2>/dev/null; then
    # Vault is encrypted, ask for password
    ansible-playbook playbooks/rancher-deploy.yml --ask-vault-pass "$@"
else
    # Vault is not encrypted (development/testing)
    ansible-playbook playbooks/rancher-deploy.yml "$@"
fi

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Add DNS/hosts entry:"
echo "   Get ingress IP: kubectl get svc -n kube-system | grep ingress"
echo "   Add to /etc/hosts: <INGRESS_IP> rancher.lab.hashgrid.net"
echo ""
echo "2. Access Rancher UI:"
echo "   URL: https://rancher.lab.hashgrid.net"
echo "   (Accept self-signed certificate warning)"
echo ""
echo "3. Login with bootstrap password and set new password"
echo ""
echo "4. View status:"
echo "   kubectl get all -n cattle-system"
echo ""
echo "5. View logs:"
echo "   kubectl logs -n cattle-system -l app=rancher -f"
echo ""
