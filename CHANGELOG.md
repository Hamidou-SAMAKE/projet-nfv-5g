# Journal de bord

Chaque entrée trace une contribution significative. Préfixe `[A]`, `[B]` ou `[A+B]`
selon l'auteur — voir convention de commits dans le README.

## J1
- [A+B] Initialisation du dépôt, structure de dossiers, README, .gitignore
- [A+B] Cadrage matériel : machine A (8 Go) / machine B (32 Go), choix Tailscale pour la mise en réseau

## J2
- [A] Revue bibliographique : Open5GS, free5GC, UERANSIM
- [B] Revue bibliographique : ETSI GS NFV-002, NFV-MAN 001, OSM
- [A+B] Choix de la pile : Open5GS + UERANSIM
- [A+B] Rédaction et validation de la note de cadrage

## J8
- [A] docs: reprise du déploiement en conteneurs Docker (cf. note de cadrage §6) après un premier essai natif — attache UE fonctionnelle mais session PDU en échec, non poursuivi
- [A] feat: script de nettoyage de l'installation native précédente — `scripts/infra/00-cleanup-native.sh`
- [A] feat: script de prérequis (Docker Engine + Compose + IP forwarding) — `scripts/infra/01-install-docker.sh`
- [A] feat: script de déploiement Open5GS conteneurisé (Borjis131/docker-open5gs, déploiement basic) — `scripts/deploiement/02-deploy-open5gs.sh`
- [A] docs: note d'architecture sur le choix de l'outil de conteneurisation — `docs/architecture/choix-deploiement-docker.md`
- [A] fix: MongoDB 8.0 incompatible avec le noyau hôte (>= 6.19, bug TCMalloc SERVER-121912) — pin à `MONGODB_VERSION=7.0`
- [A] feat: script de déploiement de la WebUI, absente du compose "basic" — `scripts/deploiement/03-deploy-webui.sh`
- [A] fix: contournement d'un bug d'endpoint réseau Docker (IP vide sur `db` après `up -d`) par un redémarrage automatique dans le script de déploiement
- [A] chore: disque de la VM porté de 30 à 100 Go (partition + fs étendus, disque déjà à 98% d'occupation)
- [A] feat: abonné de test provisionné via la WebUI (IMSI 999700000000001, valeurs par défaut UERANSIM)
- [A] feat: configs UERANSIM versionnées, alignées sur l'abonné de test — `config/ueransim/gnb.yaml`, `config/ueransim/ue.yaml`
- [A] feat: script de build + démarrage UERANSIM (gNB+UE, UERANSIM v3.2.7), avec IP dédiée automatique pour éviter le conflit de port GTP avec l'UPF conteneurisé — `scripts/deploiement/04-deploy-ueransim.sh`
- [A] fix: PLMN réel de l'AMF (001/01, pas 999/70) + slice SST=1/SD=1 requis — configs UERANSIM et abonné WebUI corrigés (IMSI 001010000000001)
- [A] fix: conflit de port GTP-U (2152) entre gNB natif et conteneur UPF — port UPF publié sur l'IP hôte précise (pas 0.0.0.0) + IP secondaire dédiée au gNB
- [A] **jalon J14 atteint** : session PDU de bout en bout validée (`ping -I uesimtun0 8.8.8.8`, 0% de perte)
