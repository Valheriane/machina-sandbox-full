#!/usr/bin/env bash

set -euo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-machina}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-monitoring}"

DASHBOARD_NAME="machina-control-sandbox"
DASHBOARD_FILE="Application/k8s/monitoring/dashboards/machina-control-sandbox.json"
CONFIGMAP_NAME="machina-control-sandbox-dashboard"

echo "=== Provisionnement du dashboard Grafana Machina ==="

test -f "$DASHBOARD_FILE" || {
    echo "ERREUR : dashboard introuvable : $DASHBOARD_FILE"
    exit 1
}

kubectl \
    --context "$KUBE_CONTEXT" \
    create configmap "$CONFIGMAP_NAME" \
    --namespace "$MONITORING_NAMESPACE" \
    --from-file="${DASHBOARD_NAME}.json=${DASHBOARD_FILE}" \
    --dry-run=client \
    --output yaml \
    | kubectl \
        --context "$KUBE_CONTEXT" \
        apply \
        --filename -

kubectl \
    --context "$KUBE_CONTEXT" \
    label configmap "$CONFIGMAP_NAME" \
    --namespace "$MONITORING_NAMESPACE" \
    grafana_dashboard=1 \
    --overwrite

echo "Dashboard provisionné : $DASHBOARD_NAME"