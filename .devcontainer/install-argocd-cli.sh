#!/usr/bin/env bash

set -Eeuo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.5.1}"

GREEN="\033[0;32m"
BLUE="\033[0;34m"
RED="\033[0;31m"
NC="\033[0m"

log_info() {
  echo -e "${BLUE}[ARGOCD-CLI]${NC} $1"
}

log_ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

current_version() {
  argocd version --client 2>/dev/null \
    | awk '/^argocd:/ {split($2, version, "+"); print version[1]; exit}'
}

if command -v argocd >/dev/null 2>&1; then
  INSTALLED_VERSION="$(current_version || true)"

  if [[ "$INSTALLED_VERSION" == "$ARGOCD_VERSION" ]]; then
    log_ok "Argo CD CLI ${ARGOCD_VERSION} déjà installé"
    exit 0
  fi

  log_info "Version présente : ${INSTALLED_VERSION:-inconnue}"
fi

case "$(uname -m)" in
  x86_64)
    ARGOCD_ARCH="amd64"
    ;;
  aarch64|arm64)
    ARGOCD_ARCH="arm64"
    ;;
  *)
    log_error "Architecture non prise en charge : $(uname -m)"
    exit 1
    ;;
esac

ARGOCD_BINARY="argocd-linux-${ARGOCD_ARCH}"
ARGOCD_BASE_URL="https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log_info "Téléchargement de Argo CD CLI ${ARGOCD_VERSION} (${ARGOCD_ARCH})..."

curl -fsSL \
  "${ARGOCD_BASE_URL}/${ARGOCD_BINARY}" \
  -o "${TMP_DIR}/${ARGOCD_BINARY}"

curl -fsSL \
  "${ARGOCD_BASE_URL}/cli_checksums.txt" \
  -o "${TMP_DIR}/cli_checksums.txt"

log_info "Vérification SHA256..."

(
  cd "$TMP_DIR"
  grep "  ${ARGOCD_BINARY}$" cli_checksums.txt \
    | sha256sum --check -
)

log_info "Installation dans /usr/local/bin/argocd..."

sudo install -m 555 \
  "${TMP_DIR}/${ARGOCD_BINARY}" \
  /usr/local/bin/argocd

INSTALLED_VERSION="$(current_version)"

if [[ "$INSTALLED_VERSION" != "$ARGOCD_VERSION" ]]; then
  log_error "Version installée inattendue : ${INSTALLED_VERSION}"
  exit 1
fi

log_ok "Argo CD CLI ${INSTALLED_VERSION} installé"
