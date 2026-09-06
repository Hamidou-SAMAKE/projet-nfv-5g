# Résultat — Limite architecturale PFCP découverte lors du Run 2 (UPF distante)

*Phase 3-4 — lié à l'objectif 4 du cahier des charges (comparaison nœud unique / distribué).*

## Contexte

Dans le cadre du protocole de comparaison Run 1 (nœud unique, machine A) / Run 2 (UPF distante sur machine B, cf. `note-de-cadrage.md` §5), la mise en place technique du Run 2 a révélé une incompatibilité entre Open5GS et une architecture distribuée reliée par VPN public (Tailscale), indépendante de la configuration réseau elle-même.

## Chronologie du diagnostic

1. **Résolution DNS FQDN** : l'UPF ne pouvait pas résoudre l'identité `smf.open5gs.org` annoncée par le SMF (FQDN interne au réseau Docker de la machine A, non résolvable depuis le pod Kubernetes sur B). Corrigé en faisant annoncer le SMF avec son IP Tailscale plutôt qu'un FQDN.
2. **Bind d'adresse impossible** : le SMF ne pouvait pas se lier directement à son IP Tailscale à l'intérieur du conteneur Docker (adresse absente du namespace réseau du conteneur). Corrigé par un mapping de port Docker (`ports: "100.91.77.11:8805:8805/udp"`) combiné à une écoute interne sur `0.0.0.0`.
3. **Bug de hairpin NAT / conntrack** : les réponses PFCP de l'UPF apparaissaient avec une adresse source `127.0.0.1` côté SMF, empêchant la validation des transactions. Cause identifiée : des entrées conntrack UDP créées avant la désactivation du `userland-proxy` Docker restaient actives et faisaient ignorer les nouvelles règles NAT (bug documenté dans le projet Docker/Moby). Corrigé par purge manuelle des entrées conntrack (`conntrack -D`) après désactivation du proxy userland.
4. **Association PFCP réussie**, mais désassociation en boucle : une fois les trois problèmes précédents résolus, l'association PFCP initiale entre le SMF (machine A) et l'UPF (machine B) aboutissait, mais se rompait systématiquement quelques secondes plus tard avec l'erreur `No Heartbeat from UPF`/`No Heartbeat from SMF`.

## Cause racine identifiée

Le mécanisme de Heartbeat PFCP d'Open5GS applique un délai d'abandon de l'association fixe de **2,5 secondes** sans réponse, non configurable dans les fichiers de configuration YAML standards ni documenté comme paramétrable — confirmé par les développeurs eux-mêmes dans une discussion officielle du projet (github.com/open5gs/open5gs/discussions/3468), qui indiquent explicitement que ce comportement diffère d'autres implémentations UPF (ex. UPG-VPP, qui tolère 30 secondes sur 3 tentatives).

Ce délai est conçu pour un déploiement colocalisé (datacenter, latence sub-milliseconde) et non pour une architecture distribuée sur réseau étendu. La calibration du lien Tailscale entre A et B (cf. `calibration-tailscale.md`) avait déjà mis en évidence une latence moyenne faible (~12,5 ms) mais des retransmissions TCP notables sous charge soutenue (jusqu'à ~1300 retransmissions/30s dans le sens B→A) — cohérent avec des pertes de paquets UDP ponctuelles suffisantes pour dépasser le seuil de 2,5 secondes lors d'un aléa réseau, même mineur.

## Conclusion scientifique pour l'objectif 4

**L'architecture distribuée Run 2, telle que conçue (UPF sur machine distante reliée par VPN public), n'est pas viable avec Open5GS en configuration standard.** Ce n'est pas un défaut de configuration réseau ni un problème résolu par un réglage supplémentaire : c'est une limite du logiciel Open5GS lui-même, qui suppose implicitement un déploiement à très faible latence et perte quasi nulle entre le SMF et l'UPF sur l'interface N4/PFCP.

Ce résultat répond directement à la question posée par le protocole de comparaison Run1/Run2 : **la topologie de déploiement n'affecte pas seulement la performance mesurée (latence, débit) du plan de dimensionnement — elle peut rendre le système non fonctionnel avant même toute mesure**, si le logiciel d'infrastructure n'est pas conçu pour tolérer la variabilité d'un réseau étendu. C'est un résultat pertinent pour toute règle de dimensionnement future : le choix de la topologie n'est pas qu'un paramètre de performance, c'est une contrainte de faisabilité.

## Suite donnée

Un test complémentaire est mené (cf. `resultat-test-reseau-local.md`) pour déterminer si cette limite est strictement liée à la variabilité du lien Tailscale/Internet, ou si elle se manifeste également sur un réseau local à latence minimale — ce qui permettrait de circonscrire plus précisément la cause (latence pure vs pertes ponctuelles vs bug indépendant du réseau).
