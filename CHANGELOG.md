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

## J15 (reprise)
- [A] fix: récidive du conflit de port GTP (détection d'IP automatique incohérente sur machine multi-IP) — `04-deploy-ueransim.sh` lit désormais `DOCKER_HOST_IP` depuis `vendor/docker-open5gs/.env` plutôt que de deviner via `ip route`
- [A] chore: re-validation de la session PDU après reprise de session (0% de perte confirmé)

## J15 (révision cadrage)
- [A+B] docs: révision de la note de cadrage — protocole Run 1/Run 2 précisé (baseline conservé sur machine A suite au jalon J14, Run 2 = migration UPF seule vers machine B via K8s)

## J15 (vérification post-K3s)
- [A] chore: testbed 5G re-validé après installation de K3s sur machine A par B (worker node) — 0% de perte, aucune interférence Docker/K3s observée

## J20 (scénarios de trafic)
- [A] feat: scripts de scénarios de trafic paramétrables (provisionnement en masse, montée en charge par paliers, génération iperf3) — `scripts/mesures/01-provisionner-abonnes.sh`, `02-scenario-trafic.sh`, `03-generer-trafic-iperf3.sh`
- [A] fix: après recréation du conteneur upf seul (sans smf), l'association PFCP SMF↔UPF reste cassée ("No UPFs are PFCP associated") — toujours redémarrer smf après upf
- [A] chore: scénario 5 UE validé (attache + 5 sessions PDU établies simultanément)

## J20 (test iperf3 local)
- [A] fix: iperf3 ne traite qu'un client à la fois par port — un port dédié par UE désormais utilisé (`03-generer-trafic-iperf3.sh`, `serveur-iperf3-machine-b.sh`), indispensable pour du trafic concurrent multi-UE
- [A] chore: chaîne de mesure trafic validée en local (5 UE, 5 flux iperf3 concurrents réussis) ; test réel via Tailscale vers machine B en attente du serveur côté B
