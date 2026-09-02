# Difficultés de déploiement — UPF sur Kubernetes (Phase 3)

*Étudiant B — machine B, jalon J15-16 (déploiement de l'UPF en pod K8s pour le Run 2).*

## Symptôme initial

Lors du premier déploiement de l'UPF en pod K8s sur la machine B, le conteneur entrait en boucle de redémarrage (`CrashLoopBackOff`) immédiatement après son démarrage — le pod passait brièvement à `1/1 Running` puis crashait environ une seconde après, en boucle.

## Diagnostic — deux pistes initiales, toutes deux réelles mais non suffisantes

**Piste 1 — conflit d'interface réseau.** Les logs affichaient :
```
Error: ipv4: Address already assigned.
RTNETLINK answers: File exists
```
L'interface `ogstun` (créée par une tentative précédente) restait orpheline sur l'hôte B après chaque crash, provoquant cette erreur au redémarrage suivant. Correction : suppression manuelle (`sudo ip link delete ogstun`). Ce message s'est avéré non fatal en réalité (le script de configuration réseau continue son exécution malgré l'échec de cette étape) — un faux positif dans le diagnostic initial.

**Piste 2 — chemin de log inaccessible.**
```
09/01 22:34:17.719: [app] FATAL: cannot open log file : /open5gs/install/var/log/open5gs/upf.log
09/01 22:34:17.719: [app] FATAL: Open5GS initialization failed. Aborted
```
Le dossier de log n'existe pas dans l'image et aucun volume n'était monté à cet emplacement. Correction : suppression de la section `logger.file` du `upf.yaml`, pour laisser Open5GS logger sur la sortie standard — cohérent avec le modèle Kubernetes (`kubectl logs`), qui repose sur stdout plutôt que sur des fichiers de log.

Cette deuxième correction a éliminé l'erreur fatale affichée, **mais le pod continuait de crasher**, ce qui a montré qu'une troisième cause, non visible dans les logs standards, restait à identifier.

## Cause réelle — incompatibilité de shell dans l'entrypoint

Un pod de diagnostic (image identique, commande de démarrage forcée à `sleep 3600` pour rester actif) a permis d'exécuter manuellement le binaire `open5gs-upfd` directement, via `/bin/bash` :
```
Open5GS daemon v2.7.6
[pfcp] INFO: pfcp_server() [0.0.0.0]:8805
[gtp] INFO: gtp_server() [0.0.0.0]:2152
[app] INFO: UPF initialize...done
```
Aucune erreur — le binaire, la configuration et les interfaces réseau étaient corrects.

En reproduisant l'exécution normale du conteneur (chargement de `helper_functions.sh` via `/bin/sh`, l'interpréteur utilisé implicitement par Kubernetes), l'erreur suivante est apparue :
```
/bin/sh: 7: /usr/local/bin/helper_functions.sh: Syntax error: "(" unexpected
command terminated with exit code 2
```

**Cause identifiée** : `entrypoint.sh` et `helper_functions.sh` (fournis par l'image `ghcr.io/borjis131/upf`) sont écrits en syntaxe bash (déclarations de fonctions au format `function nom(){}`), incompatible avec `/bin/sh` (dash/busybox), le shell utilisé par défaut lors du lancement du conteneur dans ce contexte Kubernetes. L'entrypoint échouait donc silencieusement dès le chargement des fonctions réseau, avant même d'atteindre le binaire UPF — d'où l'absence de ce message dans les logs applicatifs récupérés par `kubectl logs` (le conteneur mourait trop vite pour que les logs soient fiablement capturés).

## Correction

Forcer explicitement l'exécution via bash dans le manifeste de déploiement Kubernetes :
```yaml
command: ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
args: ["-c", "/etc/open5gs/custom/upf.yaml"]
```

## Résultat

Pod stable, `1/1 Running`, `0` redémarrage sur plusieurs minutes d'observation continue. Jalon J15-16 (UPF déployée en pod K8s sur la machine B) validé.

## Enseignement méthodologique

Face à un crash trop rapide pour être capturé par les logs standards (`kubectl logs --previous` a échoué à plusieurs reprises pendant ce diagnostic, probablement parce que le conteneur mourait avant que containerd ne finalise l'écriture des logs), la méthode qui a permis de resoudre le problème a été de **reproduire l'exécution manuellement dans un pod de diagnostic** (`command: ["sleep", "3600"]`), en isolant chaque étape de l'entrypoint (chargement des fonctions, configuration réseau, lancement du binaire) plutôt que de chercher à interpréter des logs partiels ou absents.
