#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/output.sh
source "${SCRIPT_DIR}/lib/output.sh"

trap deploy_finish EXIT

CONFIG_FILE="${1:-}"

if [[ -z "${CONFIG_FILE}" ]]; then
    fail "aucun fichier de configuration fourni."
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    fail "fichier de configuration introuvable : ${CONFIG_FILE}"
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

required_variables=(
    APP_SLUG
    APP_DISPLAY_NAME
    LOCAL_REPO
    SSH_HOST
    REMOTE_REPO
    BRANCH
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        fail "variable manquante dans la configuration : ${variable}"
    fi
done

if [[ ! -d "${LOCAL_REPO}/.git" ]]; then
    fail "${LOCAL_REPO} n'est pas un dépôt Git."
fi

printf '\n%s\n' "${C_BLUE}Déploiement de ${APP_DISPLAY_NAME}${C_RESET}"

step "1. Vérification du dépôt local..."

if ! git -C "${LOCAL_REPO}" diff --quiet; then
    fail "des modifications locales non indexées existent. Committe-les ou annule-les avant le déploiement."
fi

if ! git -C "${LOCAL_REPO}" diff --cached --quiet; then
    fail "des modifications sont indexées mais non committées."
fi

current_branch="$(git -C "${LOCAL_REPO}" branch --show-current)"

if [[ "${current_branch}" != "${BRANCH}" ]]; then
    fail "tu es sur la branche ${current_branch}, pas ${BRANCH}."
fi

ok "dépôt local propre sur ${BRANCH}"

step "2. Vérification que le commit local est bien sur GitHub..."

git -C "${LOCAL_REPO}" fetch origin "${BRANCH}" --quiet

local_commit="$(git -C "${LOCAL_REPO}" rev-parse HEAD)"
remote_commit="$(git -C "${LOCAL_REPO}" rev-parse "origin/${BRANCH}")"

if [[ "${local_commit}" != "${remote_commit}" ]]; then
    warn "le commit local n'est pas identique à origin/${BRANCH}."
    fail "fais d'abord : git -C \"${LOCAL_REPO}\" push origin ${BRANCH}"
fi

ok "commit ${local_commit:0:8} présent sur origin/${BRANCH}"

step "3. Mise à jour du serveur..."

ssh "${SSH_HOST}" \
    REMOTE_REPO="${REMOTE_REPO}" \
    BRANCH="${BRANCH}" \
    USE_COLOR="${USE_COLOR}" \
    'bash -se' <<'REMOTE_SCRIPT'
set -Eeuo pipefail

if [[ "${USE_COLOR:-0}" == "1" ]]; then
    R_RESET=$'\033[0m'
    R_RED=$'\033[1;31m'
    R_GREEN=$'\033[1;32m'
    R_DIM=$'\033[2m'
else
    R_RESET=''
    R_RED=''
    R_GREEN=''
    R_DIM=''
fi

cd "${REMOTE_REPO}"

if [[ ! -d ".git" ]]; then
    printf '%s\n' "    ${R_RED}x  ${REMOTE_REPO} n'est pas un dépôt Git.${R_RESET}" >&2
    exit 1
fi

# Ignore les fichiers non suivis (.env, logs/, static/…) : seuls les fichiers
# suivis peuvent bloquer un git pull --ff-only.
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    printf '%s\n' "    ${R_RED}x  le serveur contient des modifications Git non committées.${R_RESET}" >&2
    git status --short --untracked-files=no
    exit 1
fi

previous_commit="$(git rev-parse HEAD)"

printf '%s\n' "    ${R_DIM}commit actuellement déployé : ${previous_commit:0:8}${R_RESET}"

git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git pull --ff-only origin "${BRANCH}"

# shellcheck disable=SC1091
source env/bin/activate
pip install -r requirements.txt

new_commit="$(git rev-parse HEAD)"

printf '%s\n' "    ${R_GREEN}ok${R_RESET} ${R_DIM}nouveau commit déployé : ${new_commit:0:8}${R_RESET}"
REMOTE_SCRIPT

if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
    step "4. Vérification HTTP..."

    http_code="$(
        curl \
            --silent \
            --show-error \
            --location \
            --output /dev/null \
            --write-out "%{http_code}" \
            --max-time 20 \
            "${HEALTHCHECK_URL}"
    )"

    if [[ "${http_code}" -lt 200 || "${http_code}" -ge 400 ]]; then
        fail "health check HTTP ${http_code} sur ${HEALTHCHECK_URL}"
    fi

    ok "health check HTTP ${http_code}"
fi

deploy_succeeded=1

warn "Redémarre l'application dans le panneau Alwaysdata si le code Python a changé."
