#!/usr/bin/env bash
# scripts/deploiement/02-deploy-open5gs.sh
#
# Déploie le cœur 5G Open5GS en conteneurs Docker via le projet tiers
# Borjis131/docker-open5gs (déploiement "basic"), qui expose les
# interfaces N2 (AMF, SCTP 38412) et N3 (UPF, UDP 2152) pour un gNB
# externe — ici UERANSIM, déployé à l'étape suivante.
#
# Ce déploiement "basic" inclut le 5GC + une base MongoDB, mais PAS la
# WebUI (absente du fichier compose de ce dépôt) : voir
# scripts/deploiement/03-deploy-webui.sh pour l'ajouter.
#
# Source de l'outil : https://github.com/Borjis131/docker-open5gs
# Voir docs/architecture/choix-deploiement-docker.md pour le détail du choix
# et des problèmes rencontrés (et leurs correctifs) lors du premier déploiement.
#
# Usage : bash scripts/deploiement/02-deploy-open5gs.sh
# (nécessite scripts/infra/01-install-docker.sh exécuté au préalable)

set -euo pipefail

REPO_URL="https://github.com/Borjis131/docker-open5gs.git"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
VENDOR_DIR="${PROJECT_ROOT}/vendor/docker-open5gs"
OPEN5GS_VERSION="v2.7.6"
# MongoDB 8.x plante au démarrage sur les noyaux Linux >= 6.19 (bug connu
# TCMalloc, cf. https://jira.mongodb.org/browse/SERVER-121912). On force donc
# la version 7.0, largement suffisante pour Open5GS, plutôt que la valeur
# par défaut du dépôt (8.0).
MONGODB_VERSION="7.0"

echo "==> [1/7] Détection de l'IP de la machine hôte..."
HOST_IP="${HOST_IP:-$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')}"
if [ -z "${HOST_IP}" ]; then
  echo "Impossible de détecter l'IP automatiquement."
  echo "Relancez avec : HOST_IP=x.x.x.x bash $0"
  exit 1
fi
echo "    IP détectée : ${HOST_IP}"

echo "==> [2/7] Récupération du dépôt outil docker-open5gs..."
mkdir -p "$(dirname "${VENDOR_DIR}")"
if [ ! -d "${VENDOR_DIR}" ]; then
  git clone "${REPO_URL}" "${VENDOR_DIR}"
else
  echo "    Déjà présent, mise à jour..."
  git -C "${VENDOR_DIR}" pull
fi
cd "${VENDOR_DIR}"

echo "==> [3/7] Configuration du fichier .env (versions + IP hôte)..."
set_env_var() {
  local key="$1" val="$2"
  if grep -q "^${key}=" .env 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    echo "${key}=${val}" >> .env
  fi
}
set_env_var OPEN5GS_VERSION "${OPEN5GS_VERSION}"
set_env_var MONGODB_VERSION "${MONGODB_VERSION}"
set_env_var DOCKER_HOST_IP "${HOST_IP}"
echo "    Valeurs appliquées :"
grep -E "^(OPEN5GS_VERSION|MONGODB_VERSION|DOCKER_HOST_IP)=" .env

echo "==> [4/7] Correctif : publication des ports UPF/AMF sur l'IP hôte précise"
echo "    (et non 0.0.0.0), pour laisser une adresse locale libre au gNB natif"
echo "    déployé par 03-deploy-webui.sh / 04-deploy-ueransim.sh."
sed -i "s|\"0\.0\.0\.0:2152:2152/udp\"|\"${HOST_IP}:2152:2152/udp\"|" compose-files/basic/docker-compose.yaml
sed -i "s|\"0\.0\.0\.0:38412:38412/sctp\"|\"${HOST_IP}:38412:38412/sctp\"|" compose-files/basic/docker-compose.yaml

echo "==> [5/7] Construction de l'image de base (peut prendre plusieurs minutes)..."
make base-open5gs

echo "==> [6/7] Démarrage du déploiement 'basic' (5GC + MongoDB)..."
docker compose -f compose-files/basic/docker-compose.yaml --env-file=.env up -d

echo "==> [7/7] Correctif : réattachement réseau de 'db' (bug d'endpoint observé"
echo "    au premier déploiement : IP vide sur le réseau 'open5gs' juste après"
echo "    la création du conteneur, ce qui empêche pcf/udr de le joindre)."
sleep 5
docker restart db >/dev/null
sleep 5

echo "==> État des conteneurs (pcf/udr peuvent encore redémarrer quelques"
echo "    secondes le temps de se reconnecter à MongoDB) :"
docker compose -f compose-files/basic/docker-compose.yaml --env-file=.env ps -a

cat <<EOF

Déploiement lancé.
  N2 (AMF)  : SCTP ${HOST_IP}:38412
  N3 (UPF)  : UDP  ${HOST_IP}:2152
  MongoDB   : ${HOST_IP}:27017

Vérifiez que tous les conteneurs affichent "Up" (relancez la commande ps
ci-dessus après quelques dizaines de secondes si pcf/udr sont encore en
"Restarting"). Ensuite :
  bash scripts/deploiement/03-deploy-webui.sh   # ajoute la WebUI (absente du basic)
EOF
