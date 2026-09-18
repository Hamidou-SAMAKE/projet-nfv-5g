#!/usr/bin/env bash
# scripts/mesures/serveur-iperf3-local.sh
#
# Lance des serveurs iperf3 DANS le network namespace du conteneur upf (via
# un conteneur "sidecar" `--network container:upf`), pour mesurer la
# capacité réelle de traitement de l'UPF sans la contrainte de bande
# passante du lien Tailscale (cf. docs/cadrage/calibration-tailscale.md —
# ~14-18 Mbit/s réels, qui deviendraient eux-mêmes le goulot d'étranglement
# avant celui de l'UPF et fausseraient la calibration de µ en Phase 4).
#
# Pourquoi un sidecar et pas "iperf3 -s" sur l'hôte : dans
# compose-files/basic/docker-compose.yaml, le service upf est sur le réseau
# bridge "open5gs" (pas network_mode: host). L'interface ogstun (10.45.0.1)
# est donc créée À L'INTÉRIEUR du netns du conteneur upf — cette IP
# n'existe pas sur l'hôte machine A, un serveur qui y écoute doit donc
# partager ce même netns. `--network container:upf` fait exactement ça,
# sans rien modifier à l'image upf.
#
# Paramètres :
#   NB_PORTS   nombre de serveurs à lancer, un par tunnel UE potentiel (5)
#   BASE_PORT  premier port, incrémenté ensuite (5201, cohérent avec
#              scripts/mesures/03-generer-trafic-iperf3.sh)
#
# Prérequis : le conteneur "upf" démarré (scripts/deploiement/02-deploy-open5gs.sh).
# Usage : bash scripts/mesures/serveur-iperf3-local.sh

set -euo pipefail

NB_PORTS="${NB_PORTS:-5}"
BASE_PORT="${BASE_PORT:-5201}"

if ! docker ps --format '{{.Names}}' | grep -qx upf; then
  echo "ERREUR : le conteneur 'upf' n'est pas démarré. Lancez d'abord 02-deploy-open5gs.sh."
  exit 1
fi

echo "==> Nettoyage des serveurs iperf3 locaux précédents..."
docker ps -a --format '{{.Names}}' | grep '^iperf3-local-' | xargs -r docker rm -f > /dev/null || true

echo "==> Lancement de ${NB_PORTS} serveurs iperf3 dans le netns du conteneur upf (ports ${BASE_PORT}+)..."
port="${BASE_PORT}"
for i in $(seq 1 "${NB_PORTS}"); do
  docker run --rm -d \
    --name "iperf3-local-${port}" \
    --network container:upf \
    networkstatic/iperf3 -s -p "${port}" > /dev/null
  echo "  Port ${port} : conteneur iperf3-local-${port}"
  port=$(( port + 1 ))
done

sleep 1
echo "==> Vérification (doit lister ${NB_PORTS} conteneur(s) 'Up') :"
docker ps --filter "name=iperf3-local-" --format "  {{.Names}} : {{.Status}}"

cat <<EOF

Serveurs prêts sur 10.45.0.1:${BASE_PORT}-$(( BASE_PORT + NB_PORTS - 1 )) — adresse
interne au netns de l'UPF, joignable UNIQUEMENT depuis une session UE
établie (pas depuis l'hôte, pas depuis Tailscale).

Avant une campagne complète, vérifiez la joignabilité depuis un vrai tunnel :
  sudo ip netns exec <ns-uesimtun0> curl -m 3 10.45.0.1:${BASE_PORT}   # ou testez via un client iperf3 direct

Pour générer du trafic dessus :
  TARGET_IP=10.45.0.1 bash scripts/mesures/03-generer-trafic-iperf3.sh

Arrêt :
  docker ps -a --format '{{.Names}}' | grep '^iperf3-local-' | xargs -r docker rm -f
EOF
