# Note de cadrage — Déploiement et dimensionnement NFV d'un cœur de réseau 5G

**Binôme :** [Prénom NOM — Étudiant A] & [Prénom NOM — Étudiant B]
**Date :** J2

## 1. Objectif et périmètre

Déployer un testbed 5G Standalone virtualisé à partir d'outils open source, puis produire
un modèle de dimensionnement des ressources (vCPU, RAM, débit) des fonctions critiques du
cœur (AMF, SMF, UPF), validé par des campagnes de charge expérimentales.

## 2. Pile technique retenue

**Choix : Open5GS + UERANSIM**

Justification :
- Couple le plus documenté et le plus léger pour un testbed pédagogique
- Empreinte ressources faible (2-4 Go RAM pour l'ensemble des NF + simulateur gNB/UE),
  compatible avec la contrainte matérielle la plus stricte (8 Go)
- Communauté active, nombreux guides de référence

*(free5GC écarté pour cette itération — reste une option de repli si blocage majeur)*

## 3. Répartition des rôles

| | Étudiant A | Étudiant B |
|---|---|---|
| **Domaine** | Réseau & Orchestration | Infrastructure & Modélisation |
| **Responsabilités** | Déploiement 5GC (Open5GS), UERANSIM, plans N2/N3/N4, sessions PDU, scénarios de trafic | Virtualisation, K8s, orchestration OSM, chaîne Prometheus/Grafana, modèle de dimensionnement |
| **Livrable porté** | Guide de déploiement reproductible | Modèle + campagnes de dimensionnement |

## 4. Environnement matériel

| | Machine A | Machine B |
|---|---|---|
| RAM | 8 Go | 32 Go |
| Rôle | Open5GS + UERANSIM (phases 0-2) ; worker node K8s (phases 3-4) | Control-plane K8s, ETSI OSM (config recommandée 4 CPU/16 Go), Prometheus/Grafana |

**Mise en réseau** : VPN mesh (Tailscale), mis en place dès le J1. Ports à ouvrir entre les
deux machines :
- SCTP 38412 (N2), UDP 2152 (N3/GTP-U), UDP 8805 (N4/PFCP)
- K8s : TCP 6443 (API server), TCP 10250 (kubelet), port du CNI retenu

## 5. Planning résumé

| Jalon | Échéance |
|---|---|
| Note de cadrage validée | J2 |
| Testbed opérationnel | J14 |
| Chaîne de mesure prête | J21 |
| Dimensionnement validé | J27 |
| Rapport + soutenance | J30 |

## 6. Risques identifiés

| Risque | Mesure d'atténuation |
|---|---|
| Déséquilibre RAM (8 vs 32 Go) lors de la fusion en cluster K8s | Control-plane + OSM sur machine B, machine A en worker node uniquement |
| Dépendance réseau entre les deux machines | Tailscale testé dès J1, avant que ça devienne bloquant pour le testbed (J14) |
| Complexité OSM chronophage | Objectif secondaire si retard ; K8s "manuel" suffit à valider le scaling |
| Conflits de dépendances / échec d'installation | Déploiements conteneurisés (images/charts officiels) privilégiés |
