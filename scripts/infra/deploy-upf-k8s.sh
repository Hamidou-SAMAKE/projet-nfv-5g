#!/bin/bash
# scripts/infra/deploy-upf-k8s.sh
# Déploie (ou redéploie proprement) l'UPF en pod Kubernetes sur la machine B.
# Intègre les correctifs découverts en Phase 3 (cf. docs/architecture/difficultes-deploiement-k8s.md) :
#   - nettoyage de l'interface ogstun orpheline avant redéploiement
#   - logger sans fichier (stdout, cohérent avec kubectl logs)
#   - execution forcee via bash (l'entrypoint de l'image est incompatible avec /bin/sh)
#
# Usage : ./deploy-upf-k8s.sh
# Pré-requis : kubectl configuré (KUBECONFIG), fichiers config/k8s/upf-k8s.yaml et
#              config/k8s/deployment-upf.yaml presents dans le depot.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
NAMESPACE="nfv-5g"

echo "1/5 - Namespace..."
kubectl get namespace "$NAMESPACE" &> /dev/null || kubectl create namespace "$NAMESPACE"

echo "2/5 - Nettoyage de l'interface ogstun orpheline (si presente)..."
sudo ip link delete ogstun 2>/dev/null || echo "  (aucune interface a nettoyer)"

echo "3/5 - ConfigMap upf-config..."
kubectl delete configmap upf-config -n "$NAMESPACE" --ignore-not-found
kubectl create configmap upf-config \
  --from-file=upf.yaml="$REPO_ROOT/config/k8s/upf-k8s.yaml" \
  -n "$NAMESPACE"

echo "4/5 - Deploiement..."
kubectl apply -f "$REPO_ROOT/config/k8s/deployment-upf.yaml"

echo "5/5 - Attente de la disponibilite du pod (max 60s)..."
kubectl rollout status deployment/upf -n "$NAMESPACE" --timeout=60s

echo ""
echo "Etat final :"
kubectl get pods -n "$NAMESPACE" -l app=upf

echo ""
echo "Verification : le pod doit etre en 1/1 Running avec RESTARTS a 0."
echo "Si RESTARTS augmente, voir docs/architecture/difficultes-deploiement-k8s.md"
echo "pour le protocole de diagnostic (pod de debug avec 'command: [sleep, 3600]')."
