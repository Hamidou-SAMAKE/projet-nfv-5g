#!/bin/bash
# scripts/infra/install-k3s-server.sh
# Installe K3s en mode serveur (control-plane) sur la machine B.
# Pré-requis : Tailscale deja installe et connecte (cf. install-tailscale.sh).
#
# Usage : ./install-k3s-server.sh

set -e

if command -v k3s &> /dev/null; then
  echo "K3s deja installe. Verification du statut..."
  sudo systemctl status k3s --no-pager || true
  exit 0
fi

echo "Installation de K3s en mode serveur..."
curl -sfL https://get.k3s.io | sh -

echo "Verification du service..."
sudo systemctl status k3s --no-pager

echo ""
echo "Correctif : forcer K3s a attendre que Tailscale soit pret au demarrage"
echo "(bug connu : k3s peut demarrer avant que l'IP tailscale0 soit assignee)"
sudo mkdir -p /etc/systemd/system/k3s.service.d
sudo tee /etc/systemd/system/k3s.service.d/wait-for-tailscale.conf > /dev/null << 'EOF'
[Unit]
After=tailscaled.service
Requires=tailscaled.service
EOF
sudo systemctl daemon-reload
sudo systemctl restart k3s

echo ""
echo "Configuration de kubectl pour l'utilisateur courant..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(whoami)":"$(whoami)" ~/.kube/config

if ! grep -q "export KUBECONFIG=~/.kube/config" ~/.bashrc; then
  echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
fi
export KUBECONFIG=~/.kube/config

echo ""
echo "Node K3s :"
kubectl get nodes

echo ""
echo "Token pour connecter un agent (machine A) :"
echo "-> a recuperer avec : sudo cat /var/lib/rancher/k3s/server/node-token"
echo "-> NE PAS partager ce token en clair dans un depot public ou un chat."
