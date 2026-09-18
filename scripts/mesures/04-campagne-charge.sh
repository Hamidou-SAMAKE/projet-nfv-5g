#!/usr/bin/env bash
# scripts/mesures/04-campagne-charge.sh
#
# Exécute une campagne de charge à plusieurs niveaux successifs (ex. 1, 3, 5,
# 10 UE), répétés plusieurs fois chacun, pour construire la courbe complète
# dont le modèle de files d'attente a besoin (cf.
# docs/architecture/modele-files-attente.md, §5 : faire croître λ
# progressivement jusqu'à observer la saturation) et fournir plusieurs
# mesures par point pour l'analyse statistique des écarts prévue en J26
# (cf. docs/planning/plan-detaille-taches-A-B.md, Phase 4).
#
# Pour chaque (niveau, répétition) : nettoie les UE précédents, lance
# exactement N UE en un seul palier, laisse les sessions se stabiliser,
# génère du trafic iperf3, archive les résultats, calcule un résumé chiffré
# immédiat (débit agrégé/moyen, taux de réussite) et enregistre la fenêtre
# temporelle exacte (UTC, ISO 8601) du run.
#
# Ce script ne touche PAS à Prometheus : c'est cette fenêtre temporelle qui
# permet à l'Étudiant B d'interroger Prometheus après coup sur la bonne
# période et d'en extraire CPU/RAM/latence par NF pour calibrer µ (§5/§7 du
# modèle) — répartition des rôles J24-25 du plan.
#
# Paramètres :
#   NIVEAUX           niveaux de charge à tester, séparés par des espaces
#                      (défaut : "1 3 5 10")
#   REPETITIONS        répétitions par niveau (défaut : 3)
#   TARGET_IP          cible iperf3. Par défaut, 10.45.0.1 : l'interface
#                       ogstun de l'UPF elle-même (cf.
#                       scripts/mesures/serveur-iperf3-local.sh), pour
#                       mesurer la capacité réelle de l'UPF sans la
#                       contrainte du lien Tailscale (~14-18 Mbit/s réels,
#                       cf. docs/cadrage/calibration-tailscale.md — sinon
#                       c'est ce lien, pas l'UPF, qui saturerait en premier
#                       et fausserait la calibration de µ).
#                       Mettre TARGET_IP=100.82.162.11 pour cibler la
#                       Machine B via Tailscale à la place.
#   DUREE               durée iperf3 par run, en secondes (défaut : 20)
#   STABILISATION       délai (s) laissé aux sessions PDU pour s'établir
#                       avant de lancer le trafic (défaut : 10)
#   PAUSE_ENTRE_RUNS    délai (s) entre deux runs, pour repartir d'un état
#                       stable (défaut : 10)
#
# Usage :
#   bash scripts/mesures/04-campagne-charge.sh
#   NIVEAUX="1 2 5 10 15" REPETITIONS=5 DUREE=15 bash scripts/mesures/04-campagne-charge.sh
#
# Prérequis (cible par défaut) : scripts/mesures/serveur-iperf3-local.sh
# déjà lancé (serveurs iperf3 dans le netns de l'UPF). Si TARGET_IP est
# surchargé vers la Machine B, un serveur iperf3 doit y tourner à la place.
#
# Sortie : modele/donnees/raw/campagne-<horodatage>/
#   niveau-N-rep-K/          sortie brute de 03 (iperf3-uesimtunX.json)
#   resume.csv               une ligne par run : niveau, répétition, fenêtre
#                             temporelle, débit agrégé/moyen, taux de réussite

set -euo pipefail

NIVEAUX="${NIVEAUX:-1 3 5 10}"
REPETITIONS="${REPETITIONS:-3}"
TARGET_IP="${TARGET_IP:-10.45.0.1}"
DUREE="${DUREE:-20}"
STABILISATION="${STABILISATION:-10}"
PAUSE_ENTRE_RUNS="${PAUSE_ENTRE_RUNS:-10}"

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RAW_DIR="${PROJECT_ROOT}/modele/donnees/raw"
CAMPAGNE_DIR="${RAW_DIR}/campagne-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${CAMPAGNE_DIR}"

MAX_NIVEAU=0
for n in ${NIVEAUX}; do
  if [ "$n" -gt "$MAX_NIVEAU" ]; then MAX_NIVEAU=$n; fi
done
# Garde-fou : si la cible est l'UPF locale, vérifie que les serveurs iperf3
# écoutent RÉELLEMENT dans le netns actuel du conteneur upf (ports
# BASE_PORT .. BASE_PORT+MAX_NIVEAU-1). Évite de lancer une campagne entière
# de runs vides (Connection refused) si les sidecars manquent ou sont
# rattachés à un ancien netns après un redémarrage de upf.
if [ "${TARGET_IP}" = "10.45.0.1" ]; then
  BASE_PORT="${BASE_PORT:-5201}"
  UPF_PID="$(docker inspect -f '{{.State.Pid}}' upf 2>/dev/null || echo 0)"
  if [ "${UPF_PID}" = "0" ]; then
    echo "ERREUR : le conteneur 'upf' n'est pas démarré."
    exit 1
  fi
  ECOUTE="$(sudo nsenter -t "${UPF_PID}" -n ss -tln 2>/dev/null || true)"
  MANQUANTS=""
  for p in $(seq "${BASE_PORT}" $(( BASE_PORT + MAX_NIVEAU - 1 ))); do
    grep -qE ":${p}\s" <<< "${ECOUTE}" || MANQUANTS="${MANQUANTS} ${p}"
  done
  if [ -n "${MANQUANTS}" ]; then
    echo "ERREUR : aucun serveur iperf3 à l'écoute sur le(s) port(s) :${MANQUANTS}"
    echo "Lancez : NB_PORTS=${MAX_NIVEAU} bash scripts/mesures/serveur-iperf3-local.sh"
    exit 1
  fi
  echo "==> Serveurs iperf3 locaux OK (ports ${BASE_PORT}-$(( BASE_PORT + MAX_NIVEAU - 1 )) à l'écoute dans le netns de l'UPF)"
