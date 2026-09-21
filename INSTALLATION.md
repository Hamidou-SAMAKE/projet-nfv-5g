# Guide d'installation complet — NFV-5G

Ce guide permet de partir d'un clone du dépôt GitHub et d'arriver à un testbed 5G
fonctionnel, avec chaîne de mesure et supervision, sur deux machines. Il assemble
et ordonne les scripts déjà présents dans le dépôt — il ne remplace pas la
documentation détaillée référencée à chaque étape (bugs rencontrés, diagnostics,
choix d'architecture), qui reste la référence en cas de problème.

**Pour qui ?** Toute personne qui récupère ce dépôt et veut reproduire le testbed
de zéro (encadrant, relecteur, futur binôme reprenant le projet).

**Prérequis de lecture :** aucun. Chaque commande est donnée telle quelle.

---

## 0. Vue d'ensemble

### 0.1 Ce que vous allez construire

Un cœur de réseau 5G Standalone (5GC, Open5GS) avec RAN/UE simulés (UERANSIM),
déployé sur une machine, relié par VPN mesh (Tailscale) à une seconde machine qui
héberge un cluster Kubernetes (monitoring Prometheus/Grafana + démonstration de
scaling orchestré).

### 0.2 Les deux machines

| | Machine A | Machine B |
|---|---|---|
| RAM conseillée | 8 Go | 32 Go |
| OS | Ubuntu 24.04 LTS | Ubuntu 24.04 LTS |
| Rôle | 5GC conteneurisé (Docker) + UERANSIM natif — **héberge toutes les mesures de dimensionnement** | Control-plane K8s + Prometheus/Grafana + démonstration de scaling K8s de l'UPF |
| Composants installés | Docker, UERANSIM (compilé) | K3s, Helm, kube-prometheus-stack |

Ces deux rôles sont **indépendants dans le protocole de mesure** : toutes les
campagnes de charge et la modélisation par files d'attente reposent uniquement
sur la machine A (choix acté après l'abandon d'une architecture distribuée en
Phase 3 — voir `docs/architecture/decision-abandon-run2.md`). Le cluster K8s de
la machine B sert à deux choses distinctes : la supervision à distance des
métriques de A, et une démonstration de mise à l'échelle horizontale de l'UPF,
réalisée localement sur B.

### 0.3 Schéma d'ensemble

```
┌────────────────────────────────┐        Tailscale (VPN mesh)        ┌──────────────────────────────────┐
│           MACHINE A             │ <---------------------------------> │            MACHINE B              │
│                                  │                                     │                                    │
│  Docker : AMF/SMF/UPF/NRF/...   │   métriques AMF/SMF/UPF (9091-9093) │  K3s (control-plane, schedulable) │
│  UERANSIM (natif) : gNB + UE    │ ------------------------------------>│   - kube-prometheus-stack          │
│  Tunnels uesimtunN              │                                     │   - pod UPF (démo scaling K8s)     │
│                                  │   agent K3s (optionnel, cf. §4.3)  │                                    │
│  scripts/mesures/*.sh            │ <-----------------------------------│                                    │
└────────────────────────────────┘                                     └──────────────────────────────────┘
```

---

## 1. Prérequis

- Deux machines (VM ou physiques) sous **Ubuntu 24.04 LTS**, avec accès `sudo` et sortie Internet.
- Machine A : au moins **100 Go de disque** (Docker + builds ≈ 70 Go utiles, 30 Go s'est révélé insuffisant en pratique).
- Un compte [Tailscale](https://tailscale.com) — **le même compte des deux côtés**, sans quoi les deux machines rejoignent deux tailnets étanches et ne se voient pas.
- Accès SSH (`openssh-server`) sur les deux machines si vous travaillez depuis un poste tiers (Windows/Mac) :
  ```bash
  sudo apt update && sudo apt install -y openssh-server
  ```
- Git installé (`sudo apt install -y git`).

---

## 2. Cloner le dépôt (sur les deux machines)

```bash
git clone https://github.com/Hamidou-SAMAKE/projet-nfv-5g.git
cd projet-nfv-5g
```

---

## 3. Machine A — Testbed 5G (Docker + UERANSIM)

Cette section condense les étapes ; le détail de chaque script, les vérifications
attendues et **5 bugs déjà rencontrés et corrigés** (MongoDB, WebUI absente,
conflit de port GTP...) sont documentés en profondeur dans
**[`docs/guide-deploiement-reproductible.md`](docs/guide-deploiement-reproductible.md)** — s'y référer à la moindre erreur inattendue avant de chercher ailleurs.

```bash
# 0. Nettoyage d'une éventuelle installation Open5GS native précédente
bash scripts/infra/00-cleanup-native.sh

# 1. Docker Engine + Compose v2 + Buildx + IP forwarding
bash scripts/infra/01-install-docker.sh
# Important : se déconnecter/reconnecter (ou `newgrp docker`) avant de continuer

# 2. Déploiement du 5GC conteneurisé (Open5GS, 11 conteneurs)
bash scripts/deploiement/02-deploy-open5gs.sh

# Vérification : les 11 conteneurs doivent être "Up"
docker compose -f vendor/docker-open5gs/compose-files/basic/docker-compose.yaml --env-file=vendor/docker-open5gs/.env ps -a

# 3. WebUI d'administration (absente du déploiement "basic" par défaut)
bash scripts/deploiement/03-deploy-webui.sh
```

Ouvrir `http://<IP_machine_A>:9999` (identifiants `admin`/`1423`), menu
**Subscriber → +**, et créer l'abonné de test avec **exactement** ces valeurs
(imposées par la config de l'AMF de ce dépôt tiers, pas les valeurs par défaut
UERANSIM) :

| Champ | Valeur |
|---|---|
| IMSI | `001010000000001` |
| K | `465B5CE8B199B49FAA5F0A2EE238A6BC` |
| OPc | `E8ED289DEBA952E4283B54E88E6183CA` |
| Slice | SST = `1`, SD = `000001` |
| Session | DNN/APN = `internet`, type `IPv4` |

```bash
# 4. UERANSIM (gNB + UE natifs, compilés depuis les sources)
bash scripts/deploiement/04-deploy-ueransim.sh
```

**Vérification finale (jalon du testbed) :**
```bash
ip addr show uesimtun0
sudo ping -I uesimtun0 8.8.8.8 -c 4
```
→ attendu : `TUN interface[uesimtun0, ...] is up` et **0% packet loss**.

---

## 4. Machine B — Kubernetes, monitoring, démonstration de scaling

### 4.1 Tailscale (sur A **et** B)

```bash
bash scripts/infra/install-tailscale.sh
```
Suivre le lien d'authentification affiché — **utiliser le même compte que sur
l'autre machine**. À la fin, `tailscale status` doit montrer les deux machines.
Notez l'IP Tailscale de chaque machine (`tailscale ip -4`), elles seront
réutilisées dans toute la suite.

### 4.2 K3s — control-plane (sur B)

```bash
bash scripts/infra/install-k3s-server.sh
```
Installe K3s avec `--node-ip` forcé sur l'IP Tailscale (évite une dépendance à
une IP locale DHCP instable — un bug réel rencontré en Phase 3, cf.
`docs/architecture/difficultes-deploiement-k8s.md`, incident 2). Configure
`kubectl` pour l'utilisateur courant. Récupérez le token affiché en fin de
script (`sudo cat /var/lib/rancher/k3s/server/node-token`) — **ne pas le
partager en clair dans un dépôt public**.

### 4.3 K3s — agent, orchestration/scaling (sur A, optionnel selon vos objectifs)

Cette étape rejoint la machine A au cluster K8s de B, pour l'objectif secondaire
d'orchestration (elle n'est **pas requise** pour les mesures de dimensionnement,
qui reposent uniquement sur Docker/A — cf. §0.2) :

```bash
# Sur A :
bash scripts/infra/install-k3s-agent.sh <IP_TAILSCALE_B> <TOKEN>
```
Corrige au passage une politique iptables `FORWARD` que Docker peut positionner
en `DROP` (casse le réseau K3s/Flannel si non corrigé). Vérifiez depuis B :
```bash
kubectl get nodes
```

### 4.4 kube-prometheus-stack (sur B)

Pas encore scripté dans ce dépôt — commandes standard (Helm), avec le nom de
release `prometheus` et le namespace `monitoring` attendus par les scripts du
dépôt (`post-reboot-check.sh`, `appliquer-metriques-5gc-externe.sh`) :

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
kubectl get pods -n monitoring
```

### 4.5 UPF en pod K8s + démonstration de scaling (sur B)

```bash
bash scripts/infra/deploy-upf-k8s.sh
```
Intègre 3 correctifs déjà découverts (interface `ogstun` orpheline, logger
incompatible avec `kubectl logs`, entrypoint de l'image incompatible avec
`/bin/sh`) — détail complet dans `docs/architecture/difficultes-deploiement-k8s.md`
si le pod n'atteint pas `1/1 Running`.

Démonstration de scaling (indépendante du testbed de mesure sur A) :
```bash
kubectl scale deployment/upf -n nfv-5g --replicas=2
kubectl get pods -n nfv-5g -l app=upf -w
```

---

## 5. Relier A et B pour la supervision à distance

### 5.1 Exposer les métriques Docker de A sur le tailnet

```bash
# Sur A :
bash scripts/deploiement/05-activer-metriques-prometheus.sh
bash scripts/deploiement/06-exposer-metriques-tailscale.sh
```
Le second script affiche l'IP Tailscale de A à transmettre à B, et vérifie
lui-même que les 3 endpoints (AMF/SMF/UPF, ports 9091-9093) répondent.

### 5.2 Faire scraper ces métriques par Prometheus (sur B)

```bash
# Sur B :
bash scripts/infra/appliquer-metriques-5gc-externe.sh <IP_TAILSCALE_A>
```
Applique un `Service`/`Endpoints` (sans sélecteur, pointant vers l'IP de A) et
un `ServiceMonitor` — le pattern standard pour scraper une cible hors cluster
avec Prometheus Operator. Vérification : dans l'UI Prometheus (voir §7.1),
**Status → Targets**, chercher `5gc-docker-metrics`.

---

## 6. Lancer des mesures (sur A)

```bash
# Provisionner N abonnés de test (au-delà du premier, créé manuellement en §3)
bash scripts/mesures/01-provisionner-abonnes.sh

# Monter en charge : NB_UE UE, par paliers de PALIER_TAILLE
NB_UE=5 PALIER_TAILLE=5 bash scripts/mesures/02-scenario-trafic.sh

# Serveurs iperf3 dans le netns du conteneur UPF (mesure la capacité réelle de
# l'UPF, hors contrainte du lien Tailscale — cf. docs/cadrage/calibration-tailscale.md)
bash scripts/mesures/serveur-iperf3-local.sh

# Générer du trafic à travers les tunnels UE actifs
TARGET_IP=10.45.0.1 DUREE=20 bash scripts/mesures/03-generer-trafic-iperf3.sh

# Ou directement une campagne complète (paliers croissants x répétitions,
# fenêtres horodatées pour corrélation avec Prometheus côté B)
bash scripts/mesures/04-campagne-charge.sh
```

Résultats : `modele/donnees/raw/campagne-<horodatage>/resume.csv` (débit
agrégé/moyen, taux de réussite, fenêtre temporelle par run).

---

## 7. Visualiser les métriques

Deux options, non exclusives.

### 7.1 Grafana officiel (cluster K8s de B)

```bash
# Sur B :
bash scripts/infra/post-reboot-check.sh
```
Lance les `port-forward` Grafana (3000) et Prometheus (9091), affiche les URL
d'accès via l'IP Tailscale de B. Identifiants Grafana par défaut : voir le
secret généré par le chart (`kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d`).

### 7.2 Prometheus/Grafana locaux (machine A, sans dépendre de B)

```bash
# Sur A :
bash monitoring/local-machine-a/lancer-monitoring-local.sh
```
Scrape directement les métriques exposées en §5.1, sans passer par le cluster
K8s de B. Accès : `http://<IP_locale_A>:3000` (Grafana, `admin`/`admin`) et
`:9090` (Prometheus). Un dashboard prêt à importer (débit conteneur UPF via
cAdvisor, sessions PDU, CPU/RAM par NF) est fourni : voir
`monitoring/local-machine-a/dashboard-5gc.json`. cAdvisor doit être ajouté au
`docker-compose.yml` de ce dossier pour le panneau de débit — voir les
commentaires du fichier.

---

## 8. Où trouver quoi

| Question | Réponse |
|---|---|
| Résultats de mesure bruts | `modele/donnees/raw/campagne-*/resume.csv` |
| Le testbed ne passe pas le jalon PDU (§3) | `docs/guide-deploiement-reproductible.md`, section 4 (5 bugs documentés) |
| Le pod UPF K8s crash en boucle | `docs/architecture/difficultes-deploiement-k8s.md` |
| Pourquoi pas d'UPF distant (Run 2) ? | `docs/architecture/decision-abandon-run2.md` + `resultat-limite-pfcp-heartbeat.md` |
| Bande passante réelle du lien Tailscale | `docs/cadrage/calibration-tailscale.md` |
| Formules et stratégie de calibration du modèle | `docs/architecture/modele-files-attente.md` |
| Historique détaillé, jour par jour | `CHANGELOG.md` |

---

## 9. État actuel du projet (honnêteté sur ce qui n'est pas encore fait)

- `modele/notebooks/` et `modele/donnees/` (hors `raw/`) : formalisation théorique prête, exploitation des données encore à faire.
- ETSI OSM (`config/osm/`) : objectif secondaire de la note de cadrage, non implémenté à ce stade (dossier vide).
- `rapport/` et `soutenance/` : pas encore commencés.

Se référer à `CHANGELOG.md` pour l'avancement réel, jour par jour.
