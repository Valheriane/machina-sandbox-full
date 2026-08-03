#!/usr/bin/env bash
set -u

# =========================
# Couleurs
# =========================
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

check_namespace() {
  local ns="$1"
  if kubectl get ns "$ns" >/dev/null 2>&1; then
    log_ok "Namespace '$ns' présent"
  else
    log_error "Namespace '$ns' absent"
  fi
}

check_release() {
  local release="$1"
  local ns="$2"
  if helm status "$release" -n "$ns" >/dev/null 2>&1; then
    local status
    status=$(helm status "$release" -n "$ns" 2>/dev/null | awk -F': ' '/^STATUS:/ {print $2}')
    if [[ "$status" == "deployed" ]]; then
      log_ok "Release Helm '$release' dans '$ns' : deployed"
    else
      log_warn "Release Helm '$release' dans '$ns' : $status"
    fi
  else
    log_error "Release Helm '$release' absente dans '$ns'"
  fi
}

check_pods_by_keyword() {
  local ns="$1"
  local keyword="$2"
  local rows
  rows=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | grep "$keyword" || true)

  if [[ -z "$rows" ]]; then
    log_warn "Aucun pod '$keyword' trouvé dans '$ns'"
    return
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local name ready status restarts age
    name=$(echo "$line" | awk '{print $1}')
    ready=$(echo "$line" | awk '{print $2}')
    status=$(echo "$line" | awk '{print $3}')
    restarts=$(echo "$line" | awk '{print $4}')
    age=$(echo "$line" | awk '{print $5}')

    if [[ "$status" == "Running" || "$status" == "Completed" ]]; then
      log_ok "Pod $name [$ready] status=$status restarts=$restarts age=$age"
    elif [[ "$status" == "Pending" || "$status" == "ContainerCreating" || "$status" == "Init:0/1" ]]; then
      log_warn "Pod $name [$ready] status=$status restarts=$restarts age=$age"
    else
      log_error "Pod $name [$ready] status=$status restarts=$restarts age=$age"
    fi
  done <<< "$rows"
}

check_service() {
  local ns="$1"
  local svc="$2"
  if kubectl get svc "$svc" -n "$ns" >/dev/null 2>&1; then
    local ports
    ports=$(kubectl get svc "$svc" -n "$ns" -o jsonpath='{.spec.ports[*].port}')
    log_ok "Service '$svc' présent dans '$ns' (ports: $ports)"
  else
    log_error "Service '$svc' absent dans '$ns'"
  fi
}

section "1. Vérification des outils"

for cmd in minikube kubectl helm docker; do
  if check_cmd "$cmd"; then
    log_ok "$cmd est installé"
  else
    log_error "$cmd est introuvable"
  fi
done

section "2. État Minikube / Kubernetes"

if minikube status >/dev/null 2>&1; then
  log_ok "Minikube répond"
else
  log_error "Minikube ne répond pas"
fi

if kubectl cluster-info >/dev/null 2>&1; then
  log_ok "Cluster Kubernetes joignable"
else
  log_error "Cluster Kubernetes non joignable"
fi

echo
kubectl config current-context 2>/dev/null || true
kubectl get nodes -o wide 2>/dev/null || true

section "3. Namespaces attendus"

check_namespace "argocd"
check_namespace "monitoring"
check_namespace "machina-sandbox"
check_namespace "machina-helm-test"

section "4. Releases Helm"

check_release "monitoring" "monitoring"
check_release "loki" "monitoring"
check_release "machina-test" "machina-helm-test"

echo
helm list -A 2>/dev/null || true

section "5. Monitoring stack"

check_pods_by_keyword "monitoring" "grafana"
check_pods_by_keyword "monitoring" "prometheus"
check_pods_by_keyword "monitoring" "alertmanager"
check_pods_by_keyword "monitoring" "loki"

echo
check_service "monitoring" "monitoring-grafana"
check_service "monitoring" "monitoring-kube-prometheus-prometheus"
check_service "monitoring" "loki"

section "6. Applications métier"

check_pods_by_keyword "machina-sandbox" "broker"
check_pods_by_keyword "machina-sandbox" "fleet-api"
check_pods_by_keyword "machina-sandbox" "front"

check_pods_by_keyword "machina-helm-test" "broker"
check_pods_by_keyword "machina-helm-test" "fleet-api"
check_pods_by_keyword "machina-helm-test" "front"

section "7. Argo CD"

if kubectl get applications -n argocd >/dev/null 2>&1; then
  log_ok "Applications Argo CD accessibles"
  kubectl get applications -n argocd
else
  log_warn "Impossible de lire les Applications Argo CD"
fi

section "8. Docker"

if docker ps >/dev/null 2>&1; then
  log_ok "Docker répond"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
else
  log_error "Docker ne répond pas"
fi

section "9. Résumé"

echo -e "${GREEN}OK    : $OK_COUNT${NC}"
echo -e "${YELLOW}WARN  : $WARN_COUNT${NC}"
echo -e "${RED}ERROR : $ERR_COUNT${NC}"

echo
echo "URLs utiles :"
echo "  Grafana     : http://localhost:3000"
echo "  Prometheus  : http://monitoring-kube-prometheus-prometheus.monitoring:9090"
echo "  Loki        : http://loki.monitoring.svc.cluster.local:3100"

echo
if [[ $ERR_COUNT -gt 0 ]]; then
  echo -e "${RED}Bilan : environnement à corriger.${NC}"
  exit 1
elif [[ $WARN_COUNT -gt 0 ]]; then
  echo -e "${YELLOW}Bilan : environnement globalement fonctionnel, avec quelques points à surveiller.${NC}"
  exit 0
else
  echo -e "${GREEN}Bilan : environnement prêt.${NC}"
  exit 0
fi