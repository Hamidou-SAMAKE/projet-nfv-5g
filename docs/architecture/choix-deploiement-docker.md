# Choix du déploiement conteneurisé — Open5GS

## Contexte

La note de cadrage (§6, Risques identifiés) recommandait déjà de privilégier un
déploiement conteneurisé pour limiter les conflits de dépendances liés à la
compilation native. Un premier essai natif a permis d'obtenir l'attache UE
(registration NAS via l'AMF) mais pas l'établissement de session PDU de bout en
bout (plan usager). Nous reprenons donc le déploiement à zéro, en conteneurs,
avec des scripts numérotés pour garantir la reproductibilité — c'est le livrable
porté par l'Étudiant A (« Guide de déploiement reproductible »).

## Outil retenu

[Borjis131/docker-open5gs](https://github.com/Borjis131/docker-open5gs)

Critères de choix :
- Images Docker prêtes à l'emploi (une par fonction réseau : AMF, SMF, UPF,
  AUSF, UDM, UDR, NRF, PCF, NSSF, BSF...), pas besoin de compiler tout Open5GS
  nous-mêmes.
- Déploiement `basic` conçu pour un gNB externe : expose directement les
  interfaces N2 et N3, ce qui correspond exactement à notre besoin (UERANSIM
  déployé séparément, cf. `config/ueransim/`).
- Fournit aussi des charts Helm (mêmes briques), réutilisables par l'Étudiant B
  pour la phase d'orchestration Kubernetes (phases 3-4 du planning).
- Dépôt actif, versions taguées alignées sur les releases Open5GS.

## Configuration retenue

- Version Open5GS : `v2.7.6`
- Déploiement : `compose-files/basic/docker-compose.yaml`
- Le dépôt outil est cloné dans `vendor/docker-open5gs/` par
  `scripts/deploiement/02-deploy-open5gs.sh` — il n'est pas versionné dans notre
  dépôt (voir `.gitignore`) pour ne pas dupliquer du code tiers ; le script
  garantit sa récupération reproductible.
- Variables de configuration documentées dans `config/open5gs/.env.example`.

## Ports exposés (déploiement basic)

| Interface | Protocole / Port | Fonction |
|---|---|---|
| N2 | SCTP 38412 | AMF — signalisation vers le RAN |
| N3 | UDP 2152 | UPF — plan usager |
| WebUI | TCP 9999 | Administration des abonnés (admin / 1423 par défaut) |
| MongoDB | TCP 27017 | Base des abonnés |

## Ordre d'exécution des scripts

1. `scripts/infra/00-cleanup-native.sh` — nettoie une éventuelle install native précédente
2. `scripts/infra/01-install-docker.sh` — Docker Engine + Compose + IP forwarding
3. `scripts/deploiement/02-deploy-open5gs.sh` — déploiement du 5GC + MongoDB conteneurisés
4. `scripts/deploiement/03-deploy-webui.sh` — ajout de la WebUI (absente du compose "basic")

## Problèmes rencontrés lors du premier déploiement (et correctifs appliqués)

1. **MongoDB 8.0 incompatible avec le noyau hôte (>= 6.19)** — le conteneur
   `db` plantait immédiatement (`MongoDB cannot start... SERVER-121912`).
   Corrigé en forçant `MONGODB_VERSION=7.0` dans le script de déploiement.
2. **La WebUI n'est pas incluse dans `compose-files/basic/docker-compose.yaml`**
   — seule l'image existe dans le dépôt (`images/webui/`). Un script dédié
   (`03-deploy-webui.sh`) la construit et la connecte manuellement au réseau
   `open5gs`, avec `DB_URI=mongodb://db.open5gs.org/open5gs`.
3. **Bug d'endpoint réseau Docker** — juste après `docker compose up -d`, un
   conteneur peut se retrouver avec une IP vide sur le réseau `open5gs`
   (visible via `docker inspect`), le rendant injoignable par les autres
   conteneurs (DNS `ENOTFOUND` ou `getaddrinfo` en échec). Un `docker compose
   down` puis `up -d` complet (qui respecte l'ordre des dépendances,
   contrairement à des `docker start` individuels) résout systématiquement le
   problème ; un simple `docker restart db` suffit aussi dans le cas isolé de
   `db`. Le script de déploiement applique ce correctif automatiquement.
4. **PLMN attendu par l'AMF : `001/01`, pas `999/70`** — la config `basic` de
   ce dépôt tiers utilise le PLMN générique 001/01 (TAC=1), différent de la
   valeur par défaut 999/70 des exemples fournis par UERANSIM. Le slice exige
   en plus **SST=1 ET SD=1** (pas seulement SST=1). Un abonné avec un IMSI
   commençant par `00101` doit être créé dans la WebUI en conséquence.
5. **Conflit de port GTP-U (2152) entre le gNB natif et le conteneur UPF** —
   les deux tournant sur la même machine, un gNB natif ne peut pas se lier
   sur le port 2152 de la même IP que celle publiée par Docker pour l'UPF.
   Deux correctifs combinés : (a) le port UPF est publié sur l'IP hôte
   précise plutôt que `0.0.0.0` (`02-deploy-open5gs.sh`), et (b) le gNB
   utilise une IP secondaire dédiée, ajoutée automatiquement sur la même
   interface réseau (`04-deploy-ueransim.sh`).

   *Récidive observée :* sur une machine avec plusieurs IP sur la même
   interface (ex. `.11` primaire + `.12` secondaire), la détection
   automatique (`ip route get`) a un jour renvoyé une IP différente de celle
   utilisée par Docker, recalculant une IP dédiée pour le gNB qui retombait
   exactement sur celle de l'UPF — recréant le même conflit. Corrigé en
   lisant directement `DOCKER_HOST_IP` depuis `vendor/docker-open5gs/.env`
   (source de vérité fiable) plutôt que de deviner via `ip route`.
   Par ailleurs, l'IP secondaire ajoutée pour le gNB (`ip addr add`) ne
   survit pas à un redémarrage de la VM — sans conséquence pratique, le
   script la rajoute automatiquement à chaque exécution.

## Jalon atteint

Session PDU de bout en bout validée (J14) : `ping -I uesimtun0 8.8.8.8` répond
avec 0% de perte à travers le tunnel UE → gNB → UPF → Internet.

## Étapes suivantes

5. Scénarios de trafic paramétrables pour la chaîne de mesure (J15-J21).
6. Rédaction du guide de déploiement reproductible (rapport final).
