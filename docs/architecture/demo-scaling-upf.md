# Démonstration de scaling orchestré — UPF (Phase 4, J27)

*Étudiant B — machine B, cluster K3s.*

## Objectif

Démontrer, tel que requis par l'objectif 4 du cahier des charges, un scénario de mise à l'échelle orchestrée sur au moins une fonction réseau critique — réalisé ici sur l'UPF via Kubernetes (scale-out horizontal, `replicas: 1 → 2`).

## Contrainte architecturale découverte et corrigée

La première tentative de scale-out (`kubectl scale --replicas=2`) a échoué : le second pod restait bloqué en `Pending`, avec l'événement `"1 node(s) didn't have free ports for the requested pod ports"`. Cause identifiée : le `Deployment` UPF utilisait `hostNetwork: true` (nécessaire pour contourner un bug d'entrypoint bash rencontré en Phase 3, cf. `difficultes-deploiement-k8s.md`) — un mode réseau qui fait partager au pod la pile réseau de l'hôte, y compris ses ports. Deux instances en `hostNetwork` sur le même nœud entrent donc mécaniquement en conflit sur les ports PFCP (8805) et GTP-U (2152).

**Correction** : suppression de `hostNetwork: true`, retour au réseau de pod standard (Flannel/CNI), chaque réplica recevant sa propre IP interne au cluster (`10.42.0.x`). Cette correction n'était possible qu'après l'abandon du protocole Run 2 (cf. `decision-abandon-run2.md`) — `hostNetwork` n'était utile que pour exposer l'UPF à une IP fixe joignable depuis la machine A, un besoin qui n'existe plus.

## Résultat

Scale-out réussi et stable :
```
NAME                  READY   STATUS    RESTARTS   AGE   IP            NODE
upf-88764d495-zgfcs   1/1     Running   0          2m44s 10.42.0.177   machine-b
upf-88764d495-947j2   1/1     Running   0          88s   10.42.0.178   machine-b
```
Les deux instances démarrent proprement (`UPF initialize...done` dans les deux logs), sans erreur ni redémarrage, chacune avec son propre serveur PFCP/GTP-U/metrics sur une IP de pod distincte.

## Rattachement au modèle NFV-MANO

Ce scénario illustre concrètement la mécanique déjà formalisée dans la fiche de synthèse NFV (Phase 1) : la commande `kubectl scale` joue ici le rôle simplifié de NFVO+VNFM (décision de passer de c=1 à c=2, instanciation de la nouvelle instance), et Kubernetes (scheduler + kubelet) joue le rôle de VIM (allocation des ressources sur le nœud). C'est la démonstration pratique de l'écart assumé documenté dès la Phase 1 : ces rôles sont joués par le binôme et K8s, pas par un orchestrateur NFVO/VNFM normatif complet (OSM).

## Limite de cette démonstration

Le scale-out est démontré en local, sur un seul nœud (machine B), sans validation de son effet sur une charge réelle de trafic N3/N4 (aucune session UE active au moment du test, cf. `etalonnage-upf-repos.md`). L'effet du scaling sur les métriques de performance (latence, débit) sera observé lors des campagnes de charge réelles de la Phase 4, sur le testbed Run 1 (machine A) — ce test valide le mécanisme d'orchestration lui-même, pas encore son bénéfice mesuré sous charge.
