# PLAN DÉTAILLÉ DES TÂCHES — ÉTUDIANT A / ÉTUDIANT B

*Déploiement et dimensionnement NFV d'un cœur de réseau 5G — Hamidou SAMAKE (A) & Cheick Abdoul Aziz BOUGOUM (B)*

*Révisé fin Phase 3 : Phase 4 recentrée sur Run 1 uniquement, cf. `docs/architecture/decision-abandon-run2.md`. Phases 0-3 inchangées (hors le volet Run2 de la Phase 3, abandonné — voir plus bas).*

Principe général : A construit et fait fonctionner le testbed réseau ; B instrumente, orchestre et modélise ce qui s'y passe. Synchronisation à chaque jalon.

## Phase 0 — Cadrage (J1–J2) — travail conjoint

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J1 | Répartition des rôles, mise en place Git, cadrage matériel. | Idem (travail conjoint J1). | Dépôt Git initialisé |
| J2 | Revue bibliographique : Open5GS, free5GC, UERANSIM. | Revue bibliographique : ETSI GS NFV-002, NFV-MAN 001, doc OSM. | |
| J2 | Mise en commun : choix de la pile, rédaction de la note de cadrage. | Idem. | Note de cadrage validée |

## Phase 1 — Fondamentaux (J3–J7)

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J3–J4 | Architecture 5G SA/SBA, interfaces N1–N4, procédures. | Revue en parallèle des concepts NFV/SDN. | Schéma d'architecture commenté |
| J5–J6 | Poursuite approfondissement réseau. | Modèle ETSI MANO, dimensionnement (M/M/1, M/M/c). | Fiche de synthèse NFV |
| J7 | Panorama comparatif des outils. | Idem (conjoint). | Tableau comparatif argumenté |

## Phase 2 — Déploiement du testbed (J8–J14)

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J8–J9 | Installation Open5GS conteneurisé, configuration NF. | Prépare l'environnement K8s sur B. | 5GC démarré |
| J10–J11 | UERANSIM (gNB natif + UE), appairage N2/N3. | Support débogage réseau. | gNB enregistré |
| J12–J13 | Établissement session PDU, dépannage. | Support tests, exporters Prometheus. | Connectivité bout en bout |
| J14 | Consolidation, scripts reproductibles. | Idem (conjoint). | **JALON : testbed opérationnel — validé (`ping -I uesimtun0`, 0% perte)** |

## Phase 3 — Virtualisation, orchestration et métrologie (J15–J21) — révisée

*Le volet « migration UPF vers B pour Run 2 » initialement prévu ici est abandonné (cf. décision ci-dessous). L'orchestration K8s reste développée sur B, réorientée vers une démonstration de scaling en local plutôt qu'une migration inter-machines.*

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J15–J16 | Scénarios de trafic paramétrables (validés, 5 UE). | Cluster K3s (serveur B + agent A) opérationnel et robuste au redémarrage. | Cluster K8s stable |
| J17–J18 | Support tests. | Déploiement UPF en pod K8s (image dédiée), débogage (cf. `difficultes-deploiement-k8s.md`). | UPF pod K8s stable |
| — | *Exploration Run 2 (UPF distante, SMF sur A) — bug PFCP/hairpin NAT identifié, non résolu malgré plusieurs pistes (macvlan, network_mode host). Décision d'abandon prise fin J18-J19.* | | *Documenté : `resultat-limite-pfcp-heartbeat.md`* |
| J19 | Finalise le script de montée en charge. | Instrumentation Prometheus (A et B). | Métriques collectées |
| J20 | Support tests. | Dashboards Grafana. | Dashboards opérationnels |
| J21 | Validation conjointe de la chaîne de mesure (Run 1 uniquement). | Idem. | **JALON : chaîne de mesure prête** |

## Phase 4 — Dimensionnement NFV (J22–J27) — révisée, Run 1 uniquement

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J22 | Contribue aux hypothèses côté trafic réel observé. | Formalisation du modèle de files d'attente (M/M/1 vs M/M/c par NF). | Modèle analytique documenté |
| J23 | Support étalonnage. | Étalonnage : mesure de µ et consommation à vide par NF, sur machine A. | Paramètres de base mesurés |
| J24–J25 | Campagnes de charge complètes sur le testbed (machine A), paliers croissants, plusieurs répétitions. | Relève latence, débit, CPU/RAM par NF via Prometheus, identifie les points de saturation. | Jeux de mesures complets |
| J26 | Confrontation modèle ↔ mesures : courbes prédites vs mesurées, écarts, discussion des hypothèses (Poisson, etc.). | Idem (conjoint) — analyse statistique des écarts. | Analyse modèle/mesures |
| J27 | Support à la démonstration de scaling. | **Démonstration de scaling orchestré** : UPF K8s de `replicas: 1` à `replicas: 2` (machine B, en local), observation de l'effet sur les métriques. | **JALON : dimensionnement validé + scaling démontré** |

## Phase 5 — Consolidation, rapport et soutenance (J28–J30)

| Jour(s) | Étudiant A | Étudiant B | Jalon / Sortie |
|---|---|---|---|
| J28 | Rédige : contexte, architecture, déploiement, guide de reproduction. | Rédige : modèle de dimensionnement, campagnes, résultats, limites (incluant l'investigation PFCP). | Rapport v1 |
| J29 | Finalisation, relecture croisée obligatoire, préparation démo et slides. | Idem (conjoint). | Rapport v2 + démo répétée |
| J30 | Soutenance : présentation (20 min) + démonstration live + questions. | Idem (conjoint). | Restitution finale |

## Rappel — traçabilité des contributions

*Chaque commit est préfixé par auteur : [A] pour Hamidou, [B] pour Cheick, [A+B] pour le travail conjoint.*
