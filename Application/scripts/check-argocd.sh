#!/usr/bin/env bash
# Script de vérification de l'installation d'Argo CD
# Usage : ./check-argocd.sh
# Ce script vérifie la présence du namespace argocd, des pods, services et applications associés, et affiche le mot de passe admin initial.
# Auteur : Valheriane
# Date : 2024-06
#!/usr/bin/env bash
set -u

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
BOLD="\033[1m"
NC="\033[0m"

OK_COUNT=0
WARN_COUNT=0
ERR_COUNT=0

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; OK_COUNT=$((OK_COUNT+1)); }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; WARN_COUNT=$((WARN_COUNT+1)); }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; ERR_COUNT=$((ERR_COUNT+1)); }

section() {
  echo
  echo -e "${BOLD}==================================================${NC}"
  echo -e "${BOLD}$1${NC}"
  echo -e "${BOLD}==================================================${NC}"
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

section "1. Vérification des outils"

for cmd in kubectl base64; do
  if check_cmd "$cmd"; then
    log_ok "$cmd est installé"
  else
    log_error "$cmd est introuvable"
  fi
done

section "2. Vérification du namespace et des services"

if kubectl get ns argocd >/dev/null 2>&1; then
  log_ok "Namespace argocd présent"
else
  log_error "Namespace argocd absent"
fi

if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
  log_ok "Service argocd-server présent"
else
  log_error "Service argocd-server absent"
fi

section "3. Pods Argo CD"
kubectl get pods -n argocd || true

section "4. Applications Argo CD"
if kubectl get applications -n argocd >/dev/null 2>&1; then
  log_ok "Applications Argo CD accessibles"
  kubectl get applications -n argocd
else
  log_warn "Impossible de lire les Applications Argo CD"
fi

section "5. Mot de passe admin"
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  PASSWORD="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
  log_ok "Utilisateur : admin"
  log_ok "Mot de passe : ${PASSWORD}"
else
  log_warn "Secret argocd-initial-admin-secret introuvable"
fi

section "6. Résumé"

echo -e "${GREEN}OK    : $OK_COUNT${NC}"
echo -e "${YELLOW}WARN  : $WARN_COUNT${NC}"
echo -e "${RED}ERROR : $ERR_COUNT${NC}"

echo
echo "URL conseillée : https://localhost:8081"

if [[ $ERR_COUNT -gt 0 ]]; then
  echo -e "${RED}Bilan : Argo CD à corriger.${NC}"
  exit 1
elif [[ $WARN_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}Bilan : Argo CD globalement fonctionnel, avec quelques points à surveiller.${NC}"
  exit 0
else
  echo -e "${GREEN}Bilan : Argo CD prêt.${NC}"
  exit 0
fi