#!/usr/bin/env bash
# scripts/mesures/01-provisionner-abonnes.sh
#
# Clone l'abonné de test déjà validé (IMSI 001010000000001, PDU session
# fonctionnelle) N-1 fois dans MongoDB, avec IMSI incrémentée — pour
# provisionner rapidement les abonnés nécessaires à un scénario de trafic à
# plusieurs UE, sans risquer une config manuelle incohérente (SST/SD, DNN...).
#
# Usage : NB_ABONNES=20 bash scripts/mesures/01-provisionner-abonnes.sh
# (NB_ABONNES=10 par défaut ; l'abonné de base 001010000000001 n'est jamais
# recréé, ni écrasé s'il existe déjà)

set -euo pipefail

BASE_IMSI="001010000000001"
NB_ABONNES="${NB_ABONNES:-10}"

echo "==> Provisionnement de ${NB_ABONNES} abonnés (base : ${BASE_IMSI})..."

run_mongo() {
  # essaie mongosh (MongoDB >= 6), puis mongo (legacy) en secours
  if docker exec db mongosh open5gs --quiet --eval "$1" 2>/dev/null; then
    return 0
  fi
  docker exec db mongo open5gs --quiet --eval "$1"
}

EVAL_JS=$(cat <<EOF
const baseImsi = "${BASE_IMSI}";
const count = ${NB_ABONNES};
const base = db.subscribers.findOne({imsi: baseImsi});
if (!base) {
  print("ERREUR: abonné de base " + baseImsi + " introuvable — créez-le d'abord via la WebUI.");
  quit(1);
}
let added = 0, skipped = 0;
for (let i = 1; i < count; i++) {
  const newImsi = (BigInt(baseImsi) + BigInt(i)).toString().padStart(baseImsi.length, "0");
  if (db.subscribers.findOne({imsi: newImsi})) { skipped++; continue; }
  const clone = Object.assign({}, base);
  delete clone._id;
  clone.imsi = newImsi;
  db.subscribers.insertOne(clone);
  added++;
}
print("Abonnés ajoutés : " + added + " | déjà présents (ignorés) : " + skipped);
EOF
)

run_mongo "${EVAL_JS}"

echo "==> Vérification (nombre total d'abonnés en base) :"
run_mongo "print(db.subscribers.countDocuments({}))"
