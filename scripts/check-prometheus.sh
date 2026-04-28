#!/usr/bin/env bash
# Script de vérification de Prometheus
# Ce script vérifie la présence et l'état de Prometheus dans le namespace monitoring. Il
# affiche les pods et services de Prometheus, ainsi que le résultat d'un test de readiness en utilisant un pod temporaire avec l'image curl.
# Usage : ./scripts/check-prometheus.sh
# Note : Assurez-vous d'avoir les outils kubectl installés et configurés avant d'exécuter ce script.
# Author : [Votre Nom]*

set -e

echo "=== Pods Prometheus ==="
kubectl get pods -n monitoring | grep prometheus || true

echo
echo "=== Services Prometheus ==="
kubectl get svc -n monitoring | grep prometheus || true

echo
echo "=== Test readiness Prometheus ==="
kubectl run curl-prom-test \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl:8.7.1 \
  -n monitoring \
  -- curl -s http://monitoring-kube-prometheus-prometheus.monitoring:9090/-/ready || true