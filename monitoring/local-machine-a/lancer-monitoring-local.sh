#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
docker compose up -d
sleep 3
IP_LOCALE="$(hostname -I | awk '{print $1}')"
echo ""
docker compose ps
cat <<INNEREOF

Prometheus : http://${IP_LOCALE}:9090  (Status > Targets)
Grafana    : http://${IP_LOCALE}:3000  (admin / admin)
INNEREOF
