# NOTE DE CADRAGE — PHASE 0 (J1–J2)

*Déploiement et dimensionnement NFV d'un cœur de réseau 5G à l'aide d'outils open source*

|                     |                                                        |                |                                                            |
|---------------------|--------------------------------------------------------|----------------|------------------------------------------------------------|
| **Établissement**   | ESMT Dakar — Département Recherche et Innovation (DRI) | **Durée**      | 30 jours ouvrés                                            |
| **Étudiant A**      | Hamidou SAMAKE — Réseau & Orchestration                | **Étudiant B** | Cheick Abdoul Aziz BOUGOUM — Infrastructure & Modélisation |
| **Document établi** | J2 — note de cadrage                                   | **Statut**     | À valider par l'encadrant                                  |

## 1. Contexte et objectif

La 5G Standalone repose sur un cœur de réseau (5GC) virtualisé, organisé en architecture orientée services (AMF, SMF, UPF, NRF, AUSF, UDM...). Ce projet complète le volet radio par le versant NFV : combien de ressources (vCPU, RAM, débit) faut-il allouer à chaque fonction du cœur pour absorber une charge d'usagers donnée ?

Objectif général : concevoir, déployer et dimensionner un cœur de réseau 5G SA virtualisé à partir d'outils open source, en confrontant une modélisation analytique de la capacité à des mesures expérimentales sous charge.

- Déployer un testbed 5G SA fonctionnel et démontrer l'établissement de sessions PDU de bout en bout.

- Virtualiser et orchestrer les fonctions réseau selon le modèle de référence ETSI NFV (NFVI / VNF / MANO).

- Modéliser la capacité des fonctions critiques (AMF, SMF, UPF) par des files d'attente et en déduire une règle de dimensionnement.

- Valider le modèle par des campagnes de charge et proposer des scénarios de mise à l'échelle argumentés.

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

- **Open5GS** — documentation officielle (open5gs.org, github.com/open5gs/open5gs) : version courante alignée Release 19. Sources tierces datées (ex. blogs 2021) mentionnant la Release 16 sont obsolètes et à ne pas citer.

- **free5GC** — projet Linux Foundation (free5gc.org) : branche principale alignée Release 15, branche « next » alignée Release 17. Option de repli si blocage majeur sur Open5GS.

- **UERANSIM** — github.com/aligungr/UERANSIM, simulateur gNB/UE (licence AGPL-3.0, à mentionner dans le rapport).

- **ETSI OSM** — documentation officielle osm.etsi.org/docs (orchestrateur NFV, onboarding de packages VNF/NS).

## 2.4 Sources écartées

*Extraits Scribd de drafts 3GPP non stabilisés (ex. TS 23.501 V0.0.0/V0.1.1, 2017, sections encore marquées « Editor's notes »), blogs non primaires, et brevets USPTO citant les specs en bibliographie : aucun de ces éléments n'est retenu comme référence citable dans le rapport final.*

## 3. Choix de la pile technique

**Choix retenu : Open5GS + UERANSIM.**

- Couple le plus documenté et le plus léger pour un testbed pédagogique (empreinte de 2 à 4 Go de RAM suffisante, compatible avec la contrainte matérielle la plus stricte du binôme).

- Alignement Release 19 : couverture large du périmètre « R15+ » exigé par le cahier des charges.

- Communauté active, nombreux guides de référence pour le déploiement et le débogage.

*free5GC reste une option de repli en cas de blocage majeur (axe cloud-native, charts Kubernetes officiels).*

## 4. Environnement matériel et réseau

## 4.1 Machines et rôles

|                       |                                    |                                                                               |
|-----------------------|------------------------------------|-------------------------------------------------------------------------------|
|                       | **Machine A**                      | **Machine B**                                                                 |
| **RAM**               | 8 Go                               | 32 Go                                                                         |
| **Rôle (phases 0-2)** | Open5GS (toutes les NF) + UERANSIM | Préparation de l'environnement K8s/OSM en parallèle                           |
| **Rôle (phases 3-5)** | Worker node du cluster Kubernetes  | Control-plane K8s + ETSI OSM (4 CPU / 16 Go recommandés) + Prometheus/Grafana |

Mise en réseau : VPN mesh (Tailscale) installé sur les deux machines dès le J1 — évite les problèmes de NAT/port-forwarding. Alternative : réseau local avec IP fixes.

Ports/flux inter-machines à ouvrir : N2 (SCTP 38412, signalisation gNB↔AMF), N3 (UDP 2152 GTP-U, plan usager gNB↔UPF), N4 (UDP 8805 PFCP, contrôle UPF↔SMF), K8s API (TCP 6443), Kubelet (TCP 10250), CNI (selon plugin Calico/Flannel).

## 5. Point méthodologique — architecture nœud unique vs distribuée

Le choix d'une architecture à deux machines reliées par VPN (plutôt qu'un poste unique hébergeant tout le testbed) apporte un avantage réel — utilisation effective des deux machines, rapprochement d'un vrai cluster K8s distribué (control-plane / worker séparés) — mais introduit un risque méthodologique pour l'objectif 4 : si AMF/SMF/UPF sont répartis entre deux machines, chaque appel N2/N3/N4 traverse un réseau réel avec une latence et une gigue non nulles, ce qui peut contaminer la mesure du temps de service µ par NF utilisée pour valider le modèle de files d'attente.

