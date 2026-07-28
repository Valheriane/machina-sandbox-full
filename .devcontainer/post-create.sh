#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m"

log_info() {
  echo -e "${BLUE}[DEVCONTAINER]${NC} $1"
}

log_ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

prepare_directory() {
  local directory="$1"

  sudo mkdir -p "$directory"
  sudo chown -R "$(id -u):$(id -g)" "$directory"
}

install_python_dependencies() {
  local service_name="$1"
  local service_directory="$2"

  local requirements_file="${service_directory}/requirements.txt"
  local virtual_environment="${service_directory}/.venv"

  log_info "Installation des dépendances Python de ${service_name}..."

  if [[ ! -f "$requirements_file" ]]; then
    log_error "Fichier introuvable : ${requirements_file}"
    return 1
  fi

  prepare_directory "$virtual_environment"

  if [[ ! -x "${virtual_environment}/bin/python" ]]; then
    log_info "Création de l'environnement virtuel ${virtual_environment}"
    python3 -m venv "$virtual_environment"
  else
    log_info "Environnement virtuel déjà présent"
  fi

  "${virtual_environment}/bin/python" \
    -m pip install \
    --disable-pip-version-check \
    --no-input \
    -r "$requirements_file"

  "${virtual_environment}/bin/python" -m pip check

  log_ok "Dépendances de ${service_name} installées"
}

install_front_dependencies() {
  local front_directory="front"

  log_info "Installation des dépendances du frontend..."

  if [[ ! -f "${front_directory}/package.json" ]]; then
    log_error "Fichier introuvable : ${front_directory}/package.json"
    return 1
  fi

  if [[ ! -f "${front_directory}/package-lock.json" ]]; then
    log_error "Le fichier front/package-lock.json est absent."
    log_error "La création automatique du lockfile est volontairement bloquée."
    log_error "Il faudra exécuter npm install une fois puis versionner package-lock.json."
    return 1
  fi

  prepare_directory "${front_directory}/node_modules"

  (
    cd "$front_directory"
    npm ci --no-audit --no-fund
  )

  log_ok "Dépendances du frontend installées"
}

echo
echo "=================================================="
echo " Préparation du Dev Container MachinaControl"
echo "=================================================="
echo

install_python_dependencies "fleet-api" "fleet-api"
install_python_dependencies "drone" "agents/drone"
install_front_dependencies

echo
echo "=================================================="
log_ok "Dev Container prêt"
echo "=================================================="
echo
echo "Interpréteurs Python :"
echo "  fleet-api    : ${ROOT_DIR}/fleet-api/.venv/bin/python"
echo "  agents/drone : ${ROOT_DIR}/agents/drone/.venv/bin/python"
echo