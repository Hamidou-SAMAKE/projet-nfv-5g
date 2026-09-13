# Modélisation par files d'attente — formalisation (Phase 4, J22)

*Étudiant B — Infrastructure & Modélisation. Base théorique posée en Phase 1 (`fiche-synthese-NFV-PhaseB1.md`), complétée et opérationnalisée ici avec les métriques réellement disponibles (Prometheus/UPF, Phase 3).*

## 1. Notation et choix du modèle par fonction réseau

Notation de Kendall : **A/S/c** — loi d'arrivée / loi de service / nombre de serveurs (instances).

| NF | Modèle retenu | Justification |
|---|---|---|
| AMF | M/M/1 (c=1 par défaut), extensible en M/M/c | Événements de signalisation indépendants (attachements) — hypothèse de Poisson raisonnable en charge contrôlée |
| SMF | M/M/1 (c=1 par défaut), extensible en M/M/c | Événements de gestion de session (établissement/fermeture PDU) — même régime que l'AMF |
| UPF | M/M/1 ou M/M/c, **avec réserve méthodologique** (cf. §4) | Charge proportionnelle au volume de données, pas au nombre d'événements discrets — l'hypothèse de service "par requête" doit être adaptée (voir plus bas) |

**Rappel de la distinction de régime établie en Phase 1** (fiche de synthèse) : AMF/SMF sont sollicités par des **événements de contrôle** (une arrivée = un attachement ou une ouverture de session), tandis que l'UPF est sollicitée par un **volume de trafic continu** (octets/paquets par seconde) sur des sessions déjà établies. Cette distinction structure la façon dont λ et µ sont mesurés pour chaque NF (cf. §5).

## 2. Formules retenues

### M/M/1 (une instance)

| Paramètre | Formule | Signification |
|---|---|---|
| ρ (occupation) | ρ = λ / µ | Condition de stabilité : ρ < 1 |
| L | L = ρ / (1 − ρ) | Nombre moyen de requêtes dans le système |
| W | W = 1 / (µ − λ) | Temps moyen dans le système (Loi de Little : L = λW) |
| Lq, Wq | Lq = ρ² / (1 − ρ) ; Wq = ρ / (µ − λ) | Idem, en attente uniquement |

### M/M/c (c instances, scale-out horizontal)

ρ = λ / (c · µ)

Faire varier c dans le modèle simule directement un scale-out K8s (`replicas`) — c'est le paramètre observé concrètement en Phase 3-4 (cf. `demo-scaling-upf.md`, passage de c=1 à c=2).

## 3. Hypothèse de Poisson — validité et plan de vérification

Rappel (Phase 1) : le modèle suppose des arrivées indépendantes, sans mémoire (loi exponentielle des inter-arrivées).

**Plan de vérification, à exécuter sur les données réelles de campagne (J24-25)** :
- Calculer les inter-arrivées observées (temps entre deux établissements de session consécutifs)
- Test d'ajustement (ex. test du χ², ou comparaison visuelle de l'histogramme à une loi exponentielle)
- Si rejetée : documenter l'écart en section limites, tester un modèle alternatif **M/G/1** (loi de service générale, arrivées toujours Poisson) — formule d'Erlang C ou approximation de Pollaczek-Khinchine pour L/W dans ce cas

**Cas où l'hypothèse est structurellement fragile, identifié dès la Phase 1** : événements corrélés (reprise après coupure, "mass registration") — à signaler explicitement si le script de charge (UERANSIM, côté A) simule ce type de scénario.

## 4. Réserve méthodologique sur l'UPF — ancrage de session

Point établi lors d'un exercice de vérification en Phase 1-2 (conversation binôme/encadrant) : **une session PDU déjà établie reste ancrée sur l'instance UPF qui l'a acceptée** — un scale-out (c=1→c=2) ne bénéficie qu'aux **nouvelles** sessions, jamais à celles déjà en cours. Conséquence pour la mesure :

