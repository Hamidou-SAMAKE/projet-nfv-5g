#!/usr/bin/env bash
# scripts/infra/00-cleanup-native.sh
#
# Nettoie une éventuelle installation native précédente d'Open5GS (et libère
# ce dont Docker aura besoin : port MongoDB 27017, interface ogstun) avant de
# repartir sur le déploiement conteneurisé (cf.
# docs/architecture/choix-deploiement-docker.md).
#
# Prudent par design : arrête/désinstalle ce qui peut être détecté et annulé
# sans risque (services systemd, paquet apt, MongoDB natif, interface ogstun,
# règle NAT). Pour une installation compilée à la main (Open5GS et/ou
# UERANSIM buildés depuis les sources), le script se contente de REPÉRER les
# dossiers candidats et vous laisse confirmer la suppression vous-même.
#
# Usage : bash scripts/infra/00-cleanup-native.sh

set -uo pipefail  # pas de -e : on veut continuer même si un service/paquet est absent

echo "==> [1/6] Arrêt des services systemd Open5GS (natifs)..."
mapfile -t OPEN5GS_UNITS < <(systemctl list-units --all --type=service 2>/dev/null | grep -o 'open5gs-[a-z]*\.service' | sort -u)
if [ "${#OPEN5GS_UNITS[@]}" -eq 0 ]; then
  echo "    Aucun service open5gs-*.service trouvé."
else
  for unit in "${OPEN5GS_UNITS[@]}"; do
    echo "    Arrêt/désactivation de ${unit}"
    sudo systemctl stop "${unit}" 2>/dev/null
    sudo systemctl disable "${unit}" 2>/dev/null
  done
fi

echo "==> [2/6] Désinstallation du paquet open5gs (si installé via apt/PPA)..."
if dpkg -l 2>/dev/null | grep -q '^ii.*open5gs'; then
  sudo apt purge -y 'open5gs*'
  sudo add-apt-repository --remove -y ppa:open5gs/latest 2>/dev/null || true
  sudo apt autoremove -y
  echo "    Paquets open5gs purgés."
else
  echo "    Pas de paquet apt 'open5gs' détecté (probablement compilé depuis les sources, voir étape 6)."
fi

echo "==> [3/6] Arrêt de MongoDB natif (libère le port 27017 pour le MongoDB conteneurisé)..."
if systemctl list-unit-files 2>/dev/null | grep -q '^mongod'; then
  sudo systemctl stop mongod 2>/dev/null
  sudo systemctl disable mongod 2>/dev/null
  echo "    Service mongod arrêté/désactivé."
  echo "    (Non désinstallé — purge complète si besoin : sudo apt purge -y 'mongodb-org*')"
else
  echo "    Pas de service mongod natif détecté."
fi

echo "==> [4/6] Suppression de l'interface TUN ogstun (si présente)..."
if ip link show ogstun &>/dev/null; then
  sudo ip link set ogstun down 2>/dev/null
  sudo ip tuntap del name ogstun mode tun 2>/dev/null
  echo "    Interface ogstun supprimée."
else
  echo "    Pas d'interface ogstun active."
fi

echo "==> [5/6] Nettoyage de la règle NAT du testbed natif (si présente)..."
if sudo iptables -t nat -C POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null; then
  sudo iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
  echo "    Règle NAT supprimée."
else
  echo "    Pas de règle NAT correspondante trouvée sur ce sous-réseau (vérifiez manuellement avec 'sudo iptables -t nat -L POSTROUTING -n' si vous aviez configuré un autre sous-réseau)."
fi

echo "==> [6/6] Recherche de sources compilées à la main (Open5GS / UERANSIM)..."
echo "    Rien n'est supprimé automatiquement ici — vérifiez la liste puis supprimez vous-même :"
FOUND_ANY=0
for dir in "$HOME"/open5gs "$HOME"/Open5GS "$HOME"/UERANSIM "$HOME"/ueransim "$HOME"/src/open5gs "$HOME"/src/UERANSIM /usr/src/open5gs /opt/open5gs /opt/UERANSIM; do
  if [ -d "$dir" ]; then
    FOUND_ANY=1
    echo "    Trouvé : $dir  ($(du -sh "$dir" 2>/dev/null | cut -f1))"
    echo "      -> pour supprimer : rm -rf \"$dir\""
  fi
done
if [ "$FOUND_ANY" -eq 0 ]; then
  echo "    Aucun dossier candidat trouvé aux emplacements habituels."
  echo "    Si vous aviez cloné/compilé ailleurs, cherchez avec : find / -maxdepth 4 -iname '*ueransim*' -o -iname '*open5gs*' 2>/dev/null"
fi

echo
echo "Nettoyage terminé. Avant de déployer en Docker, vérifiez qu'aucun port n'est encore occupé :"
echo "  sudo ss -tulpn | grep -E ':(9999|2152|27017)\\b'   # WebUI / N3 / MongoDB (doit être vide)"
echo "  sudo ss -a | grep 38412                            # N2 en SCTP (doit être vide)"
