#!/usr/bin/env bash
# Script de vérification de l'environnement de monitoring
# Ce script vérifie la présence et l'état des composants de monitoring (Prometheus, Loki
# et Grafana) dans le namespace monitoring. Il affiche les pods, services et releases Helm associés à ces composants.
# Usage : ./scripts/check-monitoring.sh
# Note : Assurez-vous d'avoir les outils kubectl et helm installés et configurés avant d'exécuter ce script.
# Author : [Votre Nom]*


set -e

echo "=== Pods monitoring ==="
kubectl get pods -n monitoring -o wide

echo
echo "=== Services monitoring ==="
kubectl get svc -n monitoring

echo
echo "=== Releases Helm monitoring ==="
helm list -n monitoring

echo
echo "=== Pods Loki ==="
kubectl get pods -n monitoring | grep loki || true

echo
echo "=== Pods Prometheus ==="
kubectl get pods -n monitoring | grep prometheus || true

echo
echo "=== Pods Grafana ==="
kubectl get pods -n monitoring | grep grafana || true