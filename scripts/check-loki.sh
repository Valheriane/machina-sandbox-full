#!/usr/bin/env bash
# Script de vérification de Loki
# Ce script vérifie la présence et l'état de Loki dans le namespace monitoring. Il affiche
# les pods et services de Loki, ainsi que le résultat d'un test de readiness en utilisant un pod temporaire avec l'image curl.
# Usage : ./scripts/check-loki.sh
# Note : Assurez-vous d'avoir les outils kubectl installés et configurés avant d'exécuter ce script.
# Author : [Votre Nom]*


set -e

echo "=== Pods Loki ==="
kubectl get pods -n monitoring | grep loki || true

echo
echo "=== Services Loki ==="
kubectl get svc -n monitoring | grep loki || true

echo
echo "=== Test readiness Loki ==="
kubectl run curl-loki-test \
  --rm -it \
  --restart=Never \
  --image=curlimages/curl:8.7.1 \
  -n monitoring \
  -- curl -s http://loki.monitoring.svc.cluster.local:3100/ready || true