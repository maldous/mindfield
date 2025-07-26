#!/bin/bash
set -euo pipefail

# MicroK8s Cluster Setup Script
echo "🚀 Setting up MicroK8s cluster for MindField migration"

# Check if MicroK8s is installed
if ! command -v microk8s &> /dev/null; then
    echo "❌ MicroK8s is not installed. Please install it first:"
    echo "sudo snap install microk8s --classic"
    exit 1
fi

# Add user to microk8s group
echo "👤 Adding current user to microk8s group..."
sudo usermod -a -G microk8s $USER
echo "Please log out and back in for group changes to take effect."

# Wait for MicroK8s to be ready
echo "⏳ Waiting for MicroK8s to be ready..."
microk8s status --wait-ready

# Enable required addons
echo "🔧 Enabling required MicroK8s addons..."
microk8s enable dns storage metallb:10.0.0.200-10.0.0.250 registry

# Setup kubectl alias
echo "🔗 Setting up kubectl alias..."
mkdir -p ~/.kube
microk8s config > ~/.kube/config

# Install Helm
if ! command -v helm &> /dev/null; then
    echo "📦 Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Verify installation
echo "✅ Verifying installation..."
kubectl cluster-info
kubectl get nodes
helm version

echo "🎉 MicroK8s cluster setup complete!"
echo "Next steps:"
echo "1. Copy .env.example to .env and fill in your values"
echo "2. Run 'make migrate' to start the migration"