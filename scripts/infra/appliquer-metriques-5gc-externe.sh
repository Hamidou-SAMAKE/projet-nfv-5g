#!/usr/bin/env bash
# scripts/infra/appliquer-metriques-5gc-externe.sh
#
# Raccorde le Prometheus du cluster K8s (machine B, kube-prometheus-stack)
# aux métriques AMF/SMF/UPF exposées par la machine A via Tailscale
# (cf. scripts/deploiement/06-exposer-metriques-tailscale.sh, côté A).
#
# Applique :
#   - config/k8s/service-5gc-docker-metrics.yaml   (Service sans sélecteur)
#   - config/k8s/endpoints-5gc-docker-metrics.yaml (Endpoints -> IP Tailscale A)
#   - config/k8s/servicemonitor-5gc-docker.yaml    (scrape par Prometheus Operator)
#
# Usage : ./appliquer-metriques-5gc-externe.sh <IP_TAILSCALE_A>
# Exemple : ./appliquer-metriques-5gc-externe.sh 100.64.10.5
# (IP donnée par l'Étudiant A en fin d'exécution de 06-exposer-metriques-tailscale.sh)
#
# Pré-requis : kubectl configuré (KUBECONFIG), kube-prometheus-stack déjà
# déployé (même prérequis que config/k8s/servicemonitor-upf.yaml).

set -euo pipefail

TAILSCALE_IP_A="${1:-}"
if [ -z "${TAILSCALE_IP_A}" ]; then
  echo "Usage: $0 <IP_TAILSCALE_A>"
  echo "Récupérez cette IP auprès de l'Étudiant A (sortie de 06-exposer-metriques-tailscale.sh)."
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
K8S_DIR="${REPO_ROOT}/config/k8s"
NAMESPACE="nfv-5g"

echo "1/3 - Namespace..."
kubectl get namespace "$NAMESPACE" &> /dev/null || kubectl create namespace "$NAMESPACE"

echo "2/3 - Service + Endpoints (IP cible : ${TAILSCALE_IP_A})..."
kubectl apply -f "${K8S_DIR}/service-5gc-docker-metrics.yaml"
sed "s/TAILSCALE_IP_MACHINE_A/${TAILSCALE_IP_A}/" "${K8S_DIR}/endpoints-5gc-docker-metrics.yaml" | kubectl apply -f -

echo "3/3 - ServiceMonitor..."
kubectl apply -f "${K8S_DIR}/servicemonitor-5gc-docker.yaml"

echo ""
echo "Vérification des endpoints enregistrés :"
kubectl get endpoints 5gc-docker-metrics -n "$NAMESPACE" -o wide

cat <<INNEREOF

Fait. Prometheus doit scraper amf/smf/upf sous 15-30s (voir dans son UI :
Status > Targets, rechercher "5gc-docker-metrics").

Si les targets restent "down" :
  - Vérifiez que le Tailscale du cluster/nœud K8s (B) voit bien A :
      tailscale ping ${TAILSCALE_IP_A}
  - Vérifiez que 06-exposer-metriques-tailscale.sh a bien retourné "OK"
    pour les 3 endpoints côté A avant de relancer ce script.
INNEREOF
