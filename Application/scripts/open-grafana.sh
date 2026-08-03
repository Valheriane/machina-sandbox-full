#!/usr/bin/env bash
# Script d'ouverture de Grafana
# Ce script ouvre le port-forward de Grafana pour permettre l'accès à l'interface web de Grafana via http://localhost:3000. Assurez-vous que le service monitoring-grafana est en cours d'exécution dans le namespace monitoring avant d'exécuter ce script.
# Usage : ./scripts/open-grafana.sh
# Note : Assurez-vous d'avoir les outils kubectl installés et configurés avant d'exécuter ce script.
# Author : [Votre Nom]*
set -e

echo "Ouverture du port-forward Grafana sur http://localhost:3000"
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring