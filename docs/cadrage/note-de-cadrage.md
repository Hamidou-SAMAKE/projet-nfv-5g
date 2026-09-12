# NOTE DE CADRAGE — PHASE 0 (J1–J2)

*Déploiement et dimensionnement NFV d'un cœur de réseau 5G à l'aide d'outils open source*

*Révisée fin Phase 3 : recentrage sur Run 1 uniquement, cf. `docs/architecture/decision-abandon-run2.md`.*

|                     |                                                        |                |                                                            |
|---------------------|--------------------------------------------------------|----------------|------------------------------------------------------------|
| **Établissement**   | ESMT Dakar — Département Recherche et Innovation (DRI) | **Durée**      | 30 jours ouvrés                                            |
| **Étudiant A**      | Hamidou SAMAKE — Réseau & Orchestration                | **Étudiant B** | Cheick Abdoul Aziz BOUGOUM — Infrastructure & Modélisation |
| **Document établi** | J2 — révisé fin Phase 3 (recentrage Run 1)             | **Statut**     | À valider par l'encadrant                                  |

## 1. Contexte et objectif

La 5G Standalone repose sur un cœur de réseau (5GC) virtualisé, organisé en architecture orientée services (AMF, SMF, UPF, NRF, AUSF, UDM...). Ce projet complète le volet radio par le versant NFV : combien de ressources (vCPU, RAM, débit) faut-il allouer à chaque fonction du cœur pour absorber une charge d'usagers donnée ?

Objectif général : concevoir, déployer et dimensionner un cœur de réseau 5G SA virtualisé à partir d'outils open source, en confrontant une modélisation analytique de la capacité à des mesures expérimentales sous charge.

- Déployer un testbed 5G SA fonctionnel et démontrer l'établissement de sessions PDU de bout en bout.
- Virtualiser et orchestrer les fonctions réseau selon le modèle de référence ETSI NFV (NFVI / VNF / MANO).
- Modéliser la capacité des fonctions critiques (AMF, SMF, UPF) par des files d'attente et en déduire une règle de dimensionnement.
- Valider le modèle par des campagnes de charge et démontrer un scénario de mise à l'échelle orchestré.

## 2. Revue bibliographique ciblée

## 2.1 Fondement normatif 3GPP — architecture orientée service

- **3GPP TS 23.501 V15.5.0 (2019-03),** "System Architecture for the 5G System (5GS), Stage 2", Release 15

*Définit les deux représentations de l'architecture 5GC : orientée service (une NF expose ses services à d'autres NF autorisées) et par points de référence (interaction point-à-point, ex. N11 entre AMF et SMF).*

- **3GPP TS 23.502** — procédures (enregistrement, établissement de session PDU, handover)
- **3GPP TS 23.503** — politiques QoS (mobilisable si l'axe SMF/PCF est approfondi)

## 2.2 Cadre normatif ETSI NFV

- **ETSI GS NFV 002 V1.1.1 (2013-10)** — Architectural Framework : structure la NFV autour de trois domaines — VNF, NFVI, MANO.
- **ETSI GS NFV-MAN 001 V1.1.1 (2014-12)** — Management and Orchestration : rôle du cadre NFV-MANO dans la gestion de la NFVI et l'orchestration du cycle de vie des VNF.
- **ETSI NFV Release 4 (finalisée, v4.5.1)** — extensions container-native (série SOL001/002/003/005, dont SOL020 pour la gestion de clusters de conteneurs). Justifie le choix Docker/Kubernetes plutôt qu'OpenStack seul.

## 2.3 Piles open source — release 3GPP réellement supportée

- **Open5GS** — documentation officielle (open5gs.org, github.com/open5gs/open5gs) : version courante alignée Release 19.
- **free5GC** — projet Linux Foundation (free5gc.org) : branche principale alignée Release 15, branche « next » alignée Release 17. Option de repli.
- **UERANSIM** — github.com/aligungr/UERANSIM, simulateur gNB/UE (licence AGPL-3.0).
- **ETSI OSM** — documentation officielle osm.etsi.org/docs.

## 2.4 Sources écartées

*Extraits Scribd de drafts 3GPP non stabilisés, blogs non primaires, et brevets USPTO citant les specs en bibliographie : aucun de ces éléments n'est retenu comme référence citable dans le rapport final.*

## 3. Choix de la pile technique

**Choix retenu : Open5GS + UERANSIM.**

- Couple le plus documenté et le plus léger pour un testbed pédagogique.
- Alignement Release 19 : couverture large du périmètre « R15+ » exigé par le cahier des charges.
- Communauté active, nombreux guides de référence.

*free5GC reste une option de repli en cas de blocage majeur.*

## 4. Environnement matériel et réseau

## 4.1 Machines et rôles

|                       |                                              |                                                                                |
|-----------------------|----------------------------------------------|---------------------------------------------------------------------------------|
|                       | **Machine A**                                | **Machine B**                                                                 |
| **RAM**               | 8 Go                                          | 32 Go                                                                         |
| **Rôle**               | Testbed complet (5GC conteneurisé + UERANSIM natif) — héberge le Run 1 | Control-plane K8s + ETSI OSM (objectif secondaire) + Prometheus/Grafana + démonstration de scaling K8s (UPF, en local) |

Mise en réseau : VPN mesh (Tailscale) installé sur les deux machines pour la connectivité inter-machines (cluster K8s, monitoring à distance) — évite les problèmes de NAT/port-forwarding.

Ports/flux inter-machines : K8s API (TCP 6443), Kubelet (TCP 10250), CNI (Flannel/VXLAN).

## 5. Architecture retenue pour le dimensionnement (Phase 4)

Toutes les mesures de dimensionnement (Phase 4) sont réalisées sur la machine A, où le testbed complet (5GC conteneurisé + UERANSIM natif) est déployé et validé (jalon J14 : session PDU de bout en bout fonctionnelle, `ping -I uesimtun0` sans perte).

Le cluster Kubernetes (machine B, worker sur A) est utilisé pour l'objectif d'orchestration et de scaling : une démonstration de mise à l'échelle horizontale (passage de l'UPF de 1 à plusieurs instances via K8s) est réalisée **en local sur la machine B**, indépendamment du testbed de mesure sur A — ces deux volets ne sont pas couplés dans le protocole de mesure.

