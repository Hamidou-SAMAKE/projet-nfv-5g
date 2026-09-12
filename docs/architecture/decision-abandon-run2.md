# Décision — Recentrage de la Phase 4 sur Run 1 uniquement

*Étudiant A & B — Phase 3, fin.*

## Contexte

Le protocole initial (note de cadrage §5, revue Phase 3) prévoyait de comparer deux architectures de mesure en Phase 4 : Run 1 (baseline, toutes les NF colocalisées sur la machine A) et Run 2 (UPF migrée vers la machine B, orchestrée par Kubernetes). L'objectif était de transformer le risque méthodologique identifié dès la Phase 0 (latence/gigue inter-machines contaminant les mesures) en résultat scientifique exploitable.

## Investigation menée

La mise en œuvre technique du Run 2 a révélé un bug structurel indépendant de la question initiale (latence réseau) : un défaut de hairpin NAT dans la configuration Docker utilisée pour exposer le port PFCP du SMF, empêchant l'établissement stable d'une association PFCP entre le SMF (machine A, conteneurisé) et l'UPF (machine B, pod Kubernetes). Ce bug a été confirmé reproductible sur deux réseaux de latence très différente (Tailscale ~12,5 ms et réseau LAN interne à l'hyperviseur <1,5 ms), écartant l'hypothèse de latence comme cause.

Deux corrections structurelles ont été testées (réseau Docker macvlan, `network_mode: host`) sans aboutir à un résultat stable dans l'environnement de virtualisation imbriquée utilisé (VM invitée sous VMware Workstation, sous Windows 11) — cf. `resultat-limite-pfcp-heartbeat.md` pour le détail complet de l'investigation.

## Décision

**La Phase 4 est recentrée sur le Run 1 uniquement.** Le Run 2, tel que conçu, est abandonné comme protocole de mesure faute d'une solution stable trouvée dans le temps disponible du projet.

## Justification

- Aucun des 4 objectifs du cahier des charges n'exige explicitement une comparaison de topologie — la comparaison Run1/Run2 était une valeur ajoutée méthodologique décidée par le binôme en Phase 0, pas une exigence initiale.
- Les objectifs 1, 3 et 4 (testbed fonctionnel, modélisation par files d'attente, validation par mesures) sont entièrement réalisables sur Run 1 seul.
- L'objectif 4 inclut une démonstration de scaling orchestré — réalisable sur Kubernetes en local (passage de l'UPF de `replicas: 1` à `replicas: 2` sur la machine B), sans dépendre d'une architecture inter-machines.
- L'investigation du bug PFCP/hairpin NAT reste conservée comme résultat scientifique à part entière (section « limites » du rapport), indépendamment de l'abandon du protocole de mesure Run1/Run2.

## Conséquences sur la suite du projet

- La Phase 4 (J22-J27) est révisée : les campagnes de charge (J24-J25, initialement Run1/Run2) sont fusionnées en une campagne complète sur Run 1, avec un scénario de scaling K8s local démontré au J27.
- Le protocole de comparaison de topologie (note de cadrage §5, variables à contrôler, protocole en 3 étapes) est retiré des documents « vivants » (note de cadrage, plan des tâches), qui reflètent désormais le scope réel du projet à partir de ce point.
- Les documents relatant l'investigation (`resultat-limite-pfcp-heartbeat.md`, `difficultes-deploiement-k8s.md`, la calibration Tailscale) sont conservés tels quels, sans modification rétroactive — ils documentent un travail réel et une démarche scientifique rigoureuse, valorisable dans le rapport final (section limites/difficultés rencontrées).
- L'historique Git n'est pas réécrit : les commits relatifs au développement du Run 2 restent visibles, cohérents avec le principe de traçabilité des contributions du projet.
