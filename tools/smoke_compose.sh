#!/usr/bin/env bash
set -euo pipefail

# 1) Lancer broker + backend + front
docker compose up -d --build broker backend front

echo "⏳ Attente que le backend soit prêt..."
for i in {1..30}; do
  if curl -fsS http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Backend OK"
    break
  fi
  sleep 2
done

echo "⏳ Test du front..."
curl -fsS http://localhost:5173 > /dev/null 2>&1
echo "✅ Front répond"

# (optionnel) tu peux ajouter un test MQTT plus tard

echo "✅ Smoke test terminé avec succès"

# On arrête tout à la fin
docker compose down
