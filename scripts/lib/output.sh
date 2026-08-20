#!/usr/bin/env bash

# Sortie colorée partagée par ./deploy et les scripts de déploiement.
#
# Les couleurs ne sont actives que sur un vrai terminal : redirigée vers un
# fichier ou lue par un terminal sans capacités (TERM=dumb), la sortie reste du
# texte brut. NO_COLOR=1 les désactive à la main.

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[1;31m'
    C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'
    C_DIM=$'\033[2m'
else
    C_RESET=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_DIM=''
fi

# Le script distant tourne sans TTY et ne peut donc pas détecter les couleurs
# lui-même : cette valeur lui est transmise explicitement via ssh.
if [[ -n "${C_RED}" ]]; then
    USE_COLOR=1
else
    USE_COLOR=0
fi

step() { printf '\n%s\n' "${C_BLUE}==>${C_RESET} $*"; }
ok()   { printf '%s\n'   "    ${C_GREEN}ok${C_RESET} ${C_DIM}$*${C_RESET}"; }
warn() { printf '%s\n'   "    ${C_YELLOW}!  $*${C_RESET}" >&2; }
fail() { printf '%s\n'   "    ${C_RED}x  $*${C_RESET}" >&2; exit 1; }

# Bannière finale unique, verte ou rouge, quelle que soit la façon dont le
# script se termine — y compris quand ssh, git ou curl meurt en cours de route.
# Les scripts de déploiement posent `trap deploy_finish EXIT` puis passent
# deploy_succeeded à 1 juste avant de rendre la main.
deploy_succeeded=0

deploy_finish() {
    local code=$?

    printf '\n'

    if (( code == 0 )) && (( deploy_succeeded == 1 )); then
        printf '%s\n' "${C_GREEN}✔ ${APP_DISPLAY_NAME:-Application} déployé avec succès${C_RESET}"
    else
        printf '%s\n' "${C_RED}✖ ÉCHEC du déploiement${C_RESET}${C_DIM} — ${APP_DISPLAY_NAME:-application} (code ${code})${C_RESET}"
    fi
}
