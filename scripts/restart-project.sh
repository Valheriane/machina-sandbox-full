#!/usr/bin/env bash
set -u

# =========================
# Couleurs
# =========================
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =========================
# Vérifs outils
# =========================
check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

echo "=================================================="
echo " Relance de l'environnement Machina"
echo "=================================================="

for cmd in minikube kubectl helm docker; do
  if check_cmd "$cmd"; then
    log_ok "$cmd est installé"
  else
    log_error "$cmd est introuvable"
    exit 1
  fi
done

echo
log_info "Démarrage de Minikube..."
if minikube start; then
  log_ok "Minikube est démarré"
else
  log_error "Impossible de démarrer Minikube"
  exit 1
fi

echo
log_info "Vérification du cluster..."
if kubectl cluster-info >/dev/null 2>&1; then
  log_ok "Cluster Kubernetes joignable"
else
  log_error "Cluster Kubernetes non joignable"
  exit 1
fi

echo
log_info "Nœuds Kubernetes"
kubectl get nodes -o wide

echo
log_info "Namespaces"
kubectl get ns

echo
log_info "Releases Helm"
helm list -A

echo
log_info "Pods monitoring"
kubectl get pods -n monitoring

echo
log_info "Services monitoring"
kubectl get svc -n monitoring

echo
log_info "Pods applicatifs"
kubectl get pods -n machina-sandbox || true
kubectl get pods -n machina-helm-test || true

echo
log_info "Mot de passe Grafana"
if kubectl get secret -n monitoring monitoring-grafana >/dev/null 2>&1; then
  kubectl get secret -n monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 -d
  echo
  log_ok "Mot de passe Grafana affiché"
else
  log_warn "Secret Grafana introuvable"
fi

echo
echo "=================================================="
echo " Relance terminée"
echo "=================================================="
echo -e "${GREEN}Grafana :${NC} http://localhost:3000"
echo -e "${GREEN}Prometheus DS :${NC} http://monitoring-kube-prometheus-prometheus.monitoring:9090"
echo -e "${GREEN}Loki DS :${NC} http://loki.monitoring.svc.cluster.local:3100"
echo
echo "Pour ouvrir Grafana :"
echo "kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring"