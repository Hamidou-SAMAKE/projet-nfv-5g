# PLAN DÉTAILLÉ DES TÂCHES — ÉTUDIANT A / ÉTUDIANT B

*Déploiement et dimensionnement NFV d'un cœur de réseau 5G — Hamidou SAMAKE (A) & Cheick Abdoul Aziz BOUGOUM (B)*

Principe général : A construit et fait fonctionner le testbed réseau ; B instrumente, orchestre et modélise ce qui s'y passe. Synchronisation à chaque jalon. Les cases grisées bleu = A, vert = B.

## Phase 0 — Cadrage (J1–J2) — travail conjoint

|             |                                                                                                                                                                        |                                                                |                                                |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|------------------------------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                                                                                                                      | **Étudiant B — Cheick (Infrastructure & Modélisation)**        | **Jalon / Sortie**                             |
| J1          | Répartition des rôles, mise en place Git/GitLab (structure, README, convention de commits), cadrage matériel (machines, RAM, réseau, calibration Tailscale à prévoir). | Idem (travail conjoint J1).                                    | Dépôt Git initialisé                           |
| J2          | Revue bibliographique : Open5GS, free5GC, UERANSIM.                                                                                                                    | Revue bibliographique : ETSI GS NFV-002, NFV-MAN 001, doc OSM. |                                                |
| J2          | Mise en commun : choix de la pile (Open5GS + UERANSIM), rédaction de la note de cadrage.                                                                               | Idem.                                                          | Note de cadrage (2 p.) validée par l'encadrant |

## Phase 1 — Fondamentaux (J3–J7) — parallèle puis fusion

|             |                                                                                                                  |                                                                                                 |                                |
|-------------|------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|--------------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                                                                | **Étudiant B — Cheick (Infrastructure & Modélisation)**                                         | **Jalon / Sortie**             |
| J3–J4       | Architecture 5G SA/SBA : rôles AMF/SMF/UPF/NRF, interfaces N1–N4, procédures d'enregistrement et de session PDU. | Revue en parallèle des concepts NFV/SDN (support à la colonne A).                               | Schéma d'architecture commenté |
| J5–J6       | Poursuite de l'approfondissement réseau / support à B si besoin.                                                 | Concepts NFV/SDN, modèle ETSI MANO (NFVI, VNF/CNF, NFVO, VNFM, VIM), notion de dimensionnement. | Fiche de synthèse NFV          |
| J7          | Panorama comparatif des outils (Open5GS vs free5GC, UERANSIM, OSM, K8s) et justification des choix.              | Idem (conjoint).                                                                                | Tableau comparatif argumenté   |

## Phase 2 — Déploiement du testbed (J8–J14) — A pilote, B en support

|             |                                                                                                                   |                                                                                                                  |                                         |
|-------------|-------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------|-----------------------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                                                                 | **Étudiant B — Cheick (Infrastructure & Modélisation)**                                                          | **Jalon / Sortie**                      |
| J8–J9       | Préparation de l'hôte (Ubuntu LTS, Docker), installation d'Open5GS, configuration des NF et de la base d'abonnés. | Prépare en parallèle l'environnement K8s/OSM (installation de base) sur la machine B, documente au fil de l'eau. | 5GC démarré, NF « up »                  |
| J10–J11     | Installation et configuration d'UERANSIM (gNB + 1 UE), appairage N2/N3 avec le cœur.                              | Support débogage réseau inter-machines (Tailscale, ports).                                                       | gNB enregistré sur l'AMF                |
| J12–J13     | Établissement d'une session PDU, test de connectivité plan usager (ping/iperf), dépannage.                        | Support tests, prépare les premiers exporters Prometheus.                                                        | Connectivité de bout en bout            |
| J14         | Consolidation, scripts de déploiement reproductibles, capture des configurations.                                 | Idem (conjoint).                                                                                                 | JALON : testbed opérationnel + guide v1 |

## Phase 3 — Virtualisation, orchestration et métrologie (J15–J21) — B pilote, A en support

