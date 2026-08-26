#!/usr/bin/env bash
# scripts/deploiement/03-deploy-webui.sh
#
# Construit et démarre la WebUI Open5GS, absente du déploiement "basic" de
# Borjis131/docker-open5gs (seule l'image existe dans le dépôt, sous
# images/webui/, sans service correspondant dans le docker-compose.yaml).
# On la connecte manuellement au réseau Docker "open5gs" créé par
# scripts/deploiement/02-deploy-open5gs.sh, pointée vers la base MongoDB
# via son alias réseau db.open5gs.org.
#
# Usage : bash scripts/deploiement/03-deploy-webui.sh
# (nécessite scripts/deploiement/02-deploy-open5gs.sh exécuté au préalable,
# avec le réseau Docker "open5gs" et le conteneur "db" déjà actifs)

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/docker-open5gs"
OPEN5GS_VERSION="v2.7.6"
NODE_VERSION="20"

if ! docker network inspect open5gs >/dev/null 2>&1; then
  echo "Le réseau Docker 'open5gs' n'existe pas."
  echo "Lancez d'abord scripts/deploiement/02-deploy-open5gs.sh."
  exit 1
fi

cd "${VENDOR_DIR}"

echo "==> [1/3] Construction de l'image webui..."
docker build \
  --build-arg OPEN5GS_VERSION="${OPEN5GS_VERSION}" \
  --build-arg NODE_VERSION="${NODE_VERSION}" \
  -t webui:"${OPEN5GS_VERSION}" \
  images/webui

echo "==> [2/3] Nettoyage d'un ancien conteneur webui si présent..."
docker rm -f webui >/dev/null 2>&1 || true

echo "==> [3/3] Démarrage de la WebUI (réseau 'open5gs', DB via db.open5gs.org)..."
docker run -d \
  --name webui \
  --network open5gs \
  -e DB_URI="mongodb://db.open5gs.org/open5gs" \
  -p 9999:9999 \
  webui:"${OPEN5GS_VERSION}"

HOST_IP="$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"

cat <<EOF

WebUI démarrée : http://${HOST_IP}:9999
Identifiants par défaut : admin / 1423

Si la page ne répond pas immédiatement (erreur de connexion), patientez
~15-20s le temps que le serveur de développement Next.js compile, puis
vérifiez avec :
  docker logs webui --tail 20
Si les logs montrent une erreur "getaddrinfo ENOTFOUND db.open5gs.org",
c'est le même bug d'endpoint réseau que pour 'db' : relancez simplement
  docker restart db && sleep 5 && docker restart webui

Prochaine étape : créer un abonné de test dans la WebUI, puis déployer
UERANSIM (scripts/deploiement/04-deploy-ueransim.sh).
EOF
