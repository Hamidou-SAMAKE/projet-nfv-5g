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

TAILSCALE_IP=$(tailscale ip -4)
if [ -z "$TAILSCALE_IP" ]; then
  echo "ERREUR : impossible de recuperer l'IP Tailscale. Verifiez que Tailscale est bien connecte (tailscale status)."
  exit 1
fi

echo "Installation de K3s en mode serveur, avec node-ip force sur Tailscale (${TAILSCALE_IP})..."
echo "(evite la dependance a l'IP locale DHCP, source d'un bug rencontre en Phase 3 :"
echo " l'agent perdait la connexion au control-plane apres un changement d'IP locale/reboot)"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=${TAILSCALE_IP}" sh -

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
