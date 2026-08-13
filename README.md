# Déploiement et dimensionnement NFV d'un cœur de réseau 5G

Projet de fin d'étape — ESMT Dakar, Département Recherche et Innovation (DRI)

## Équipe

- **Étudiant·e A — Réseau & Orchestration** : déploiement 5GC, RAN/UE simulés
- **Étudiant·e B — Infrastructure & Modélisation** : virtualisation, orchestration, dimensionnement

## Objectif

Concevoir, déployer et dimensionner un cœur de réseau 5G Standalone virtualisé à partir
d'outils open source, en confrontant une modélisation analytique de la capacité à des
mesures expérimentales sous charge.

## Pile technique

- **Cœur 5G** : Open5GS
- **RAN + UE** : UERANSIM
- **Orchestration NFV** : Kubernetes + ETSI Open Source MANO (OSM)
- **Métrologie** : Prometheus + Grafana, iperf3

## Environnement

| | Machine A | Machine B |
|---|---|---|
| RAM | 8 Go | 32 Go |
| Rôle (phases 0-2) | Open5GS + UERANSIM | Préparation K8s/OSM |
| Rôle (phases 3-5) | Worker node K8s | Control-plane K8s + ETSI OSM + monitoring |

Connexion inter-machines : **Tailscale**. Voir [note de cadrage](docs/cadrage/note-de-cadrage.md)
pour le détail des ports et flux requis.

## Structure du dépôt

```
docs/          documentation (cadrage, architecture, synthèses)
scripts/       scripts de déploiement, infrastructure, mesures
config/        fichiers de configuration Open5GS, UERANSIM, K8s, OSM
monitoring/    configuration Prometheus/Grafana
modele/        notebooks et données de la modélisation analytique
rapport/       rapport technique et figures
soutenance/    support de soutenance
```

## Jalons

| Jalon | Échéance | Statut |
|---|---|---|
| Note de cadrage validée | J2 | ☐ |
| Testbed opérationnel (session PDU de bout en bout) | J14 | ☐ |
| Chaîne de mesure prête | J21 | ☐ |
| Dimensionnement validé (loi + scénario de scaling) | J27 | ☐ |
| Rapport et soutenance | J30 | ☐ |

## Convention de commits

Préfixe par auteur et type de changement, pour la traçabilité des contributions :

```
[A] feat: config initiale AMF/SMF
[B] feat: manifeste K8s pour NRF
[A+B] docs: mise à jour note de cadrage
[B] fix: correction endpoint Prometheus
```

Extraction de la contribution d'un membre : `git log --grep="\[A\]"` ou `git log --grep="\[B\]"`.

## Documentation

- [Note de cadrage](docs/cadrage/note-de-cadrage.md)
- [Journal de bord](CHANGELOG.md)
