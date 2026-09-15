#!/usr/bin/env bash
# scripts/deploiement/05-activer-metriques-prometheus.sh
#
# Active l'export natif de métriques Prometheus (port 9090) sur les
# fonctions réseau AMF, SMF et UPF — nécessaire pour la stratégie de mesure
# du modèle de files d'attente (cf. docs/architecture/modele-files-attente.md,
# §5 : fivegs_upffunction_*, process_cpu_seconds_total...).
#
# Idempotent : si la section "metrics:" existe déjà dans un fichier de
# config, il n'est pas modifié une seconde fois.
#
# Usage : bash scripts/deploiement/05-activer-metriques-prometheus.sh
# (nécessite scripts/deploiement/02-deploy-open5gs.sh déjà exécuté)

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/docker-open5gs"
CONFIG_DIR="${VENDOR_DIR}/configs/basic"
COMPOSE_FILE="${VENDOR_DIR}/compose-files/basic/docker-compose.yaml"

add_metrics_block() {
  local file="$1" anchor="$2"
  if grep -q "^  metrics:" "$file"; then
    echo "    Déjà présent : $(basename "$file")"
    return
  fi
  sed -i "/^  ${anchor}:/i\\  metrics:\\n    server:\\n      - address: 0.0.0.0\\n        port: 9090" "$file"
  echo "    Ajouté : $(basename "$file")"
}

echo "==> [1/3] Ajout de la section 'metrics' dans les configs (si absente)..."
add_metrics_block "${CONFIG_DIR}/upf.yaml" "session"
add_metrics_block "${CONFIG_DIR}/smf.yaml" "session"
add_metrics_block "${CONFIG_DIR}/amf.yaml" "guami"

echo "==> [2/3] Recréation des conteneurs amf, smf, upf..."
cd "${VENDOR_DIR}"
docker compose -f "${COMPOSE_FILE}" --env-file=.env up -d --force-recreate amf smf upf
sleep 8

echo "==> [3/3] Vérification des endpoints /metrics..."
for nf in amf smf upf; do
  ip="$(docker inspect -f '{{.NetworkSettings.Networks.open5gs.IPAddress}}' "$nf")"
  if curl -s --max-time 3 "http://${ip}:9090/metrics" | grep -q "^# HELP"; then
    echo "    ${nf} (${ip}:9090) : OK"
  else
    echo "    ${nf} (${ip}:9090) : ÉCHEC — vérifier 'docker logs ${nf}'"
  fi
done

cat <<EOF

Métriques activées en interne (réseau Docker "open5gs").

Accès depuis l'hôte (pour test local) :
  AMF_IP=\$(docker inspect -f '{{.NetworkSettings.Networks.open5gs.IPAddress}}' amf)
  curl http://\$AMF_IP:9090/metrics

Accès externe (pour Prometheus sur la machine B via Tailscale) : PAS ENCORE
configuré — nécessite de publier ces ports sur l'IP hôte (3 ports distincts,
ex. 9091/9092/9093 -> 9090 interne) et de coordonner avec l'Étudiant B sur
sa configuration de scraping Prometheus.
EOF