|             |                                                                         |                                                                                                                 |                                 |
|-------------|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|---------------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                       | **Étudiant B — Cheick (Infrastructure & Modélisation)**                                                         | **Jalon / Sortie**              |
| J15–J16     | Prépare les scénarios de trafic paramétrables réutilisables en Phase 4. | Conteneurisation des NF / passage en pods, prise en main de Kubernetes (control-plane sur B, A en worker node). | NF déployées en conteneurs/pods |
| J17–J18     | Support tests d'intégration.                                            | Installation d'ETSI OSM, onboarding d'un package (VNF/NS), instanciation orchestrée d'une fonction.             | Instanciation via OSM réussie   |
| J19–J20     | Finalise le script de montée en charge (UE + iperf3).                   | Chaîne de métrologie : Prometheus (exporters CPU/RAM par NF), Grafana (dashboards), instrumentation N3.         | Dashboards en temps réel        |
| J21         | Validation de la reproductibilité des mesures (conjoint).               | Idem.                                                                                                           | JALON : chaîne de mesure prête  |

## Phase 4 — Dimensionnement NFV (J22–J27) — travail conjoint serré

*Inclut le protocole de comparaison nœud unique vs architecture distribuée, validé pour objectiver l'effet de la topologie sur la mesure du temps de service µ (scope : UPF uniquement).*

|             |                                                                                                                  |                                                                                                    |                                    |
|-------------|------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|------------------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                                                                | **Étudiant B — Cheick (Infrastructure & Modélisation)**                                            | **Jalon / Sortie**                 |
| J22         | Contribue aux hypothèses côté trafic réel observé.                                                               | Formalisation du modèle de files d'attente (M/M/1 vs M/M/c par NF, hypothèses, variables λ, µ, c). | Modèle analytique documenté        |
| J22         | Calibration Tailscale : mesure ping/iperf3 à vide entre A et B (latence, gigue) — donnée de référence.           | Idem (conjoint, dès que possible dans la phase, idéalement anticipé dès J1-J2).                    | Latence de référence mesurée       |
| J23         | Support étalonnage.                                                                                              | Étalonnage : mesure de µ et de la consommation à vide par NF.                                      | Paramètres de base mesurés         |
| J24         | Run 1 (baseline) : exécute les campagnes de charge avec AMF+SMF+UPF colocalisées sur la machine B.               | Relève latence, débit, CPU/RAM par NF via Prometheus, identifie les points de saturation.          | Jeu de mesures Run 1 (nœud unique) |
| J25         | Run 2 (distribué) : mêmes campagnes de charge, AMF/SMF/UPF réparties selon l'architecture Tailscale (focus UPF). | Idem — mêmes métriques relevées côté distribué.                                                    | Jeu de mesures Run 2 (distribué)   |
| J26         | Confrontation modèle ↔ mesures : courbes prédites vs mesurées, écarts, discussion des hypothèses.                | Comparaison Run 1 vs Run 2 : écart mis en regard de la latence Tailscale calibrée (J22).           | Analyse comparative (2 runs)       |
| J27         | Loi de dimensionnement par NF + au moins un scénario de scaling orchestré (scale-out démontré).                  | Idem (conjoint) + conclusion sur l'effet de la topologie.                                          | JALON : dimensionnement validé     |

## Phase 5 — Consolidation, rapport et soutenance (J28–J30)

|             |                                                                                                             |                                                                                    |                           |
|-------------|-------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|---------------------------|
| **Jour(s)** | **Étudiant A — Hamidou (Réseau & Orchestration)**                                                           | **Étudiant B — Cheick (Infrastructure & Modélisation)**                            | **Jalon / Sortie**        |
| J28         | Rédige : contexte, architecture, déploiement, guide de reproduction.                                        | Rédige : modèle de dimensionnement, campagnes (Run 1 + Run 2), résultats, limites. | Rapport v1                |
| J29         | Finalisation du guide de reproduction, relecture croisée obligatoire, préparation de la démo et des slides. | Idem (conjoint).                                                                   | Rapport v2 + démo répétée |
| J30         | Soutenance : présentation (20 min) + démonstration live + questions.                                        | Idem (conjoint).                                                                   | Restitution finale        |

## Rappel — traçabilité des contributions

*Chaque commit est préfixé par auteur : \[A\] pour Hamidou, \[B\] pour Cheick, \[A+B\] pour le travail conjoint. Extraction rapide : git log --grep="\\A\\" ou git log --grep="\\B\\".*
