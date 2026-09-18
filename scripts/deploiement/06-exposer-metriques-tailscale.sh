#!/usr/bin/env bash
# scripts/deploiement/06-exposer-metriques-tailscale.sh
#
# Publie sur l'IP Tailscale de cette machine (A) les ports de métriques
# AMF/SMF/UPF activés en interne par 05-activer-metriques-prometheus.sh,
# pour que Prometheus (machine B, cluster K8s) puisse les scraper à
# distance via le tailnet.
#
# Ports publiés (IP_TAILSCALE_A:PORT_HOTE -> 9090 interne au conteneur) :
#   AMF -> 9091
#   SMF -> 9092
#   UPF -> 9093
# (SMF n'a par défaut aucune section "ports:" dans le compose "basic" —
# ce script l'ajoute.)
#
# Binding sur l'IP Tailscale précise (pas 0.0.0.0), même logique que le
# correctif déjà appliqué par 02-deploy-open5gs.sh sur les ports N2/N3 :
# n'exposer ces métriques que sur le tailnet, pas sur le réseau local/public.
#
# Idempotent : si un port est déjà publié, il n'est pas ajouté une seconde fois.
#
# Usage : bash scripts/deploiement/06-exposer-metriques-tailscale.sh
# Pré-requis :
#   - scripts/deploiement/05-activer-metriques-prometheus.sh déjà exécuté
#   - Tailscale installé et connecté (scripts/infra/install-tailscale.sh)
#
# Étape suivante (côté B) : donner l'IP Tailscale affichée en fin de script
# à l'Étudiant B pour scripts/infra/appliquer-metriques-5gc-externe.sh

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/docker-open5gs"
COMPOSE_FILE="${VENDOR_DIR}/compose-files/basic/docker-compose.yaml"

echo "==> [1/4] Détection de l'IP Tailscale de cette machine..."
TAILSCALE_IP="$(tailscale ip -4)"
if [ -z "${TAILSCALE_IP}" ]; then
  echo "ERREUR : impossible de récupérer l'IP Tailscale. Vérifiez 'tailscale status'."
  exit 1
fi
echo "    IP Tailscale : ${TAILSCALE_IP}"

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "ERREUR : ${COMPOSE_FILE} introuvable."
  echo "Avez-vous exécuté scripts/deploiement/02-deploy-open5gs.sh ?"
  exit 1
fi

echo "==> [2/4] Publication des ports de métriques sur le compose Open5GS..."

if grep -q ':9091:9090/tcp"' "${COMPOSE_FILE}"; then
  echo "    Déjà publié : AMF (9091)"
else
  sed -i "/:38412:38412\/sctp\"/a\\      - \"${TAILSCALE_IP}:9091:9090/tcp\"" "${COMPOSE_FILE}"
  echo "    Ajouté : AMF -> ${TAILSCALE_IP}:9091 -> 9090/tcp"
fi

if grep -q ':9093:9090/tcp"' "${COMPOSE_FILE}"; then
  echo "    Déjà publié : UPF (9093)"
else
  sed -i "/:2152:2152\/udp\"/a\\      - \"${TAILSCALE_IP}:9093:9090/tcp\"" "${COMPOSE_FILE}"
  echo "    Ajouté : UPF -> ${TAILSCALE_IP}:9093 -> 9090/tcp"
fi

if grep -q ':9092:9090/tcp"' "${COMPOSE_FILE}"; then
  echo "    Déjà publié : SMF (9092)"
else
  # SMF n'a pas de section "ports:" par défaut : on l'ajoute juste après
  # sa ligne de config (unique dans le fichier), avant "depends_on:".
  sed -i "/target: \/etc\/open5gs\/custom\/smf.yaml/a\\    ports:\\n      - \"${TAILSCALE_IP}:9092:9090/tcp\"" "${COMPOSE_FILE}"
  echo "    Ajouté : SMF -> ${TAILSCALE_IP}:9092 -> 9090/tcp"
fi

echo "==> [3/4] Recréation des conteneurs amf, smf, upf..."
cd "${VENDOR_DIR}"
docker compose -f "${COMPOSE_FILE}" --env-file=.env up -d --force-recreate amf smf upf
sleep 8

echo "==> [4/4] Vérification depuis l'IP Tailscale (comme le ferait Prometheus sur B)..."
declare -A PORTS=([amf]=9091 [smf]=9092 [upf]=9093)
for nf in "${!PORTS[@]}"; do
  port="${PORTS[$nf]}"
  if curl -s --max-time 3 "http://${TAILSCALE_IP}:${port}/metrics" | grep -q "^# HELP"; then
    echo "    ${nf} (${TAILSCALE_IP}:${port}) : OK"
  else
    echo "    ${nf} (${TAILSCALE_IP}:${port}) : ÉCHEC — vérifier 'docker logs ${nf}' et le pare-feu local"
  fi
done

cat <<EOF

Métriques exposées sur le tailnet. À transmettre à l'Étudiant B :

  IP Tailscale (machine A) : ${TAILSCALE_IP}
  AMF : ${TAILSCALE_IP}:9091/metrics
  SMF : ${TAILSCALE_IP}:9092/metrics
  UPF : ${TAILSCALE_IP}:9093/metrics

Côté B, appliquer :
  bash scripts/infra/appliquer-metriques-5gc-externe.sh ${TAILSCALE_IP}
EOF
