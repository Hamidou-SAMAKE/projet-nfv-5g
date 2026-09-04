# Chaîne de mesure — scénarios de trafic (état et remise en service)

Documentation de fonctionnement des 3 scripts de `scripts/mesures/` (Étudiant A),
et de la procédure pour tout remettre en état après un redémarrage de la VM.

---

## 1. Vue d'ensemble des scripts

| Script | Rôle | Machine |
|---|---|---|
| `01-provisionner-abonnes.sh` | Clone l'abonné validé (`001010000000001`) N-1 fois dans MongoDB, IMSI incrémentée | A |
| `02-scenario-trafic.sh` | Lance N UE (UERANSIM) par paliers, établit leurs sessions PDU | A |
| `03-generer-trafic-iperf3.sh` | Génère du trafic réel (iperf3, un port par UE) à travers chaque tunnel | A |
| `serveur-iperf3-machine-b.sh` | Démarre N instances iperf3 (une par port) | B (à transmettre) |

Chaîne complète : `01` (une fois, ou pour augmenter le nombre d'abonnés) → `02`
(à chaque scénario) → `03` (génère le trafic sur les tunnels actifs par `02`).

---

## 2. État des abonnés provisionnés

Les abonnés sont numérotés séquentiellement à partir de l'IMSI de base
`001010000000001` (clés K/OPc, DNN, slice identiques — voir
`config/ueransim/ue.yaml`). Un ancien abonné de test (`999700000000001`,
PLMN 999/70, antérieur à la correction du bug n°4) traîne aussi en base,
sans conséquence.

**Vérifier le nombre actuel d'abonnés à tout moment :**
```bash
docker exec db mongosh open5gs --quiet --eval "db.subscribers.countDocuments({})"
```

**Lister les IMSI de la plage `00101...` :**
```bash
docker exec db mongosh open5gs --quiet --eval "db.subscribers.find({imsi: /^00101/}, {imsi:1, _id:0}).forEach(printjson)"
```

**Provisionner plus d'abonnés si besoin** (le script ignore ceux déjà présents,
sûr à relancer) :
```bash
NB_ABONNES=20 bash scripts/mesures/01-provisionner-abonnes.sh
```

---

## 3. Ce qui survit à un redémarrage de la VM (et ce qui ne survit pas)

| Élément | Survit à un reboot ? | Remarque |
|---|---|---|
| Abonnés dans MongoDB | ✅ Oui | Stockés dans le volume Docker `open5gs_db_data`, persistant tant qu'on ne fait pas `docker compose down -v` |
| Conteneurs 5GC + webui | ❌ Non (sauf `pcf`/`udr`) | Redémarrage manuel requis — voir `docs/procedure-redemarrage-vm.md` |
| gNB / UE (UERANSIM) | ❌ Non | Processus natifs, toujours à relancer après un reboot |
| IP secondaire dédiée au gNB | ❌ Non | Recréée automatiquement par `04-deploy-ueransim.sh` à chaque lancement |
| Résultats de mesure (`modele/donnees/raw/`) | ✅ Oui | Fichiers sur disque, suivis (ou non) par Git selon `.gitignore` |

**Point clé : les abonnés provisionnés ne sont jamais perdus au redémarrage** —
inutile de relancer `01-provisionner-abonnes.sh` après un simple reboot, sauf
si vous voulez en ajouter de nouveaux.

---

## 4. Procédure complète de remise en service après un redémarrage VM

```bash
cd ~/projet-nfv-5g

# 1) Base 5GC + WebUI (voir docs/procedure-redemarrage-vm.md pour le détail)
cd vendor/docker-open5gs
docker compose -f compose-files/basic/docker-compose.yaml --env-file=.env up -d
sleep 10
docker restart db
sleep 5
docker start webui
sleep 5
docker compose -f compose-files/basic/docker-compose.yaml --env-file=.env ps -a
cd ~/projet-nfv-5g

# 2) Vérifier que les abonnés sont bien toujours là (doit être > 1)
docker exec db mongosh open5gs --quiet --eval "db.subscribers.countDocuments({})"

# 3) Relancer le scénario de trafic souhaité (gNB redémarré automatiquement si besoin)
NB_UE=5 PALIER_TAILLE=5 PALIER_DELAI=10 bash scripts/mesures/02-scenario-trafic.sh

# 4) Générer le trafic (si serveur iperf3 disponible, local ou machine B)
TARGET_IP=192.168.1.12 bash scripts/mesures/03-generer-trafic-iperf3.sh   # test local
# ou, contre la machine B :
TARGET_IP=<IP Tailscale de B> bash scripts/mesures/03-generer-trafic-iperf3.sh
```

---

## 5. Nettoyer entre deux scénarios (sans redémarrer la VM)

Si vous relancez `02-scenario-trafic.sh` plusieurs fois dans la même session
sans couper les UE précédents, les anciens tunnels restent actifs et peuvent
entrer en conflit d'IMSI avec le nouveau scénario. Avant de relancer :

```bash
sudo pkill -f nr-ue    # arrête tous les UE actifs (garde le gNB)
sleep 2
ip -o addr show | grep uesimtun   # doit être vide
```

Puis relancez `02-scenario-trafic.sh` normalement.

**Après recréation du conteneur `upf` (pour quelque raison que ce soit),
toujours redémarrer `smf`** — sinon les sessions PDU échouent silencieusement
avec `NETWORK_FAILURE` (association PFCP cassée) :
```bash
docker restart smf
sleep 5
```

---

## 6. Aide-mémoire

| Besoin | Commande |
|---|---|
| Nombre d'abonnés | `docker exec db mongosh open5gs --quiet --eval "db.subscribers.countDocuments({})"` |
| Ajouter des abonnés | `NB_ABONNES=<N> bash scripts/mesures/01-provisionner-abonnes.sh` |
| Lancer un scénario | `NB_UE=<N> PALIER_TAILLE=<N> PALIER_DELAI=<N> bash scripts/mesures/02-scenario-trafic.sh` |
| Tunnels actifs | `ip -o addr show \| grep uesimtun` |
| Arrêter tous les UE | `sudo pkill -f nr-ue` |
| Générer du trafic | `TARGET_IP=<cible> bash scripts/mesures/03-generer-trafic-iperf3.sh` |
| Résultats de mesure | `modele/donnees/raw/run-<horodatage>/` |
