#!/bin/bash
# scripts/infra/install-k3s-agent.sh
# Installe K3s en mode agent (worker) sur la machine A.
# Pré-requis : Tailscale deja installe et connecte, K3s deja installe sur B (serveur).
#
# Usage : ./install-k3s-agent.sh <IP_TAILSCALE_B> <TOKEN>
# Exemple : ./install-k3s-agent.sh 100.82.162.11 K10xxxxx...

set -e

SERVER_IP=$1
TOKEN=$2

if [ -z "$SERVER_IP" ] || [ -z "$TOKEN" ]; then
  echo "Usage: $0 <IP_TAILSCALE_B> <TOKEN>"
  echo "Recuperez le token sur B avec : sudo cat /var/lib/rancher/k3s/server/node-token"
  exit 1
fi

echo "Verification/correction de la politique iptables FORWARD"
echo "(risque connu : Docker peut positionner FORWARD en DROP, ce qui casse le reseau K3s/Flannel)"
CURRENT_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -oP '(?<=policy )[A-Z]+' || echo "INCONNU")
echo "Politique actuelle : $CURRENT_POLICY"
if [ "$CURRENT_POLICY" == "DROP" ]; then
  echo "Correction : passage en ACCEPT..."
  sudo iptables -P FORWARD ACCEPT
else
  echo "Politique deja correcte (ACCEPT ou non-bloquante), aucune action necessaire."
fi

if command -v k3s &> /dev/null; then
  echo "K3s deja installe sur cette machine. Verification du statut agent..."
  sudo systemctl status k3s-agent --no-pager || true
  exit 0
fi

echo ""
echo "Installation de K3s en mode agent, connexion a ${SERVER_IP}..."
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" K3S_TOKEN="${TOKEN}" sh -

echo ""
echo "Correctif : forcer k3s-agent a attendre que Tailscale soit pret au demarrage"
sudo mkdir -p /etc/systemd/system/k3s-agent.service.d
sudo tee /etc/systemd/system/k3s-agent.service.d/wait-for-tailscale.conf > /dev/null << 'EOF'
[Unit]
After=tailscaled.service
Requires=tailscaled.service
EOF
sudo systemctl daemon-reload
sudo systemctl restart k3s-agent

echo ""
echo "Verification : conteneurs Docker existants (Open5GS) toujours actifs apres K3s ?"
docker ps

echo ""
echo "Agent installe. Verifiez depuis B avec : kubectl get nodes"
