# PLAN DÉTAILLÉ DES TÂCHES — ÉTUDIANT A / ÉTUDIANT B

*Déploiement et dimensionnement NFV d'un cœur de réseau 5G — Hamidou SAMAKE (A) & Cheick Abdoul Aziz BOUGOUM (B)*

*Révisé en Phase 3 suite au changement d'architecture Run1/Run2 (cf. `docs/cadrage/note-de-cadrage.md` §5 et `docs/architecture/choix-deploiement-docker.md`) : le Run 1 (baseline) est réalisé intégralement sur la machine A (5GC conteneurisé + UERANSIM natif, jalon J14 validé), le Run 2 (distribué) ne migre que l'UPF vers la machine B via Kubernetes. Phases 0-2 et 5 inchangées ; Phases 3 et 4 mises à jour ci-dessous.*

Principe général : A construit et fait fonctionner le testbed réseau ; B instrumente, orchestre et modélise ce qui s'y passe. Synchronisation à chaque jalon. Les cases grisées bleu = A, vert = B.

## Phase 0 — Cadrage (J1–J2) — travail conjoint

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J1 | Répartition des rôles, mise en place Git/GitLab (structure, README, convention de commits), cadrage matériel (machines, RAM, réseau, calibration Tailscale à prévoir). | Idem (travail conjoint J1). | Dépôt Git initialisé |
| J2 | Revue bibliographique : Open5GS, free5GC, UERANSIM. | Revue bibliographique : ETSI GS NFV-002, NFV-MAN 001, doc OSM. | |
| J2 | Mise en commun : choix de la pile (Open5GS + UERANSIM), rédaction de la note de cadrage. | Idem. | Note de cadrage (2 p.) validée par l'encadrant |

## Phase 1 — Fondamentaux (J3–J7) — parallèle puis fusion

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J3–J4 | Architecture 5G SA/SBA : rôles AMF/SMF/UPF/NRF, interfaces N1–N4, procédures d'enregistrement et de session PDU. | Revue en parallèle des concepts NFV/SDN (support à la colonne A). | Schéma d'architecture commenté |
| J5–J6 | Poursuite de l'approfondissement réseau / support à B si besoin. | Concepts NFV/SDN, modèle ETSI MANO (NFVI, VNF/CNF, NFVO, VNFM, VIM), notion de dimensionnement. | Fiche de synthèse NFV |
| J7 | Panorama comparatif des outils (Open5GS vs free5GC, UERANSIM, OSM, K8s) et justification des choix. | Idem (conjoint). | Tableau comparatif argumenté |

## Phase 2 — Déploiement du testbed (J8–J14) — A pilote, B en support

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J8–J9 | Préparation de l'hôte (Ubuntu LTS, Docker), installation d'Open5GS conteneurisé (docker-open5gs), configuration des NF et de la base d'abonnés. | Prépare en parallèle l'environnement K8s (installation de base) sur la machine B, documente au fil de l'eau. | 5GC démarré, NF « up » |
| J10–J11 | Installation et configuration d'UERANSIM (gNB natif + 1 UE), appairage N2/N3 avec le cœur conteneurisé. | Support débogage réseau inter-machines (Tailscale, ports). | gNB enregistré sur l'AMF |
| J12–J13 | Établissement d'une session PDU, test de connectivité plan usager (ping/iperf), dépannage (bugs PLMN, port GTP, endpoint réseau — cf. `choix-deploiement-docker.md`). | Support tests, prépare les premiers exporters Prometheus. | Connectivité de bout en bout |
| J14 | Consolidation, scripts de déploiement reproductibles, capture des configurations. | Idem (conjoint). | **JALON : testbed opérationnel + guide v1 — validé (`ping -I uesimtun0 8.8.8.8`, 0% perte)** |

## Phase 3 — Virtualisation, orchestration et métrologie (J15–J21) — *révisée*

