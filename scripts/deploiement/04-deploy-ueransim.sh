#!/usr/bin/env bash
# scripts/deploiement/04-deploy-ueransim.sh
#
# Installe les dépendances, compile UERANSIM (gNB + UE simulés) depuis les
# sources, puis démarre le gNB et l'UE en arrière-plan.
#
# Le gNB tourne nativement sur la même machine que le 5GC conteneurisé : il a
# besoin de SA PROPRE adresse IP locale (distincte de celle du 5GC), sans quoi
# son port GTP-U (2152) entre en conflit avec celui publié par le conteneur
# UPF. Ce script ajoute donc une IP secondaire sur l'interface réseau
# existante (ex. 192.168.1.13 si le 5GC est en 192.168.1.12) — c'est un
# correctif nécessaire, pas une simplification : voir
# docs/architecture/choix-deploiement-docker.md pour le détail des trois bugs
# rencontrés (PLMN, port GTP, endpoint réseau) et pourquoi cette IP séparée
# est indispensable.
#
# Prérequis : scripts/deploiement/02-deploy-open5gs.sh exécuté (le 5GC doit
# tourner), avec un abonné correspondant à config/ueransim/ue.yaml créé dans
# la WebUI (IMSI 001010000000001, DNN internet, slice SST=1/SD=000001).
#
# Usage : bash scripts/deploiement/04-deploy-ueransim.sh
# Variables d'override possibles : HOST_IP, GNB_IP (sinon auto-détectées)

set -euo pipefail

UERANSIM_VERSION="v3.2.7"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/UERANSIM"
RUNTIME_DIR="${PROJECT_ROOT}/vendor/ueransim-runtime"
LOG_DIR="${PROJECT_ROOT}/vendor/logs-ueransim"

echo "==> [1/6] Détection des adresses IP (5GC et gNB)..."
OPEN5GS_ENV="${PROJECT_ROOT}/vendor/docker-open5gs/.env"
if [ -z "${HOST_IP:-}" ] && [ -f "${OPEN5GS_ENV}" ]; then
  # Source de vérité fiable : l'IP réellement utilisée pour publier les ports
  # Docker (AMF/UPF), plutôt que de deviner via 'ip route' — peu fiable dès
  # que la machine a plusieurs IP sur la même interface (cas rencontré : la
  # détection automatique a un jour renvoyé une IP différente de celle
  # utilisée par Docker, recréant le conflit de port du bug n°5).
  HOST_IP="$(grep '^DOCKER_HOST_IP=' "${OPEN5GS_ENV}" | cut -d= -f2)"
fi
HOST_IP="${HOST_IP:-$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')}"
IFACE="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')"
if [ -z "${HOST_IP}" ] || [ -z "${IFACE}" ]; then
  echo "Impossible de détecter l'IP/l'interface automatiquement."
  echo "Relancez avec : HOST_IP=x.x.x.x GNB_IP=x.x.x.y bash $0"
  exit 1
fi
# IP dédiée au gNB par défaut : dernier octet de HOST_IP + 1 (modifiable via
# la variable d'environnement GNB_IP si elle entre en conflit sur le réseau).
LAST_OCTET="$(echo "${HOST_IP}" | awk -F. '{print $4}')"
DEFAULT_GNB_IP="$(echo "${HOST_IP}" | awk -F. -v o="$(( (LAST_OCTET % 254) + 1 ))" '{print $1"."$2"."$3"."o}')"
GNB_IP="${GNB_IP:-${DEFAULT_GNB_IP}}"
echo "    5GC (AMF/UPF) : ${HOST_IP}   |   gNB (dédiée) : ${GNB_IP} sur ${IFACE}"

echo "==> [2/6] Ajout de l'IP dédiée au gNB sur ${IFACE} (si absente)..."
if ! ip addr show "${IFACE}" | grep -q "${GNB_IP}/"; then
  sudo ip addr add "${GNB_IP}/24" dev "${IFACE}"
else
  echo "    Déjà présente."
fi

echo "==> [3/6] Installation des dépendances de build/exécution..."
sudo apt update
sudo apt install -y make gcc g++ libsctp-dev lksctp-tools iproute2 git cmake

echo "==> [4/6] Récupération et compilation des sources UERANSIM (${UERANSIM_VERSION})..."
mkdir -p "$(dirname "${VENDOR_DIR}")" "${LOG_DIR}" "${RUNTIME_DIR}"
if [ ! -d "${VENDOR_DIR}" ]; then
  git clone --branch "${UERANSIM_VERSION}" --depth 1 https://github.com/aligungr/UERANSIM.git "${VENDOR_DIR}"
else
  echo "    Sources déjà présentes."
fi
cd "${VENDOR_DIR}"
make

echo "==> [5/6] Génération des configs (templates + IPs détectées)..."
sed -e "s/__AMF_IP__/${HOST_IP}/g" -e "s/__GNB_IP__/${GNB_IP}/g" \
  "${PROJECT_ROOT}/config/ueransim/gnb.yaml" > "${RUNTIME_DIR}/gnb.yaml"
sed -e "s/__AMF_IP__/${HOST_IP}/g" -e "s/__GNB_IP__/${GNB_IP}/g" \
  "${PROJECT_ROOT}/config/ueransim/ue.yaml" > "${RUNTIME_DIR}/ue.yaml"

echo "==> [6/6] Démarrage du gNB puis de l'UE..."
sudo pkill -9 -f nr-gnb 2>/dev/null || true
sudo pkill -9 -f nr-ue 2>/dev/null || true
sleep 2
sudo nohup ./build/nr-gnb -c "${RUNTIME_DIR}/gnb.yaml" > "${LOG_DIR}/gnb.log" 2>&1 &
sleep 3
sudo nohup ./build/nr-ue -c "${RUNTIME_DIR}/ue.yaml" > "${LOG_DIR}/ue.log" 2>&1 &
sleep 8

cat <<EOF

gNB et UE lancés en arrière-plan.
  Logs gNB : ${LOG_DIR}/gnb.log
  Logs UE  : ${LOG_DIR}/ue.log

Vérifiez :
  tail -n 20 ${LOG_DIR}/ue.log
  ip addr show uesimtun0
  sudo ping -I uesimtun0 8.8.8.8 -c 4

Pour arrêter :
  sudo pkill -f nr-gnb; sudo pkill -f nr-ue
EOF