- Le modèle M/M/c classique suppose implicitement que n'importe quel serveur libre peut traiter n'importe quelle requête en attente — **hypothèse violée pour l'UPF** dès qu'il y a des sessions actives au moment du scale-out.
- **Implication pour le protocole de mesure (cf. §6 et §5.3 de la fiche J5-J6)** : les métriques post-scaling doivent être **labellisées par instance** (déjà anticipé dans le plan de mesure), pour isoler l'effet réel du scale-out sur la charge nouvellement acheminée, plutôt que de mélanger les sessions "héritées" de l'ancienne charge et les nouvelles.
- Pour l'AMF/SMF (événements discrets, pas de session longue "ancrée"), cette réserve ne s'applique pas — le modèle M/M/c standard reste valide sans adaptation.

## 5. Stratégie de mesure de λ et µ à partir des métriques Prometheus disponibles

Métriques natives Open5GS déjà branchées (cf. `config/k8s/upf-k8s.yaml`, dashboard Grafana `NFV-5G — UPF Dimensionnement`) :

| Métrique Prometheus | Usage pour le modèle |
|---|---|
| `fivegs_upffunction_upf_sessionnbr` | Estimation de L (nombre moyen de sessions "dans le système") en régime observé |
| `rate(fivegs_ep_n3_gtp_indatapktn3upf[1m])` / `outdatapktn3upf` | Proxy de λ pour l'UPF (taux d'arrivée de paquets, cohérent avec le régime "volume" de l'UPF, §1) |
| `fivegs_upffunction_sm_n4sessionestabreq` (compteur, à dériver en `rate()`) | λ au sens strict pour l'UPF — taux d'établissement de nouvelles sessions N4 |
| `process_cpu_seconds_total` | Proxy indirect de µ — le temps CPU consommé par requête traitée, sous charge connue, permet d'estimer le débit maximal de traitement (µ) par calibration |
| `pfcp_peers_active` | Vérification de robustesse (association SMF↔UPF active pendant la mesure) |

**Méthode de calibration de µ (à exécuter en J23, étalonnage)** : faire croître λ progressivement (paliers UERANSIM) jusqu'à observer la saturation (ρ → 1, W croissant fortement — comportement non linéaire déjà illustré par l'exemple numérique ci-dessous). Le point de saturation observé (débit maximal stable avant dégradation) donne une estimation empirique de µ, à comparer à la valeur théorique déduite de la configuration matérielle (CPU alloué).

Pour l'AMF/SMF, λ se mesure directement comme le taux d'événements de signalisation par seconde (scripts de charge, côté A) ; µ se calibre de la même façon, par palier jusqu'à saturation.

## 6. Exemple numérique de référence (rappel Phase 1, AMF, c=1)

Avec λ = 45 req/s et µ = 50 req/s :
- ρ = 0,9 → marge de sécurité faible (10%)
- L = 9 requêtes en moyenne dans le système
- W = 200 ms, soit 10× le temps de service pur (1/µ = 20 ms) — l'essentiel du délai vient de l'attente
- Avec c=2 : ρ = 0,45 → marge largement restaurée

**Comportement non linéaire à retenir pour la règle de dimensionnement** : au voisinage de ρ=1, une faible variation de λ provoque une explosion de W (ex. λ=48 → ρ=0,96 → W≈500 ms). La règle de dimensionnement visée n'est donc pas "au plus juste" mais avec **marge** — ρ cible typiquement < 0,7-0,8, cohérent avec les pratiques d'ingénierie réseau standard.

## 7. Prochaines étapes (dépendent des campagnes réelles, J24-25)

1. Exécuter les paliers de charge (UERANSIM, côté A) en relevant λ, µ par NF via les métriques ci-dessus.
2. Tester l'hypothèse de Poisson sur les inter-arrivées observées (§3).
3. Confronter les courbes L(λ), W(λ) prédites par le modèle aux valeurs mesurées.
4. Documenter les écarts (section limites) — origine possible : hypothèse Poisson invalidée, contention CPU non modélisée, effet d'ancrage de session pour l'UPF (§4).
5. En déduire la règle de dimensionnement finale : nombre d'instances par NF nécessaires pour une charge cible, avec marge ρ < 0,7-0,8.
