#!/usr/bin/env bash
# scripts/infra/00-install-docker.sh
#
# Prérequis machine A : installe Docker Engine + Compose plugin sur Ubuntu,
# et active l'IP forwarding nécessaire au plan usager (UPF) du testbed 5G.
#
# Usage : bash scripts/infra/00-install-docker.sh

set -euo pipefail

echo "==> [1/4] Mise à jour du système et paquets de base..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg git make

echo "==> [2/4] Installation de Docker Engine (dépôt officiel Docker)..."
if ! command -v docker &>/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "    Docker déjà installé : $(docker --version)"
fi

echo "==> [3/4] Ajout de l'utilisateur courant au groupe docker..."
sudo usermod -aG docker "${USER}"

echo "==> [4/4] Activation de l'IP forwarding (obligatoire pour le trafic UE via l'UPF)..."
sudo sysctl -w net.ipv4.ip_forward=1
if ! grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf > /dev/null
fi

echo
echo "Installation terminée."
echo "IMPORTANT : déconnectez-vous/reconnectez-vous (ou lancez 'newgrp docker')"
echo "pour pouvoir utiliser Docker sans sudo, puis vérifiez avec :"
echo "  docker --version && docker compose version"
