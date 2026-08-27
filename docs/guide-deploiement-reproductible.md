# Guide de déploiement reproductible — Testbed 5G (Étudiant A)

**Projet :** Déploiement et dimensionnement NFV d'un cœur de réseau 5G
**Auteur :** Hamidou SAMAKE — Étudiant A (Réseau & Orchestration)
**Périmètre :** Déploiement du 5GC (Open5GS), du RAN/UE simulés (UERANSIM), validation de la session PDU de bout en bout — jalon J14
**Machine cible :** Machine A (VM Ubuntu 24.04, 8 Go RAM prévus au cadrage, 100 Go disque)

---

## 1. Vue d'ensemble

### 1.1 Objectif

Déployer un cœur de réseau 5G Standalone (5GC) fonctionnel, de façon **entièrement scriptée et reproductible**, capable d'établir une session PDU de bout en bout avec un UE simulé — du terminal jusqu'à Internet.

### 1.2 Choix d'architecture : conteneurisation Docker

La note de cadrage identifiait dès le départ le risque de conflits de dépendances lors d'une installation native (compilation depuis les sources). Après un premier essai natif partiellement fonctionnel (attache UE réussie, mais session PDU en échec faute de configuration réseau/NAT), le déploiement a été **entièrement repris en conteneurs Docker**, conformément à la mesure d'atténuation prévue dans la note de cadrage (§8 : *"Conflits de dépendances / échec d'installation → Déploiements conteneurisés privilégiés"*).

