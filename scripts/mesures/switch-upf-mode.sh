#!/bin/bash
# scripts/mesures/switch-upf-mode.sh
# Bascule la configuration SMF entre Run 1 (UPF locale sur A) et Run 2 (UPF distante sur B).
# Usage : ./switch-upf-mode.sh [run1|run2]

set -e

MODE=$1
REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_DIR="$REPO_ROOT/vendor/docker-open5gs/configs/basic"
COMPOSE_FILE="$REPO_ROOT/vendor/docker-open5gs/compose-files/basic/docker-compose.yaml"

if [ "$MODE" == "run1" ]; then
  echo "Bascule vers Run 1 : UPF locale (machine A)"
  cp "$REPO_ROOT/docs/architecture/smf-run1.yaml" "$CONFIG_DIR/smf.yaml"
elif [ "$MODE" == "run2" ]; then
  echo "Bascule vers Run 2 : UPF distante (machine B)"
  echo "Verification de l'IP Tailscale de B avant bascule..."
  cp "$REPO_ROOT/docs/architecture/smf-run2.yaml" "$CONFIG_DIR/smf.yaml"
  echo "ATTENTION : verifiez que l'IP dans smf-run2.yaml correspond bien a 'tailscale ip -4' execute sur B a l'instant."
else
  echo "Usage: $0 [run1|run2]"
  exit 1
fi

docker compose -f "$COMPOSE_FILE" restart smf
sleep 3
echo "Bascule effectuee : $MODE"
echo "Verification recommandee : docker logs smf --tail 20"
