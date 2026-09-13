#!/bin/bash
# scripts/infra/post-reboot-check.sh
# À exécuter sur la machine B après chaque redémarrage.
# Vérifie Tailscale, K3s, le pod UPF, Prometheus/Grafana, et relance les port-forwards.

set -e

echo "=== 1/5 - Tailscale ==="
if ! tailscale status &> /dev/null; then
  echo "Tailscale semble down, tentative de reconnexion..."
  sudo tailscale up
fi
tailscale status

echo ""
echo "=== 2/5 - K3s ==="
sudo systemctl status k3s --no-pager | grep "Active:"
echo "Nodes du cluster :"
kubectl get nodes -o wide

echo ""
echo "=== 3/5 - Pod UPF ==="
kubectl get pods -n nfv-5g
UPF_STATUS=$(kubectl get pods -n nfv-5g -l app=upf -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "ABSENT")

if [ "$UPF_STATUS" != "Running" ]; then
  echo "Pod UPF non Running (statut: $UPF_STATUS). Nettoyage et redeploiement..."
  sudo ip link delete ogstun 2>/dev/null || echo "  (aucune interface a nettoyer)"
  kubectl delete pod -n nfv-5g -l app=upf --ignore-not-found
  sleep 3
  bash "$(git rev-parse --show-toplevel)/scripts/infra/deploy-upf-k8s.sh"
else
  echo "Pod UPF deja Running, RAS."
fi

echo ""
echo "=== 4/5 - Prometheus/Grafana ==="
kubectl get pods -n monitoring

echo ""
echo "=== 5/5 - Lancement des port-forwards (Grafana:3000, Prometheus:9091) ==="
echo "Ctrl+C pour arreter les deux."

pkill -f "port-forward -n monitoring svc/prometheus-grafana" 2>/dev/null || true
pkill -f "port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus" 2>/dev/null || true
sleep 1

kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 --address 0.0.0.0 &
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9091:9090 --address 0.0.0.0 &

echo ""
echo "Grafana    : http://$(tailscale ip -4):3000"
echo "Prometheus : http://$(tailscale ip -4):9091"
echo ""
wait
