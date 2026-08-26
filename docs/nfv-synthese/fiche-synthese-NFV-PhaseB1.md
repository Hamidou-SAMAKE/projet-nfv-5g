Projet de stage NFV/5G — ESMT Dakar (DRI)

# FICHE DE SYNTHÈSE NFV

*Phase 1 — Fondamentaux (J5–J6) \| Étudiant B — Infrastructure & Modélisation \| Cheick Abdoul Aziz BOUGOUM*

## 1. Cadre normatif ETSI NFV — les trois domaines

La virtualisation des fonctions réseau (NFV) est structurée par l'ETSI (GS NFV 002) autour de trois domaines fonctionnels distincts, qu'il ne faut jamais confondre :

|             |                                                                                                                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Domaine** | **Définition**                                                                                                                                                                             |
| VNF / CNF   | Implémentation logicielle d'une fonction réseau (ex. AMF, SMF, UPF), packagée comme machine virtuelle (VNF) ou conteneur (CNF — extension container-native actée par l'ETSI en Release 4). |
| NFVI        | Infrastructure physique et virtuelle qui héberge et connecte les VNF/CNF : serveurs, hyperviseurs/runtime conteneur, réseau virtualisé.                                                    |
| MANO        | Management and Orchestration — coordonne l'allocation des ressources NFVI et le cycle de vie des VNF, rendu nécessaire par le découplage fonction/infrastructure.                          |

## 2. NFV-MANO — qui décide, qui exécute, qui alloue

Le cadre NFV-MANO se décompose en trois blocs fonctionnels, chacun responsable d'un niveau distinct de la chaîne de décision. Exemple d'application : scaling d'une AMF/UPF suite à un pic de charge.

|          |                                                                                                                                                             |                                                        |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------|
| **Bloc** | **Rôle**                                                                                                                                                    | **Dans notre scénario**                                |
| NFVO     | Orchestration au niveau service réseau ; peut coordonner plusieurs VNF et déclencher une politique de scaling au niveau service.                            | Décide qu'il faut passer de c=1 à c=2 instances d'AMF. |
| VNFM     | Gère le cycle de vie d'une VNF donnée : instanciation, configuration, mise à jour, terminaison. Peut aussi déclencher un scaling via ses propres métriques. | Démarre et configure la nouvelle instance d'AMF.       |
| VIM      | Contrôle les ressources virtualisées de la NFVI (CPU, RAM, stockage, réseau).                                                                               | Alloue les ressources à la nouvelle instance.          |

*Écart assumé pour ce projet : l'architecture retenue s'appuie sur Kubernetes comme VIM avec une orchestration « manuelle » (scripts + Prometheus/Grafana pour la détection, action de scale-out déclenchée manuellement ou via HPA Kubernetes), sans déploiement complet d'ETSI OSM. Les rôles NFVO et VNFM sont donc joués de façon simplifiée par le binôme plutôt que par un orchestrateur normatif complet.*

## 3. Deux régimes de charge distincts dans le 5GC

Le découpage contrôle/usager de la 5G SA implique deux régimes de sollicitation différents pour les NF critiques — point central pour choisir le bon modèle de dimensionnement par NF :

|        |          |                                                                                                                          |
|--------|----------|--------------------------------------------------------------------------------------------------------------------------|
| **NF** | **Plan** | **Charge proportionnelle à…**                                                                                            |
| AMF    | Contrôle | Nombre d'événements de signalisation (attachements, ré-attachements) — pas au volume de données.                         |
| SMF    | Contrôle | Nombre d'événements de gestion de session (ouverture/fermeture de session PDU).                                          |
| UPF    | Usager   | Volume/débit de données réellement transporté (octets ou paquets par seconde), pour toute la durée des sessions actives. |

Conséquence pratique : un pic de nouvelles connexions (attachements en masse) sollicite surtout AMF/SMF ; un pic de débit sur des sessions déjà établies sollicite surtout l'UPF. Ces deux régimes appellent des campagnes de charge et des jeux de mesures distincts en Phase 4.

## 4. Modélisation par files d'attente — notions retenues

Notation de Kendall : A/S/c (loi d'arrivée / loi de service / nombre de serveurs). Modèle de base retenu pour une NF à instance unique : M/M/1 — arrivées de Poisson (paramètre λ), temps de service exponentiel (paramètre µ), 1 serveur.

|                |                                      |                                                                             |
|----------------|--------------------------------------|-----------------------------------------------------------------------------|
| **Paramètre**  | **Formule (M/M/1)**                  | **Signification**                                                           |
| ρ (occupation) | ρ = λ / µ                            | Fraction du temps où la NF est occupée. Condition de stabilité : ρ \< 1.    |
| L              | L = ρ / (1 − ρ)                      | Nombre moyen de requêtes dans le système (attente + service).               |
| W              | W = 1 / (µ − λ)                      | Temps moyen passé dans le système par requête (Loi de Little : L = λW).     |
| Lq, Wq         | Lq = ρ² / (1 − ρ) ; Wq = ρ / (µ − λ) | Mêmes rôles que L et W , uniquement pour la part en attente (hors service). |

Extension multi-instances (scale-out) — modèle M/M/c :

*ρ = λ / (c · µ)*

Faire varier c dans le modèle revient à simuler un scale-out (ajout d'instances en parallèle) plutôt qu'un scale-up (plus de ressources sur une seule instance). C'est le paramètre directement pilotable par le VIM/K8s en Phase 3–4.

## 5. Hypothèse de Poisson — validité et limites

Le modèle M/M/1/M/M/c suppose des arrivées indépendantes et sans mémoire (loi exponentielle des inter-arrivées). Cette hypothèse est :

- Raisonnable en testbed contrôlé : le script de génération de charge (UERANSIM) peut être conçu pour produire des inter-arrivées tirées d'une loi exponentielle de paramètre λ, garantissant un processus de Poisson par construction.

- Potentiellement violée en conditions réelles lors d'événements corrélés (ex. reprise après coupure de courant, « mass registration ») : les arrivées cessent d'être indépendantes, le modèle sous-estime alors le pic réel de charge.

Implication méthodologique : valider d'abord le modèle en régime nominal (charge poissonnienne contrôlée), puis documenter explicitement, en section « limites » du rapport, les régimes de charge où l'hypothèse cesse d'être réaliste.

## 6. Exemple numérique de référence (AMF, c=1)

Avec λ = 45 req/s et µ = 50 req/s :

- ρ = 45/50 = 0,9 → marge de sécurité faible (10 %).

- L = 0,9/0,1 = 9 requêtes en moyenne dans le système.

- W = 1/(50−45) = 0,2 s = 200 ms, soit 10× le temps de service pur (1/µ = 20 ms) — l'essentiel du délai vient de l'attente, pas du traitement.

- Avec c=2 : ρ = 45/(2×50) = 0,45 → marge largement restaurée, W chute fortement.

Comportement non linéaire à retenir : au voisinage de ρ=1, une faible variation de λ provoque une explosion de W (ex. λ=48 → ρ=0,96 → W≈500 ms). C'est ce comportement qui justifiera une règle de dimensionnement visant une marge (ρ cible typiquement \< 0,7–0,8) plutôt qu'un dimensionnement au plus juste.

*Document établi au J5–J6 — base de travail pour le tableau comparatif des outils (J7) et pour le modèle de dimensionnement de la Phase 4.*
