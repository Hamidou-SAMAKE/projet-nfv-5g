# Calibration du lien Tailscale — donnée de référence

*Réalisée hors planning initial (prévue J1-J2, effectuée après mise en place effective de Tailscale en Phase 3) — Étudiant B, machine B vers/depuis machine A.*

## Contexte

Le protocole de comparaison nœud unique vs architecture distribuée (voir `note-de-cadrage.md`, section 5) prévoit une calibration préalable du lien Tailscale à vide, pour servir de référence lors de l'interprétation des écarts mesurés en Phase 4 (Run 1 vs Run 2). Cette calibration a été réalisée dès que le lien Tailscale entre A et B a été établi et stabilisé (installation de K3s, Phase 3), en retard sur le planning initial mais avant la Phase 4 — ce qui reste l'exigence critique.

## Machines concernées

| | Machine A | Machine B |
|---|---|---|
| Hostname | samake-ubuntu | machine-b |
| IP Tailscale | 100.91.77.11 | 100.82.162.11 |
| Rôle cluster K3s | Worker (agent) | Control-plane (server) |

## 1. Latence et gigue (ping)

Commande : `ping -c 100 100.82.162.11` (depuis A vers B)

| Métrique | Valeur |
|---|---|
| Latence minimale | 9.016 ms |
| Latence moyenne | 12.524 ms |
| Latence maximale | 30.601 ms |
| Gigue (mdev) | 3.536 ms |
| Paquets transmis | 100 |
| Perte de paquets | 0% |

**Observation** : le maximum (30.6 ms) dépasse nettement la moyenne + 2×gigue (≈19.6 ms), signe d'au moins un pic isolé pendant le test. À surveiller si ce type de pic se reproduit pendant les campagnes de charge réelles en Phase 4.

## 2. Débit (iperf3, TCP, 30 secondes)

### Sens A → B

| Métrique | Valeur |
|---|---|
| Débit moyen | 18.5 Mbits/sec |
| Retransmissions | Non consignées (première exécution, colonne absente du test) |
| Comportement | Relativement stable (17-22 Mbits/sec), un creux ponctuel à 4.19 Mbits/sec (22-25s) |

### Sens B → A (2 exécutions consécutives, test de reproductibilité)

| Métrique | Essai 1 | Essai 2 |
|---|---|---|
| Débit moyen | 14.2 Mbits/sec | 14.5 Mbits/sec |
| Retransmissions TCP (30s) | 1271 | 1015 |
| Comportement Cwnd | Oscillant (16-56 KB), pas de convergence stable | Oscillant (17-164 KB), pic initial élevé puis chute |

**Observation clé — reproductibilité confirmée** : les deux essais B→A donnent des résultats quasi identiques (écart de 0.3 Mbits/sec), ce qui indique une caractéristique **structurelle** du lien dans ce sens, pas un aléa ponctuel.

## 3. Type de connexion Tailscale

Commande : `tailscale status`

```
100.82.162.11  machine-b      cheickbougoum90-web@  linux  -
100.91.77.11   samake-ubuntu  cheickbougoum90-web@  linux  active; direct 41.82.211.16:48571
```

**Connexion directe confirmée** — pas de relais DERP intermédiaire. Le débit limité et les retransmissions observées ne sont donc pas imputables à un détour réseau via un serveur relais Tailscale, mais probablement à la bande passante réelle des connexions internet sous-jacentes des deux machines (asymétrie typique d'une connexion résidentielle : upload plus limité que download selon le sens).

## 4. Synthèse et implication pour la Phase 4

| Métrique | Valeur retenue |
|---|---|
| Latence de référence (aller-retour) | ~12.5 ms (moyenne), gigue ~3.5 ms |
| Perte de paquets (ICMP, faible charge) | 0% |
| Débit A→B | ~18.5 Mbits/sec |
| Débit B→A | ~14.35 Mbits/sec (moyenne 2 essais) |
| Retransmissions TCP sous charge (B→A) | ~1000-1300 / 30s — significatif |
| Asymétrie du lien | Oui, ~25-30% plus lent dans le sens B→A |

**Implication méthodologique pour le Run 2 (Phase 4)** : la latence de base est faible et stable, mais le débit TCP sous charge soutenue révèle des retransmissions significatives, en particulier dans le sens B→A. Si les campagnes de charge sur l'UPF (plan usager, fort débit) sollicitent majoritairement ce sens, il faut s'attendre à ce que cette caractéristique déjà mesurée ici se traduise par de la latence ou une perte de débit supplémentaire dans les mesures — un effet réseau anticipé et chiffré, pas une anomalie du modèle de files d'attente.

## Fichiers bruts associés (conservés en local, non versionnés)

- `calibration_ping_A-vers-B.log`
- `calibration_iperf3_A-vers-B.log`
- `calibration_iperf3_B-vers-A.log` (2 exécutions)

*Document établi rétroactivement en Phase 3 — Étudiant B.*