Outil retenu pour le 5GC : **[Borjis131/docker-open5gs](https://github.com/Borjis131/docker-open5gs)** — images Docker prêtes à l'emploi (une par fonction réseau), déploiement `basic` exposant les interfaces N2/N3 pour un gNB externe, et charts Helm réutilisables plus tard pour la phase d'orchestration Kubernetes (Étudiant B).

UERANSIM (gNB + UE), qui n'est pas fourni en conteneur par cet outil, est compilé nativement depuis les sources sur la même machine.

### 1.3 Architecture obtenue

```
┌─────────────────────────────────────────────────────────────────┐
│                     Machine A (VM Ubuntu, 100 Go)                │
│                                                                    │
│   ┌──────────────────────────────────────────────────────────┐   │
│   │         Docker Engine — réseau "open5gs" (bridge)          │   │
│   │                                                              │   │
│   │   [nrf] [ausf] [udm] [udr] [nssf] [bsf] [pcf]              │   │
│   │   [amf] ───────── SCTP 38412 (N2) ── publié sur IP hôte    │   │
│   │   [smf]                                                     │   │
│   │   [upf] ───────── UDP  2152  (N3) ── publié sur IP hôte    │   │
│   │   [db]  (MongoDB 7.0) ── [webui] (port 9999)               │   │
│   └──────────────────────────────────────────────────────────┘   │
│                                                                    │
│   Processus natifs (hors Docker, IP secondaire dédiée) :          │
│      nr-gnb  (gNB simulé) ── nr-ue (UE simulé, imsi-00101...)     │
│      → tunnel uesimtun0 → Internet                                │
└─────────────────────────────────────────────────────────────────┘
```

Point clé : le gNB (UERANSIM) tourne **nativement** sur la même machine que le 5GC conteneurisé. Il utilise une **IP secondaire dédiée** (ex. `192.168.1.13`) sur l'interface réseau existante, distincte de l'IP du 5GC (ex. `192.168.1.12`), pour éviter tout conflit de port avec le conteneur UPF (voir §3 — bug n°5).

---

## 2. Prérequis

| Élément | Valeur retenue | Remarque |
|---|---|---|
| Système | Ubuntu 24.04 LTS (VM VMware) | Réseau en mode Bridged |
| Disque | 100 Go | 30 Go initiaux insuffisants (Docker + builds ≈ 70 Go utiles) |
| RAM | 8 Go (cadrage) | Suffisant pour 5GC + gNB/UE en simulation légère |
| SSH | OpenSSH server installé et actif | Nécessaire pour `scp` depuis l'hôte Windows/Mac |
| Docker | Docker Engine + Compose v2 + Buildx (dépôt officiel Docker) | Le paquet `docker.io` d'Ubuntu ne fournit pas le plugin Compose |

---

## 3. Étapes de déploiement (avec commandes)

Tous les scripts sont dans le dépôt Git, sous `scripts/infra/` et `scripts/deploiement/`, numérotés dans l'ordre d'exécution.

### Étape 0 — Nettoyage d'une éventuelle installation native précédente

```bash
cd ~/projet-nfv-5g
chmod +x scripts/infra/00-cleanup-native.sh
bash scripts/infra/00-cleanup-native.sh
```

Arrête/désactive les services `open5gs-*.service` (systemd), purge le paquet apt `open5gs*` s'il existe, arrête MongoDB natif (libère le port 27017), supprime l'interface `ogstun` et une éventuelle règle NAT associée. Repère (sans les supprimer automatiquement) les sources compilées à la main (`~/UERANSIM`, `~/open5gs`...).

### Étape 1 — Installation de Docker

```bash
bash scripts/infra/01-install-docker.sh
```

Installe Docker Engine + Compose v2 + Buildx depuis le dépôt officiel Docker (pas le paquet Ubuntu générique), ajoute l'utilisateur au groupe `docker`, active l'IP forwarding (`net.ipv4.ip_forward=1`, nécessaire au plan usager UPF).

**Important :** se déconnecter/reconnecter (ou `newgrp docker`) après cette étape pour utiliser Docker sans `sudo`.

### Étape 2 — Déploiement du 5GC (Open5GS conteneurisé)

```bash
bash scripts/deploiement/02-deploy-open5gs.sh
```

Ce script :
1. Détecte l'IP de la machine hôte.
2. Clone [Borjis131/docker-open5gs](https://github.com/Borjis131/docker-open5gs) dans `vendor/docker-open5gs/` (non versionné, cf. `.gitignore`).
3. Configure `.env` : `OPEN5GS_VERSION=v2.7.6`, `MONGODB_VERSION=7.0` (voir bug n°1), `DOCKER_HOST_IP` détectée.
4. **Patch** le fichier compose pour publier les ports UPF (2152/udp) et AMF (38412/sctp) sur l'IP hôte précise plutôt que `0.0.0.0` (voir bug n°5).
5. Construit l'image de base (`make base-open5gs`) puis lance le déploiement `basic` (`docker compose up -d`).
6. Redémarre automatiquement le conteneur `db` (voir bug n°3).

Vérification :
```bash
cd vendor/docker-open5gs
docker compose -f compose-files/basic/docker-compose.yaml --env-file=.env ps -a
```
→ les 11 conteneurs (amf, ausf, bsf, db, nrf, nssf, pcf, smf, udm, udr, upf) doivent afficher `Up`.

### Étape 3 — Déploiement de la WebUI

```bash
bash scripts/deploiement/03-deploy-webui.sh
```

L'image WebUI existe dans le dépôt tiers (`images/webui/`) mais n'est **pas incluse** dans le compose `basic` (voir bug n°2). Ce script la construit et la démarre séparément, connectée au réseau Docker `open5gs`, avec `DB_URI=mongodb://db.open5gs.org/open5gs`.

Accès : `http://<IP_VM>:9999` — identifiants par défaut `admin` / `1423`.

### Étape 4 — Provisionnement d'un abonné de test

Dans la WebUI, menu **Subscriber → +** :

| Champ | Valeur |
|---|---|
| IMSI | `001010000000001` |
| K | `465B5CE8B199B49FAA5F0A2EE238A6BC` |
| OPc | `E8ED289DEBA952E4283B54E88E6183CA` |
| Slice | SST = `1`, SD = `000001` |
| Session | DNN/APN = `internet`, type `IPv4` |

**Le PLMN (001/01) et le SD (1, pas seulement SST) sont imposés par la configuration de l'AMF de ce dépôt tiers** (`vendor/docker-open5gs/configs/basic/amf.yaml`) — voir bug n°4. Ce n'est pas la valeur par défaut 999/70 des exemples UERANSIM.

### Étape 5 — Déploiement d'UERANSIM (gNB + UE)

```bash
bash scripts/deploiement/04-deploy-ueransim.sh
```

Ce script :
1. Détecte l'IP du 5GC et calcule une **IP secondaire dédiée au gNB** (ex. `HOST_IP` + 1 sur le dernier octet), ajoutée sur l'interface réseau existante (`ip addr add`).
2. Installe les dépendances de build (`make`, `gcc`, `g++`, `libsctp-dev`, `lksctp-tools`, `cmake`).
3. Clone et compile UERANSIM v3.2.7 dans `vendor/UERANSIM/`.
4. Génère les fichiers de config réels à partir des templates versionnés (`config/ueransim/gnb.yaml`, `ue.yaml`), en substituant les IP détectées aux placeholders `__AMF_IP__` / `__GNB_IP__`.
5. Démarre `nr-gnb` puis `nr-ue` en arrière-plan (logs dans `vendor/logs-ueransim/`).

### Étape 6 — Validation de la session PDU (jalon J14)

```bash
tail -n 20 vendor/logs-ueransim/ue.log
ip addr show uesimtun0
sudo ping -I uesimtun0 8.8.8.8 -c 4
```

Résultat attendu (obtenu) :
```
Connection setup for PDU session[1] is successful, TUN interface[uesimtun0, 10.45.0.3] is up.
...
4 packets transmitted, 4 received, 0% packet loss
```

**✅ Jalon J14 validé** : session PDU de bout en bout fonctionnelle, connectivité Internet réelle à travers le tunnel UE → gNB → UPF.

---

## 4. Problèmes rencontrés et corrections apportées

Ces cinq problèmes ont été rencontrés dans l'ordre ci-dessous lors du premier déploiement ; les correctifs sont désormais intégrés dans les scripts (plus besoin de les rejouer manuellement).

### Bug n°1 — MongoDB 8.0 incompatible avec le noyau hôte

**Symptôme :** le conteneur `db` plantait immédiatement au démarrage (`MongoDB cannot start`).
**Cause :** bug connu de MongoDB (réf. `SERVER-121912`) — les versions 8.x sont incompatibles avec les noyaux Linux ≥ 6.19 (bug TCMalloc).
**Correctif :** `MONGODB_VERSION=7.0` forcé dans `02-deploy-open5gs.sh`, à la place de la valeur par défaut du dépôt tiers (8.0).

### Bug n°2 — WebUI absente du déploiement "basic"

**Symptôme :** aucune interface d'administration disponible après le déploiement du 5GC.
**Cause :** l'image `webui` existe dans le dépôt (`images/webui/`) mais aucun service correspondant n'est déclaré dans `compose-files/basic/docker-compose.yaml`.
**Correctif :** script dédié `03-deploy-webui.sh` qui construit l'image et démarre le conteneur manuellement, connecté au réseau `open5gs`.

### Bug n°3 — Endpoint réseau Docker incohérent après `up -d`

**Symptôme :** juste après le démarrage, certains conteneurs (`db`, puis `upf`) se retrouvaient avec une IP vide sur le réseau `open5gs` (visible via `docker inspect`), rendant leur alias DNS (ex. `db.open5gs.org`) injoignable par les autres conteneurs.
**Cause :** condition de course lors de l'attribution de l'adresse réseau au moment de la création du conteneur.
**Correctif :** un `docker compose down` suivi d'un `up -d` complet (qui respecte l'ordre des dépendances `depends_on`, contrairement à des `docker start` individuels) résout systématiquement le problème. Le script applique un redémarrage ciblé automatique de `db` après le déploiement.

### Bug n°4 — PLMN et slice non conformes à la config réelle de l'AMF

**Symptôme :** `NG Setup procedure is failed. Cause: misc/unknown-PLMN-or-SNPN`.
**Cause :** les configurations UERANSIM utilisaient par défaut le PLMN `999/70` (valeur des exemples officiels UERANSIM), alors que l'AMF de ce dépôt tiers est configuré pour le PLMN `001/01` (TAC=1), avec un slice exigeant **SST=1 ET SD=1** (pas seulement SST=1).
**Correctif :** configs `gnb.yaml`/`ue.yaml` et abonné WebUI alignés sur `001/01`, IMSI `001010000000001`, slice SST=1/SD=1.

### Bug n°5 — Conflit de port GTP-U (2152) entre le gNB natif et le conteneur UPF

**Symptôme :** `GTP/UDP task could not be created. Socket bind failed: Address already in use`, puis un crash du gNB (erreur de segmentation) lors du test de trafic réel.
**Cause :** le gNB (natif) et l'UPF (conteneurisé) tournent sur la même machine et utilisent tous deux le port standard 2152. Le conteneur UPF publiait son port sur `0.0.0.0` (toutes les interfaces), ce qui occupait aussi toute IP secondaire ajoutée pour le gNB.
**Correctif combiné :**
1. Publication du port UPF (et AMF, par cohérence) sur l'**IP hôte précise** plutôt que `0.0.0.0` (patch appliqué dans `02-deploy-open5gs.sh`).
2. Attribution d'une **IP secondaire dédiée** au gNB sur la même interface réseau, distincte de celle du 5GC (`04-deploy-ueransim.sh`).

*Note méthodologique :* une adresse loopback (`127.0.0.x`) a été testée pour le gNB avant l'IP secondaire — elle ne fonctionne pas, le noyau Linux refusant qu'une adresse loopback serve de source pour joindre une adresse non-loopback (`Network is unreachable`).

---

## 5. Structure du dépôt (partie Étudiant A)

```
scripts/
  infra/
    00-cleanup-native.sh       nettoyage installation native précédente
    01-install-docker.sh       Docker Engine + Compose + IP forwarding
  deploiement/
    02-deploy-open5gs.sh       déploiement 5GC conteneurisé
    03-deploy-webui.sh         WebUI (absente du compose basic)
    04-deploy-ueransim.sh      build + démarrage gNB/UE
config/
  open5gs/.env.example         variables du déploiement Docker (documentées)
  ueransim/gnb.yaml             template config gNB (placeholders IP)
  ueransim/ue.yaml              template config UE (placeholders IP)
docs/
  architecture/
    choix-deploiement-docker.md   justification + bugs détaillés
  guide-deploiement-reproductible.md   ce document
vendor/                        (non versionné) dépôts tiers clonés, logs UERANSIM
```

---

## 6. Aide-mémoire — commandes utiles

| Action | Commande |
|---|---|
| État des conteneurs 5GC | `docker compose -f vendor/docker-open5gs/compose-files/basic/docker-compose.yaml --env-file=vendor/docker-open5gs/.env ps -a` |
| Logs d'un conteneur | `docker logs <nom> --tail 50` |
| Relancer tout le 5GC proprement | `docker compose -f .../docker-compose.yaml --env-file=.env down && ... up -d` |
| Relancer gNB/UE | `bash scripts/deploiement/04-deploy-ueransim.sh` |
| Logs gNB / UE | `tail -f vendor/logs-ueransim/gnb.log` / `ue.log` |
| Arrêter gNB/UE | `sudo pkill -f nr-gnb; sudo pkill -f nr-ue` |
| Tester la session PDU | `sudo ping -I uesimtun0 8.8.8.8 -c 4` |

---

## 7. Prochaines étapes

- Scénarios de trafic paramétrables pour la chaîne de mesure (J15-J21, `scripts/mesures/`).
- Support des campagnes de charge pour le dimensionnement (J22-J27, en appui de l'Étudiant B).
- Intégration finale dans le rapport et la soutenance (J28-J30).
