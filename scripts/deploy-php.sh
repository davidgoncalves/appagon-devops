#!/usr/bin/env bash

set -Eeuo pipefail

CONFIG_FILE="${1:-}"

if [[ -z "${CONFIG_FILE}" ]]; then
    echo "Erreur : aucun fichier de configuration fourni."
    exit 1
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Erreur : fichier de configuration introuvable : ${CONFIG_FILE}"
    exit 1
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
        echo "Erreur : variable manquante dans la configuration : ${variable}"
        exit 1
    fi
done

if [[ ! -d "${LOCAL_REPO}/.git" ]]; then
    echo "Erreur : ${LOCAL_REPO} n'est pas un dépôt Git."
    exit 1
fi

echo
echo "Déploiement de ${APP_DISPLAY_NAME}"
echo "----------------------------------------"

echo "1. Vérification du dépôt local..."

if ! git -C "${LOCAL_REPO}" diff --quiet; then
    echo "Erreur : des modifications locales non indexées existent."
    echo "Committe-les ou annule-les avant le déploiement."
    exit 1
fi

if ! git -C "${LOCAL_REPO}" diff --cached --quiet; then
    echo "Erreur : des modifications sont indexées mais non committées."
    exit 1
fi

current_branch="$(git -C "${LOCAL_REPO}" branch --show-current)"

if [[ "${current_branch}" != "${BRANCH}" ]]; then
    echo "Erreur : tu es sur la branche ${current_branch}, pas ${BRANCH}."
    exit 1
fi

echo "2. Vérification que le commit local est bien sur GitHub..."

git -C "${LOCAL_REPO}" fetch origin "${BRANCH}" --quiet

local_commit="$(git -C "${LOCAL_REPO}" rev-parse HEAD)"
remote_commit="$(git -C "${LOCAL_REPO}" rev-parse "origin/${BRANCH}")"

if [[ "${local_commit}" != "${remote_commit}" ]]; then
    echo "Erreur : le commit local n'est pas identique à origin/${BRANCH}."
    echo "Fais d'abord :"
    echo
    echo "  git -C \"${LOCAL_REPO}\" push origin ${BRANCH}"
    echo
    exit 1
fi

echo "3. Mise à jour du serveur..."

ssh "${SSH_HOST}" \
    REMOTE_REPO="${REMOTE_REPO}" \
    BRANCH="${BRANCH}" \
    'bash -se' <<'REMOTE_SCRIPT'
set -Eeuo pipefail

cd "${REMOTE_REPO}"

if [[ ! -d ".git" ]]; then
    echo "Erreur : ${REMOTE_REPO} n'est pas un dépôt Git."
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Erreur : le serveur contient des modifications Git non committées."
    git status --short
    exit 1
fi

previous_commit="$(git rev-parse HEAD)"

echo "Commit actuellement déployé : ${previous_commit}"

git fetch origin "${BRANCH}"
git checkout "${BRANCH}"
git pull --ff-only origin "${BRANCH}"

composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --optimize-autoloader

new_commit="$(git rev-parse HEAD)"

echo "Nouveau commit déployé : ${new_commit}"
REMOTE_SCRIPT

if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
    echo "4. Vérification HTTP..."

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
        echo "Erreur : le health check retourne HTTP ${http_code}."
        exit 1
    fi

    echo "Health check réussi : HTTP ${http_code}"
fi

echo
echo "Déploiement terminé avec succès."
