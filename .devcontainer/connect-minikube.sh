#!/usr/bin/env bash

set -Eeuo pipefail

PROFILE="${MINIKUBE_PROFILE:-machina}"
STRICT="${CONNECT_MINIKUBE_STRICT:-0}"

KUBE_DIR="${HOME}/.kube"
KUBE_CONFIG="${KUBE_DIR}/config"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

log_info() {
  echo -e "${BLUE}[MINIKUBE]${NC} $1"
}

log_ok() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

stop_or_skip() {
  local message="$1"

  if [[ "$STRICT" == "1" ]]; then
    log_error "$message"
    exit 1
  fi

  log_warn "$message"
  log_warn "Le Dev Container reste utilisable sans Kubernetes."
  exit 0
}

check_command() {
  command -v "$1" >/dev/null 2>&1
}

log_info "Connexion au cluster Kubernetes '${PROFILE}'..."

for command_name in docker kubectl; do
  if ! check_command "$command_name"; then
    stop_or_skip "Commande introuvable : ${command_name}"
  fi
done

# Le cluster Minikube doit avoir été créé sur la machine hôte.
if ! docker inspect "$PROFILE" >/dev/null 2>&1; then
  stop_or_skip \
    "Le conteneur Minikube '${PROFILE}' est absent. Démarre-le depuis le terminal local avec : minikube start -p ${PROFILE} --driver=docker"
fi

MINIKUBE_RUNNING="$(
  docker inspect \
    --format '{{.State.Running}}' \
    "$PROFILE" 2>/dev/null || true
)"

if [[ "$MINIKUBE_RUNNING" != "true" ]]; then
  stop_or_skip \
    "Le cluster '${PROFILE}' existe, mais son conteneur n'est pas démarré. Lance depuis le terminal local : minikube start -p ${PROFILE}"
fi

DEV_CONTAINER_ID="$(hostname)"

MINIKUBE_NETWORK="$(
  docker inspect "$PROFILE" \
    --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' \
    | head -n 1
)"

MINIKUBE_IP="$(
  docker inspect "$PROFILE" \
    --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
    | head -n 1
)"

if [[ -z "$MINIKUBE_NETWORK" ]]; then
  stop_or_skip "Impossible de déterminer le réseau Docker de '${PROFILE}'."
fi

if [[ -z "$MINIKUBE_IP" ]]; then
  stop_or_skip "Impossible de déterminer l'adresse IP de '${PROFILE}'."
fi

log_info "Réseau détecté : ${MINIKUBE_NETWORK}"
log_info "Adresse détectée : ${MINIKUBE_IP}"

# Un conteneur Docker peut appartenir à plusieurs réseaux.
# On ne reconnecte pas le Dev Container s'il est déjà présent.
if docker inspect "$DEV_CONTAINER_ID" \
  --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' \
  | grep -Fxq "$MINIKUBE_NETWORK"; then

  log_info "Dev Container déjà connecté au réseau '${MINIKUBE_NETWORK}'."
else
  log_info "Connexion du Dev Container au réseau '${MINIKUBE_NETWORK}'..."

  docker network connect \
    "$MINIKUBE_NETWORK" \
    "$DEV_CONTAINER_ID"

  log_ok "Dev Container connecté au réseau Minikube."
fi

# Récupération d'un kubeconfig administrateur depuis le control plane.
mkdir -p "$KUBE_DIR"

TEMP_KUBECONFIG="$(mktemp)"
trap 'rm -f "$TEMP_KUBECONFIG"' EXIT

umask 077

if ! docker exec "$PROFILE" \
  cat /etc/kubernetes/admin.conf \
  > "$TEMP_KUBECONFIG"; then

  stop_or_skip "Impossible de récupérer le kubeconfig depuis '${PROFILE}'."
fi

install \
  -m 600 \
  "$TEMP_KUBECONFIG" \
  "$KUBE_CONFIG"

export KUBECONFIG="$KUBE_CONFIG"

CLUSTER_NAME="$(
  kubectl config view \
    --kubeconfig "$KUBE_CONFIG" \
    --minify \
    -o jsonpath='{.clusters[0].name}'
)"

if [[ -z "$CLUSTER_NAME" ]]; then
  stop_or_skip "Aucun cluster trouvé dans le kubeconfig récupéré."
fi

# L'admin.conf utilise un nom DNS interne inaccessible depuis le Dev Container.
# On utilise donc l'IP réelle pour la connexion, tout en conservant le nom TLS.
kubectl config \
  --kubeconfig "$KUBE_CONFIG" \
  set-cluster "$CLUSTER_NAME" \
  --server="https://${MINIKUBE_IP}:8443" \
  --tls-server-name="control-plane.minikube.internal" \
  >/dev/null

CURRENT_CONTEXT="$(
  kubectl config \
    --kubeconfig "$KUBE_CONFIG" \
    current-context
)"

if [[ "$CURRENT_CONTEXT" != "$PROFILE" ]]; then
  if kubectl config \
    --kubeconfig "$KUBE_CONFIG" \
    get-contexts -o name \
    | grep -Fxq "$PROFILE"; then

    kubectl config \
      --kubeconfig "$KUBE_CONFIG" \
      use-context "$PROFILE" \
      >/dev/null
  else
    kubectl config \
      --kubeconfig "$KUBE_CONFIG" \
      rename-context "$CURRENT_CONTEXT" "$PROFILE" \
      >/dev/null
  fi
fi

if ! kubectl \
  --kubeconfig "$KUBE_CONFIG" \
  --request-timeout=10s \
  get nodes \
  >/dev/null 2>&1; then

  stop_or_skip \
    "Le kubeconfig a été préparé, mais le cluster '${PROFILE}' ne répond pas."
fi

SERVER="$(
  kubectl config \
    --kubeconfig "$KUBE_CONFIG" \
    view \
    --minify \
    -o jsonpath='{.clusters[0].cluster.server}'
)"

log_ok "Connexion Kubernetes opérationnelle."
echo "  Contexte : $(kubectl config current-context)"
echo "  Serveur  : ${SERVER}"