*Une architecture distribuée (UPF sur machine B, SMF sur machine A) a été explorée en Phase 3 dans le cadre d'un protocole de comparaison de topologies, initialement prévu pour cette section. Cette piste a été abandonnée suite à une limite technique identifiée (bug de hairpin NAT/conntrack, indépendant de la latence réseau) — cf. `docs/architecture/decision-abandon-run2.md` et `docs/architecture/resultat-limite-pfcp-heartbeat.md` pour le détail complet de l'investigation, conservée comme résultat scientifique à part entière.*

## 6. Répartition des rôles

|                        |                                                           |                                                                                       |
|------------------------|-------------------------------------------------------------|---------------------------------------------------------------------------------------|
|                        | **Étudiant A — Hamidou SAMAKE**                           | **Étudiant B — Cheick Abdoul Aziz BOUGOUM**                                           |
| **Domaine principal**  | Déploiement 5GC + RAN/UE, plans N2/N3/N4, sessions PDU, campagnes de charge | Virtualisation, VIM, orchestration K8s, dimensionnement analytique, démonstration de scaling |
| **Contributions clés** | Testbed fonctionnel (machine A, jalon J14 validé), scénarios de trafic, intégration RAN | NFVI/K8s, chaîne de mesure Prometheus/Grafana, modèle de files d'attente |
| **Livrable porté**     | Guide de déploiement reproductible                        | Modèle + campagnes de dimensionnement (Run 1) + démonstration de scaling K8s |

Jalons communs : cadrage (J2) · testbed opérationnel (J14) · chaîne de mesure prête (J21) · dimensionnement validé (J27) · rapport et soutenance (J30). Traçabilité via commits préfixés [A]/[B]/[A+B].

## 7. Structure du dépôt Git

- docs/ — note de cadrage, revue bibliographique, architecture, comparatifs
- scripts/ — déploiement (A), infra K8s (B), mesures (A+B)
- config/ — Open5GS, UERANSIM, K8s
- monitoring/ — Prometheus, Grafana
- modele/ — notebooks de modélisation, données brutes et traitées
- rapport/ — rapport LaTeX et figures
- soutenance/ — slides

## 8. Risques et mesures d'atténuation

|                                                                |                                       |                                                                                                |
|----------------------------------------------------------------|-----------------------------------------|-----------------------------------------------------------------------------------------------|
| **Risque**                                                     | **Impact**                            | **Mesure d'atténuation**                                                                       |
| Complexité d'OSM chronophage                                   | Retard Phase 4                        | OSM en objectif secondaire ; orchestration K8s manuelle suffit à valider le scaling            |
| Hypothèses du modèle mises en défaut (non-Poisson)             | Écart modèle/mesure                   | Documenter comme résultat scientifique ; tester un modèle alternatif (M/G/1)                   |
| Bug PFCP/hairpin NAT en architecture distribuée (résolu par abandon du Run 2) | Protocole de comparaison de topologie abandonné | Documenté comme résultat scientifique (cf. §5) ; dimensionnement validé sur Run 1 seul |
