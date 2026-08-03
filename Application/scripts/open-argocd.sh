#!/usr/bin/env bash
# Script d'ouverture de l'interface web d'Argo CD en local
# Usage : ./open-argocd.sh [PORT]
# Par défaut, le port local utilisé est 8081, mais vous pouvez spécifier un
# autre port en argument, par exemple : ./open-argocd.sh 8090
# Auteur : Valheriane
# Date : 2024-06

#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${1:-8081}"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

port_in_use() {
  ss -ltn "( sport = :${LOCAL_PORT} )" 2>/dev/null | grep -q ":${LOCAL_PORT}"
}

open_browser() {
  local url="$1"

  if check_cmd xdg-open; then
    xdg-open "$url" >/dev/null 2>&1 &
    return 0
  fi

  if check_cmd sensible-browser; then
    sensible-browser "$url" >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

echo "=================================================="
echo " Ouverture de l'interface Argo CD"
echo "=================================================="

for cmd in kubectl base64 ss; do
  if check_cmd "$cmd"; then
    log_ok "$cmd est installé"
  else
    log_error "$cmd est introuvable"
    exit 1
  fi
done

if ! kubectl get ns argocd >/dev/null 2>&1; then
  log_error "Le namespace argocd n'existe pas"
  exit 1
fi

if ! kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
  log_error "Le service argocd-server est introuvable"
  exit 1
fi

if port_in_use; then
  log_error "Le port local ${LOCAL_PORT} est déjà utilisé"
  echo "Relance avec un autre port, par exemple :"
  echo "./scripts/open-argocd.sh 8090"
  exit 1
fi

log_info "Récupération du mot de passe admin..."
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
  log_ok "Utilisateur : admin"
  log_ok "Mot de passe : ${PASSWORD}"
else
  log_warn "Impossible de récupérer argocd-initial-admin-secret"
fi

URL="https://localhost:${LOCAL_PORT}"

echo
log_info "URL Argo CD : ${URL}"
log_warn "Le navigateur peut signaler un certificat non reconnu : c'est normal en local."
echo

if open_browser "$URL"; then
  log_ok "Tentative d'ouverture du navigateur effectuée"
else
  log_warn "Impossible d'ouvrir automatiquement le navigateur"
  log_info "Ouvre manuellement : ${URL}"
fi

echo
log_info "Lancement du port-forward..."
kubectl port-forward svc/argocd-server "${LOCAL_PORT}:443" -n argocd