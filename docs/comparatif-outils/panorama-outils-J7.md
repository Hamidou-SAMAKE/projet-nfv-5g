# Panorama comparatif des outils — J7

*Open5GS vs free5GC vs UERANSIM vs ETSI OSM vs Kubernetes — Phase 1, clôture*

## 1. Cœurs de réseau 5G : Open5GS vs free5GC

| Critère | Open5GS | free5GC |
|---|---|---|
| Langage | C | Go |
| Gouvernance | Projet communautaire indépendant | Linux Foundation (contributeurs principaux : National Yang Ming Chiao Tung University) |
| Licence | AGPL-3.0 (double licence, commerciale via NewPlane) | Apache 2.0 — permissive, aucune obligation de republication |
| Release 3GPP | Release 19 (version courante — attention, des sources tierces datées mentionnent encore R16, obsolète) | Branche main : Release 15 ; branche « next » : Release 17 |
| Conception | Historiquement mono-hôte/VM, containerisation ajoutée ensuite | Cloud-native dès la conception, charts Helm officiels |
| Périphérie/EPC | Couvre aussi l'EPC 4G dans le même code base | Focalisé 5GC |
| Documentation | open5gs.org/docs — très complète, WebUI incluse | free5gc.org/guide — bonne doc, communauté plus restreinte |
| Pertinence pour le projet | Choix retenu : léger, documenté ; déjà utilisé par le binôme dans un projet de classe (testbed Open5GS + UERANSIM) | Option de repli en cas de blocage majeur, notamment si l'axe cloud-native est priorisé |

## 2. Simulateur RAN/UE : UERANSIM

- Langage : C++. Rôle : simule un gNB et un ou plusieurs UE, standard de facto pour tester un 5GC sans matériel radio réel.
- Compatible Open5GS et free5GC — confirme le choix indépendamment de la pile cœur retenue.
- Licence : AGPL-3.0 (double licence, commerciale disponible auprès de l'auteur).
- Alternative existante mais non retenue : my5G-RANTester, moins répandu que UERANSIM dans la communauté.

## 3. Orchestration : ETSI OSM vs Kubernetes « nu »

| Critère | ETSI OSM | Kubernetes seul |
|---|---|---|
| Conformité NFV-MANO | Orchestrateur NFV de référence, conforme au cadre ETSI (NFVO + VNFM intégrés) | N'est PAS un NFVO au sens NFV-MANO — orchestrateur de conteneurs généraliste ; le rôle NFVO/VNFM doit être « joué » manuellement (scripts, HPA) |
| Configuration minimale (vérifiée à la source, Release 19) | Recommandé : 4 CPU / 16 Go RAM / 80 Go disque (installation par défaut, Ubuntu 24.04) | Variable selon distribution (k3s/minikube largement < 4 Go) |
| Courbe d'apprentissage | Élevée — nombreux composants (LCM, RO, NBI, MON, Kafka, MongoDB...) | Modérée — écosystème plus répandu, davantage de ressources d'apprentissage |
| Adéquation contrainte matérielle (machine A, 8 Go) | Ne tient pas sur la machine A ; nécessite la machine B (32 Go) | Compatible avec les deux machines (nœud worker léger côté A) |
| Décision retenue | Objectif secondaire — installé sur la machine B si le temps le permet, pour démontrer la conformité MANO | Socle principal d'orchestration (control-plane B, worker A), avec scaling piloté manuellement/HPA en cas de retard sur OSM |

*Cette configuration OSM confirme et sécurise le chiffre déjà utilisé dans notre note de cadrage et dans le plan  — source vérifiée : osm.etsi.org/docs (Quickstart, dernière version).*

## 4. Grille de décision — justification devant jury

- Légèreté vs contrainte matérielle : Open5GS + UERANSIM tiennent sur la machine A (8 Go) ; OSM ne tient que sur la machine B (32 Go) → argument déjà utilisé pour répartir les rôles A/B.
- Fidélité au standard 3GPP : les deux cœurs couvrent largement le périmètre R15+ exigé ; Open5GS va plus loin (R19).
- Fidélité au standard NFV-MANO : Kubernetes seul est un écart assumé et documenté par rapport au modèle ETSI de référence — OSM reste l'option de conformité complète si le temps le permet.
- Communauté et maintenabilité : Open5GS a la communauté la plus large pour un projet pédagogique en délai contraint (30 jours).

## 5. Sources vérifiées (à recontrôler vous-mêmes)

- [Open5GS — dépôt officiel (licence, release)](https://github.com/open5gs/open5gs)
- [free5GC — site officiel (licence, gouvernance Linux Foundation)](https://free5gc.org/)
- [free5GC — dépôt officiel](https://github.com/free5gc/free5gc)
- [UERANSIM — dépôt officiel (licence)](https://github.com/aligungr/UERANSIM)
- [ETSI OSM — Quickstart officiel (configuration minimale/recommandée)](https://osm.etsi.org/docs/user-guide/latest/getting-started/quickstart.html)