*L'UPF seule est conteneurisée/orchestrée sur K8s (machine B) pour servir de cible de migration en Run 2 ; AMF/SMF/UERANSIM restent sur la machine A dans les deux runs.*

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J15 | Documente précisément la config actuelle AMF/SMF pointant vers l'UPF locale (adresses N3/N4) — base de référence pour le basculement à venir. | Construit le manifeste K8s de l'UPF seule : Deployment + Service exposant N3 (UDP 2152) et N4 (UDP 8805) en NodePort (accès depuis A, hors cluster). | Manifeste UPF K8s prêt (non testé) |
| J16 | Prépare les scénarios de trafic paramétrables (UERANSIM + iperf3), réutilisables identiquement pour Run 1 et Run 2. | Déploie l'UPF en pod sur B, teste la connectivité N3/N4 depuis A via Tailscale — attention aux bugs déjà documentés côté A (PLMN, endpoint réseau), possiblement sous une autre forme côté K8s. | UPF pod K8s démarré et joignable depuis A |
| J17 | Support tests d'intégration ; ajuste la config SMF pour pointer vers le NodePort de B plutôt que l'UPF locale, selon le mode (Run1/Run2). | Construit et documente un **mécanisme de bascule explicite** (script ou procédure) entre « configuration Run 1 » (UPF locale sur A) et « configuration Run 2 » (UPF sur B). | Script de bascule Run1/Run2 fonctionnel |
| J18 | Valide qu'une session PDU complète s'établit en configuration Run 2 (UPF distante) — même test qu'au J14, avec l'UPF sur B. | Installation ETSI OSM sur B (objectif secondaire — à mettre en pause si retard sur J15-17). | Session PDU validée en config distribuée |
| J19 | Finalise le script de montée en charge, testé dans les deux configurations. | Instrumentation Prometheus : exporters côté A (Docker/native) et côté B (pod K8s), métriques comparables entre les deux. | Métriques UPF collectées dans les 2 configs |
| J20 | Support tests. | Dashboards Grafana comparant les deux configurations en temps réel. | Dashboards opérationnels |
| J21 | Validation conjointe : Run 1 et Run 2 en miniature (charge faible), vérifier que la bascule est propre et les métriques cohérentes des deux côtés. | Idem. | **JALON : chaîne de mesure prête pour les deux architectures** |

## Phase 4 — Dimensionnement NFV (J22–J27) — *révisée*

*Le Run 1 (baseline) se déroule intégralement sur la machine A. Le Run 2 (distribué) ne déplace que l'UPF vers la machine B — AMF, SMF et UERANSIM restent sur A dans les deux runs.*

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J22 | Contribue aux hypothèses côté trafic réel observé. | Formalisation du modèle de files d'attente (M/M/1 vs M/M/c par NF, hypothèses, variables λ, µ, c). | Modèle analytique documenté |
| ~~J22~~ *(fait par anticipation, Phase 3)* | — | ~~Calibration Tailscale : latence, gigue, débit A↔B~~ **— déjà réalisée, cf. `docs/cadrage/calibration-tailscale.md`.** | Latence de référence mesurée ✅ |
| J23 | Support étalonnage. | Étalonnage : mesure de µ et de la consommation à vide par NF, **sur la machine A** (configuration Run 1). | Paramètres de base mesurés |
| J24 | **Run 1 (baseline)** : exécute les campagnes de charge, AMF+SMF+UPF+UERANSIM colocalisés **sur la machine A**. | Relève latence, débit, CPU/RAM par NF via Prometheus, identifie les points de saturation. | Jeu de mesures Run 1 (nœud unique, machine A) |
| J25 | **Run 2 (distribué)** : mêmes campagnes de charge, bascule via le script de J17 — **seule l'UPF migre vers la machine B** (pod K8s), AMF/SMF/UERANSIM restent sur A. | Idem — mêmes métriques relevées côté distribué, sur les deux machines. | Jeu de mesures Run 2 (UPF sur machine B) |
| J26 | Confrontation modèle ↔ mesures : courbes prédites vs mesurées, écarts, discussion des hypothèses. | Comparaison Run 1 vs Run 2 : écart mis en regard de la latence/débit Tailscale déjà calibrés. | Analyse comparative (2 runs) |
| J27 | Loi de dimensionnement par NF + au moins un scénario de scaling orchestré (scale-out démontré sur l'UPF, machine B). | Idem (conjoint) + conclusion sur l'effet de la topologie. | **JALON : dimensionnement validé** |

## Phase 5 — Consolidation, rapport et soutenance (J28–J30)

| Jour(s) | Étudiant A — Hamidou (Réseau & Orchestration) | Étudiant B — Cheick (Infrastructure & Modélisation) | Jalon / Sortie |
|---|---|---|---|
| J28 | Rédige : contexte, architecture, déploiement, guide de reproduction. | Rédige : modèle de dimensionnement, campagnes (Run 1 + Run 2), résultats, limites. | Rapport v1 |
| J29 | Finalisation du guide de reproduction, relecture croisée obligatoire, préparation de la démo et des slides. | Idem (conjoint). | Rapport v2 + démo répétée |
| J30 | Soutenance : présentation (20 min) + démonstration live + questions. | Idem (conjoint). | Restitution finale |

## Rappel — traçabilité des contributions

*Chaque commit est préfixé par auteur : [A] pour Hamidou, [B] pour Cheick, [A+B] pour le travail conjoint. Extraction rapide : `git log --grep="[A]"` ou `git log --grep="[B]"`.*
