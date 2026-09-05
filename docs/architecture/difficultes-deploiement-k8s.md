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

---

# Incident 2 — Perte de connexion du cluster après changement d'IP locale (Phase 3, tard)

## Contexte

Après un redémarrage complet des deux machines (test de robustesse volontaire), l'agent K3s sur la machine A n'arrivait plus à se reconnecter au control-plane sur B, malgré Tailscale fonctionnel des deux côtés (`tailscale status` montrait les deux machines actives et connectées directement).

## Symptôme

```
level=error msg="Failed to connect to proxy. Empty dialer response" error="dial tcp 192.168.1.13:6443: connect: no route to host"
```

L'agent tentait de joindre `192.168.1.13:6443` — une adresse IP **locale**, pas l'IP Tailscale de B (`100.82.162.11`) utilisée pourtant explicitement lors de l'installation initiale (`K3S_URL=https://100.82.162.11:6443`).

## Cause

K3s enregistre, en plus de l'URL de connexion initiale, l'**IP locale du node** (détectée automatiquement via l'interface réseau par défaut) pour certaines communications internes entre nodes du cluster. Cette IP locale est distribuée par DHCP et peut changer à chaque redémarrage ou reconfiguration réseau (dans notre cas, une bascule temporaire NAT→Bridged sur la VM de la machine B a provoqué un renouvellement de bail DHCP, changeant son IP locale de `192.168.1.12` à `192.168.1.13`). Le control-plane s'était donc enregistré avec une IP locale devenue invalide après ce changement, rendant le cluster injoignable pour l'agent malgré un lien Tailscale fonctionnel.

## Correction

Réinstallation du serveur K3s (sur B) et de l'agent (sur A) avec le paramètre `--node-ip` forcé explicitement sur l'adresse Tailscale de chaque machine :
```bash
# Sur B (serveur)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=100.82.162.11" sh -

# Sur A (agent)
curl -sfL https://get.k3s.io | K3S_URL=https://100.82.162.11:6443 K3S_TOKEN=<token> INSTALL_K3S_EXEC="--node-ip=100.91.77.11" sh -
```
Ce paramètre force K3s à utiliser l'IP Tailscale (stable, indépendante du DHCP local) pour toutes ses communications internes, éliminant la dépendance au réseau local.

## Conséquence opérationnelle

La réinstallation du serveur K3s a régénéré le cluster (nouveau token, nouvel état `etcd`), entraînant la perte du pod UPF précédemment déployé et stabilisé (Incident 1). Celui-ci a dû être redéployé après coup avec `scripts/infra/deploy-upf-k8s.sh`.

## Enseignement méthodologique

Face à un crash trop rapide pour être capturé par les logs standards (`kubectl logs --previous` a échoué à plusieurs reprises pendant ce diagnostic, probablement parce que le conteneur mourait avant que containerd ne finalise l'écriture des logs), la méthode qui a permis de resoudre le problème (Incident 1) a été de **reproduire l'exécution manuellement dans un pod de diagnostic** (`command: ["sleep", "3600"]`), en isolant chaque étape de l'entrypoint (chargement des fonctions, configuration réseau, lancement du binaire) plutôt que de chercher à interpréter des logs partiels ou absents.

L'Incident 2 illustre un principe distinct, propre aux architectures multi-machines reliées par VPN : une IP stable pour le VPN (Tailscale) ne suffit pas si le logiciel orchestré (ici K3s) capture par ailleurs une IP locale instable pour son propre usage interne. Toute option de configuration explicite pour forcer l'IP de communication (`--node-ip` chez K3s) doit être utilisée dès l'installation initiale dans ce type d'architecture, plutôt que de laisser le logiciel détecter automatiquement une interface réseau qui peut changer.
