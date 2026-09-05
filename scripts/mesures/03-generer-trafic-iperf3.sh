#!/usr/bin/env bash
# scripts/mesures/03-generer-trafic-iperf3.sh
#
# Lance un client iperf3 depuis chaque tunnel UE actif (uesimtunN) vers un
# serveur iperf3 cible sur la Machine B (via Tailscale) — génère du trafic
# réel à travers les sessions PDU établies par 02-scenario-trafic.sh, et
# enregistre les résultats (JSON) pour la modélisation (Étudiant B).
#
# Paramètres :
#   TARGET_IP   IP Tailscale du serveur iperf3 sur la Machine B
#               (100.82.162.11 par défaut, cf. docs/cadrage/calibration-tailscale.md)
#   DUREE       durée de chaque test iperf3, en secondes (20 par défaut)
#
# Prérequis : un serveur iperf3 actif sur la Machine B, cf.
# scripts/mesures/serveur-iperf3-machine-b.sh (à exécuter sur la Machine B).
#
# Usage :
#   bash scripts/mesures/03-generer-trafic-iperf3.sh
#   TARGET_IP=100.82.162.11 DUREE=30 bash scripts/mesures/03-generer-trafic-iperf3.sh

set -euo pipefail

TARGET_IP="${TARGET_IP:-100.82.162.11}"
DUREE="${DUREE:-20}"
BASE_PORT="${BASE_PORT:-5201}"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="${PROJECT_ROOT}/modele/donnees/raw"
TS="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${OUT_DIR}/run-${TS}"
mkdir -p "${RUN_DIR}"

echo "==> [1/3] Vérification d'iperf3..."
if ! command -v iperf3 &>/dev/null; then
  sudo apt update && sudo apt install -y iperf3
fi

echo "==> [2/3] Vérification de la joignabilité du serveur cible (${TARGET_IP})..."
if ! ping -c 2 -W 2 "${TARGET_IP}" > /dev/null 2>&1; then
  echo "ATTENTION : ${TARGET_IP} ne répond pas au ping. Vérifiez que Tailscale"
  echo "est actif et que le serveur iperf3 tourne sur la Machine B avant de continuer."
fi

echo "==> [3/3] Lancement d'un client iperf3 par tunnel UE actif (durée ${DUREE}s chacun)..."
mapfile -t TUNNELS < <(ip -o addr show | awk '/uesimtun/ {print $2}' | sort -u)

if [ "${#TUNNELS[@]}" -eq 0 ]; then
  echo "Aucun tunnel uesimtunN actif. Lancez d'abord scripts/mesures/02-scenario-trafic.sh."
  exit 1
fi

echo "    ${#TUNNELS[@]} tunnel(s) détecté(s) : ${TUNNELS[*]}"
echo "    (un port dédié par tunnel, à partir de ${BASE_PORT} — iperf3 ne traite"
echo "    qu'un client à la fois par port, indispensable pour du trafic concurrent)"

PIDS=()
port="${BASE_PORT}"
for iface in "${TUNNELS[@]}"; do
  local_ip="$(ip -o -4 addr show "${iface}" | awk '{print $4}' | cut -d/ -f1)"
  if [ -z "${local_ip}" ]; then continue; fi
  out_file="${RUN_DIR}/iperf3-${iface}.json"
  echo "    ${iface} (${local_ip}) -> ${TARGET_IP}:${port} ..."
  iperf3 -c "${TARGET_IP}" -p "${port}" -B "${local_ip}" -t "${DUREE}" -J > "${out_file}" 2> "${RUN_DIR}/iperf3-${iface}.err" &
  PIDS+=("$!")
  port=$(( port + 1 ))
done

echo "    En attente de la fin des ${#PIDS[@]} tests (parallèles, ~${DUREE}s)..."
wait "${PIDS[@]}" 2>/dev/null || true

cat <<EOF

Résultats enregistrés dans : ${RUN_DIR}/
  iperf3-uesimtunN.json   résultat structuré (débit, retransmissions...)
  iperf3-uesimtunN.err    erreurs éventuelles (ex. serveur injoignable)

Résumé rapide des débits :
EOF
for f in "${RUN_DIR}"/iperf3-*.json; do
  [ -s "$f" ] || continue
  iface="$(basename "$f" .json)"
  mbps="$(python3 -c "import json,sys
try:
    d=json.load(open('$f'))
    print(round(d['end']['sum_received']['bits_per_second']/1e6,2))
except Exception:
    print('N/A')")"
  echo "  ${iface} : ${mbps} Mbit/s"
done
