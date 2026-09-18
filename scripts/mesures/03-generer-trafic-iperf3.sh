#!/usr/bin/env bash
# scripts/mesures/03-generer-trafic-iperf3.sh
#
# Lance un client iperf3 depuis chaque tunnel UE actif (uesimtunN), un par
# tunnel en parallèle (un port dédié chacun), et enregistre les résultats
# (JSON) pour la modélisation (Étudiant B).
#
# Paramètres :
#   TARGET_IP   cible iperf3 (10.45.0.1 par défaut : interface ogstun de
#               l'UPF elle-même, cf. scripts/mesures/serveur-iperf3-local.sh).
#               Mettre TARGET_IP=100.82.162.11 pour cibler la Machine B via
#               Tailscale à la place (cf. docs/cadrage/calibration-tailscale.md).
#   DUREE       durée de chaque test iperf3, en secondes (5 par défaut)
#
# Prérequis : un serveur iperf3 actif sur la cible (par défaut,
# scripts/mesures/serveur-iperf3-local.sh sur cette machine).
#
# Usage :
#   bash scripts/mesures/03-generer-trafic-iperf3.sh
#   TARGET_IP=100.82.162.11 DUREE=20 bash scripts/mesures/03-generer-trafic-iperf3.sh

set -euo pipefail

TARGET_IP="${TARGET_IP:-10.45.0.1}"
DUREE="${DUREE:-5}"
BASE_PORT=5201

for cmd in iperf3 jq; do
  if ! command -v "${cmd}" &>/dev/null; then
    sudo apt update && sudo apt install -y "${cmd}"
  fi
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
OUT_DIR="${REPO_ROOT}/modele/donnees/raw/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUT_DIR}"

echo "==> [1/2] Recherche des tunnels UE actifs (uesimtun)..."
TUNNELS=$(ip -o addr show | grep -oP 'uesimtun\d+' | sort -u || true)

if [ -z "${TUNNELS}" ]; then
    echo "Erreur : aucun tunnel uesimtun détecté. Démarrez d'abord le scénario UE (02-scenario-trafic.sh)."
    exit 1
fi

echo "==> [2/2] Lancement des clients iperf3 via les tunnels (durée ${DUREE}s)..."
PORT=${BASE_PORT}
PIDS=()

for TUN in ${TUNNELS}; do
    IP_LOCAL=$(ip -o -4 addr show dev "${TUN}" | awk '{print $4}' | cut -d/ -f1)
    echo "    ${TUN} (${IP_LOCAL}) -> ${TARGET_IP}:${PORT} ..."
    
    iperf3 -c "${TARGET_IP}" -B "${IP_LOCAL}" -p "${PORT}" -t "${DUREE}" --json \
        > "${OUT_DIR}/iperf3-${TUN}.json" 2> "${OUT_DIR}/iperf3-${TUN}.err" &
    PIDS+=($!)
    PORT=$((PORT + 1))
done

for PID in "${PIDS[@]}"; do
    wait "${PID}" || true
done

echo ""
echo "Résultats enregistrés dans : ${OUT_DIR}/"
echo "Résumé rapide des débits :"
for TUN in ${TUNNELS}; do
    FILE="${OUT_DIR}/iperf3-${TUN}.json"
    if [ -f "${FILE}" ] && grep -q '"bits_per_second"' "${FILE}"; then
        BPS=$(jq -r '.end.sum_received.bits_per_second // .end.sum_sent.bits_per_second // 0' "${FILE}")
        MBPS=$(awk -v bps="${BPS}" 'BEGIN {printf "%.2f", bps/1000000}')
        echo "    iperf3-${TUN} : ${MBPS} Mbit/s"
    else
        echo "    iperf3-${TUN} : Échec (voir ${OUT_DIR}/iperf3-${TUN}.err)"
    fi
done