fi

NB_NIVEAUX=$(echo ${NIVEAUX} | wc -w)
TOTAL_RUNS=$(( NB_NIVEAUX * REPETITIONS ))

echo "==> Campagne : niveaux [${NIVEAUX}] x ${REPETITIONS} répétition(s) = ${TOTAL_RUNS} run(s)"

echo "==> Vérification du nombre d'abonnés (besoin d'au moins ${MAX_NIVEAU})..."
NB_ABONNES="${MAX_NIVEAU}" bash "${PROJECT_ROOT}/scripts/mesures/01-provisionner-abonnes.sh"

RESUME="${CAMPAGNE_DIR}/resume.csv"
echo "niveau_ue,repetition,debut_iso,fin_iso,debit_agrege_mbps,debit_moyen_par_ue_mbps,flux_reussis,flux_total" > "${RESUME}"

trap 'sudo pkill -f nr-ue 2>/dev/null || true' EXIT

run_num=0
for N in ${NIVEAUX}; do
  for REP in $(seq 1 "${REPETITIONS}"); do
    run_num=$(( run_num + 1 ))
    echo ""
    echo "======================================================================"
    echo "==> Run ${run_num}/${TOTAL_RUNS} — niveau ${N} UE, répétition ${REP}/${REPETITIONS}"
    echo "======================================================================"

    echo "--> Nettoyage des UE précédents..."
    sudo pkill -f nr-ue 2>/dev/null || true
    sleep 2

    DEBUT_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    echo "--> Lancement de ${N} UE (palier unique)..."
    NB_UE="${N}" PALIER_TAILLE="${N}" PALIER_DELAI=1 \
      bash "${PROJECT_ROOT}/scripts/mesures/02-scenario-trafic.sh" || \
      echo "    ATTENTION : 02-scenario-trafic.sh a retourné une erreur, ce run sera incomplet."

    echo "--> Stabilisation (${STABILISATION}s)..."
    sleep "${STABILISATION}"

    NB_TUNNELS=$(ip -o -4 addr show | grep -c uesimtun || true)
    echo "--> ${NB_TUNNELS} tunnel(s) actif(s) sur ${N} attendu(s)"

    echo "--> Génération de trafic iperf3 (${DUREE}s)..."
    TARGET_IP="${TARGET_IP}" DUREE="${DUREE}" \
      bash "${PROJECT_ROOT}/scripts/mesures/03-generer-trafic-iperf3.sh" || true

    FIN_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Récupère le dossier de résultats iperf3 le plus récent et l'archive sous ce run
    DERNIER_RUN=$(ls -td "${RAW_DIR}"/run-*/ 2>/dev/null | head -1 || true)
    NIVEAU_DIR="${CAMPAGNE_DIR}/niveau-${N}-rep-${REP}"
    if [ -n "${DERNIER_RUN}" ]; then
      mv "${DERNIER_RUN}" "${NIVEAU_DIR}"
    else
      mkdir -p "${NIVEAU_DIR}"
    fi

    # Résumé chiffré de ce run, ajouté à resume.csv
    python3 - "$NIVEAU_DIR" "$N" "$REP" "$DEBUT_ISO" "$FIN_ISO" "$RESUME" <<'PYEOF'
import json, sys, glob, os

niveau_dir, n, rep, debut, fin, resume_path = sys.argv[1:7]
debits = []
total = 0
for f in glob.glob(os.path.join(niveau_dir, "iperf3-*.json")):
    total += 1
    try:
        d = json.load(open(f))
        debits.append(d["end"]["sum_received"]["bits_per_second"] / 1e6)
    except Exception:
        pass

agrege = sum(debits)
moyen = (agrege / len(debits)) if debits else 0
with open(resume_path, "a") as out:
    out.write(f"{n},{rep},{debut},{fin},{agrege:.2f},{moyen:.2f},{len(debits)},{total}\n")
print(f"    Résumé niveau {n} UE (rép. {rep}) : {len(debits)}/{total} flux réussis, "
      f"débit agrégé {agrege:.2f} Mbit/s, moyen/UE {moyen:.2f} Mbit/s")
PYEOF

    if [ "${run_num}" -lt "${TOTAL_RUNS}" ]; then
      echo "--> Pause avant le run suivant (${PAUSE_ENTRE_RUNS}s)..."
      sleep "${PAUSE_ENTRE_RUNS}"
    fi
  done
done

sudo pkill -f nr-ue 2>/dev/null || true

echo ""
echo "======================================================================"
echo "Campagne terminée. Résultats dans : ${CAMPAGNE_DIR}"
echo "Résumé (aussi la référence temporelle pour les requêtes Prometheus, côté B) :"
echo "  ${RESUME}"
echo "======================================================================"
column -s, -t "${RESUME}"
