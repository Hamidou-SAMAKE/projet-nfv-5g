#!/bin/bash
# scripts/infra/install-tailscale.sh
# Installe et démarre Tailscale. À exécuter sur A ET B, avec le MÊME compte Tailscale
# pour que les deux machines rejoignent le même tailnet (cf. bug rencontré en Phase 3 :
# deux comptes différents = deux tailnets étanches, les machines ne se voient pas).
#
# Usage : ./install-tailscale.sh

set -e

if command -v tailscale &> /dev/null; then
  echo "Tailscale deja installe."
else
  echo "Installation de Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

echo "Activation du service au demarrage..."
sudo systemctl enable --now tailscaled

echo ""
echo "Lancement de l'authentification. Suivez le lien affiche."
echo "IMPORTANT : utilisez le MEME compte que sur l'autre machine du binome."
sudo tailscale up

echo ""
echo "IP Tailscale de cette machine :"
tailscale ip -4

echo ""
echo "Verification des pairs visibles sur le tailnet :"
tailscale status
echo ""
echo "Si l'autre machine n'apparait PAS ci-dessus, verifiez que vous etes bien"
echo "connectes avec le meme compte (email) des deux cotes."