**Décision retenue : ne pas trancher entre les deux architectures, mais les comparer et quantifier l'effet de la topologie sur le dimensionnement — ce risque devient un résultat scientifique du rapport plutôt qu'un biais non contrôlé.**

## 5.1 Variables à contrôler

|                                                                            |                                                                             |
|----------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| **Variable maintenue constante**                                           | **Pourquoi**                                                                |
| Nombre d'UE simulés et profil de montée en charge (paliers, intervalles)   | Sinon l'écart pourrait venir du trafic, pas de la topologie                 |
| Version des NF (même build Open5GS, mêmes YAML)                            | Évite une variable confondue avec le placement                              |
| Ressources allouées par NF (mêmes limites CPU/RAM)                         | Évite de mesurer un effet de sous-dimensionnement plutôt qu'un effet réseau |
| Script et paramètres de génération de charge (UERANSIM, iperf3)            | Reproductibilité                                                            |
| Charge parasite des machines contrôlée (CPU idle vérifié avant chaque run) | Évite de confondre contention CPU locale et latence réseau                  |

*Seule variable qui change entre les deux runs : la topologie de placement des NF (colocalisées vs réparties AMF/SMF/UPF entre les deux machines via Tailscale).*

## 5.2 Protocole en trois étapes

- Calibration préalable (dès J1-J2, pas en Phase 4) : mesurer la latence et la gigue du lien Tailscale à vide (ping, iperf3) entre les deux machines — donnée de référence citée dans le rapport, à re-mesurer si le lien semble varier dans le temps.

- Run 1 — baseline nœud unique : AMF+SMF+UPF colocalisées sur la machine B (32 Go). Mesure du temps de service µ par NF dans les conditions les plus propres possible — ce run valide le modèle analytique (objectifs 3/4).

- Run 2 — distribué : même charge, mêmes UE, même script de montée en charge, AMF/SMF/UPF réparties selon l'architecture Tailscale du binôme. Mêmes métriques relevées.

Comparaison : écart entre les deux courbes de latence/débit, mis en regard de la latence réseau mesurée en calibration. Si l'écart correspond à la latence Tailscale mesurée, l'explication est solide ; si l'écart est plus grand, une autre cause doit être recherchée (ex. contention CPU sur la machine 8 Go) — à documenter en section « limites » du rapport.

## 5.3 Scope retenu

**La Phase 4 ne compte que 6 jours (J22-J27), déjà dense. La comparaison nœud unique / distribué est donc limitée à l'UPF — la NF la plus exposée au trafic inter-machines (elle porte N3 et N4) — plutôt qu'aux trois NF critiques, pour rester réalisable dans le planning.**

## 6. Répartition des rôles

|                        |                                                           |                                                                                       |
|------------------------|-----------------------------------------------------------|---------------------------------------------------------------------------------------|
|                        | **Étudiant A — Hamidou SAMAKE**                           | **Étudiant B — Cheick Abdoul Aziz BOUGOUM**                                           |
| **Domaine principal**  | Déploiement 5GC + RAN/UE, plans N2/N3/N4, sessions PDU    | Virtualisation, VIM, orchestration OSM, dimensionnement analytique                    |
| **Contributions clés** | Testbed fonctionnel, scénarios de trafic, intégration RAN | NFVI/K8s, chaîne de mesure Prometheus/Grafana, modèle de files d'attente              |
| **Livrable porté**     | Guide de déploiement reproductible                        | Modèle + campagnes de dimensionnement (incluant la comparaison nœud unique/distribué) |

Jalons communs : cadrage (J2) · testbed opérationnel (J14) · chaîne de mesure prête (J21) · dimensionnement validé (J27) · rapport et soutenance (J30). Traçabilité via commits préfixés \[A\]/\[B\]/\[A+B\].

## 7. Structure du dépôt Git

- docs/ — note de cadrage, revue bibliographique, architecture, comparatifs

- scripts/ — déploiement (A), infra K8s/OSM (B), mesures (A+B)

- config/ — Open5GS, UERANSIM, K8s, OSM

- monitoring/ — Prometheus, Grafana

- modele/ — notebooks de modélisation, données brutes et traitées (incluant les deux runs)

- rapport/ — rapport LaTeX et figures

- soutenance/ — slides

## 8. Risques et mesures d'atténuation

|                                                                |                                       |                                                                                                |
|----------------------------------------------------------------|---------------------------------------|------------------------------------------------------------------------------------------------|
| **Risque**                                                     | **Impact**                            | **Mesure d'atténuation**                                                                       |
| Latence/gigue Tailscale contaminant les mesures Run 2          | Écart modèle/mesure non interprétable | Calibration préalable (ping/iperf3 à vide dès J1-J2) + comparaison ciblée sur l'UPF uniquement |
| Déséquilibre RAM (8 vs 32 Go) lors de la fusion en cluster K8s | Cluster instable                      | Control-plane + OSM sur machine B ; machine A en worker node uniquement                        |
| Complexité d'OSM chronophage                                   | Retard Phase 4                        | OSM en objectif secondaire si retard ; orchestration K8s manuelle suffit à valider le scaling  |
| Hypothèses du modèle mises en défaut (non-Poisson)             | Écart modèle/mesure                   | Documenter comme résultat scientifique ; tester un modèle alternatif (M/G/1)                   |
