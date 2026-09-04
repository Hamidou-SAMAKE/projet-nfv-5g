#!/usr/bin/env bash
# scripts/mesures/02-scenario-trafic.sh
#
# Lance un scénario de trafic paramétrable : montée en charge par paliers
# d'UE simulés (UERANSIM), au-dessus du gNB déjà déployé. Chaque UE établit
# sa propre session PDU (interface uesimtunN), en s'appuyant sur les abonnés
# provisionnés par 01-provisionner-abonnes.sh.
#
# Paramètres (variables d'environnement, valeurs par défaut entre parenthèses) :
#   NB_UE          nombre total d'UE à simuler (10)
#   PALIER_TAILLE  nombre d'UE ajoutés à chaque palier (5)
#   PALIER_DELAI   secondes d'attente entre deux paliers (30)
#   STAGGER_MS     délai (ms) entre le démarrage de deux UE au sein d'un palier (500)
#
# Usage :
#   bash scripts/mesures/02-scenario-trafic.sh
#   NB_UE=20 PALIER_TAILLE=4 PALIER_DELAI=20 bash scripts/mesures/02-scenario-trafic.sh
#
# Prérequis : scripts/deploiement/02-deploy-open5gs.sh (5GC actif) et
# scripts/mesures/01-provisionner-abonnes.sh (assez d'abonnés pour NB_UE) déjà
# exécutés.

set -euo pipefail

BASE_IMSI="001010000000001"
NB_UE="${NB_UE:-10}"
PALIER_TAILLE="${PALIER_TAILLE:-5}"
PALIER_DELAI="${PALIER_DELAI:-30}"
STAGGER_MS="${STAGGER_MS:-500}"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/UERANSIM"
RUNTIME_DIR="${PROJECT_ROOT}/vendor/ueransim-runtime"
LOG_DIR="${PROJECT_ROOT}/vendor/logs-mesures"
mkdir -p "${RUNTIME_DIR}/scenario" "${LOG_DIR}"

HOST_IP="${HOST_IP:-}"
OPEN5GS_ENV="${PROJECT_ROOT}/vendor/docker-open5gs/.env"
if [ -z "${HOST_IP}" ] && [ -f "${OPEN5GS_ENV}" ]; then
  HOST_IP="$(grep '^DOCKER_HOST_IP=' "${OPEN5GS_ENV}" | cut -d= -f2)"
fi
GNB_IP="${GNB_IP:-}"
if [ -z "${GNB_IP}" ]; then
  LAST_OCTET="$(echo "${HOST_IP}" | awk -F. '{print $4}')"
  GNB_IP="$(echo "${HOST_IP}" | awk -F. -v o="$(( (LAST_OCTET % 254) + 1 ))" '{print $1"."$2"."$3"."o}')"
fi

echo "==> [1/3] Vérification du gNB (le démarre si nécessaire)..."
if ! pgrep -f nr-gnb > /dev/null; then
  HOST_IP="${HOST_IP}" GNB_IP="${GNB_IP}" bash "${PROJECT_ROOT}/scripts/deploiement/04-deploy-ueransim.sh" > "${LOG_DIR}/gnb-init.log" 2>&1
  sleep 3
  sudo pkill -f nr-ue 2>/dev/null || true   # on relance nous-mêmes les UE ci-dessous
  sleep 1
else
  echo "    gNB déjà actif."
fi

echo "==> [2/3] Montée en charge : ${NB_UE} UE au total, par paliers de ${PALIER_TAILLE} (délai ${PALIER_DELAI}s)..."

batch_offset=0
batch_num=0
while [ "${batch_offset}" -lt "${NB_UE}" ]; do
  taille=$(( NB_UE - batch_offset < PALIER_TAILLE ? NB_UE - batch_offset : PALIER_TAILLE ))
  start_imsi="$(( $(echo "${BASE_IMSI}" | sed 's/^0*//') + batch_offset ))"
  start_imsi_padded="$(printf "%015d" "${start_imsi}")"

  batch_cfg="${RUNTIME_DIR}/scenario/ue-batch-${batch_num}.yaml"
  sed -e "s/__AMF_IP__/${HOST_IP}/g" -e "s/__GNB_IP__/${GNB_IP}/g" \
      -e "s/imsi-${BASE_IMSI}/imsi-${start_imsi_padded}/" \
      "${PROJECT_ROOT}/config/ueransim/ue.yaml" > "${batch_cfg}"

  echo "    Palier ${batch_num} : ${taille} UE à partir de imsi-${start_imsi_padded}"
  sudo nohup "${VENDOR_DIR}/build/nr-ue" -c "${batch_cfg}" -n "${taille}" -t "${STAGGER_MS}" \
    > "${LOG_DIR}/ue-batch-${batch_num}.log" 2>&1 &

  batch_offset=$(( batch_offset + taille ))
  batch_num=$(( batch_num + 1 ))
  if [ "${batch_offset}" -lt "${NB_UE}" ]; then
    sleep "${PALIER_DELAI}"
  fi
done

echo "==> [3/3] Récapitulatif des tunnels UE actifs :"
sleep 5
ip -o addr show | grep uesimtun || echo "    Aucun tunnel actif pour l'instant — vérifiez les logs dans ${LOG_DIR}/"

cat <<EOF

Scénario lancé : ${NB_UE} UE en ${batch_num} palier(s).
Logs par palier : ${LOG_DIR}/ue-batch-*.log
Tunnels actifs  : ip -o addr show | grep uesimtun

Prochaine étape : générer du trafic réel à travers ces tunnels avec
  bash scripts/mesures/03-generer-trafic-iperf3.sh

Pour arrêter tous les UE :
  sudo pkill -f nr-ue
EOF
