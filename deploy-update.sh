#!/bin/bash
set -euo pipefail

cd /home/emil-paziuk/network-checker-compose

STATE_DIR="$HOME/.local/state/network-checker-compose"
STATE_FILE="$STATE_DIR/last-deployed-commit"

mkdir -p "$STATE_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Błąd: repozytorium zawiera lokalne zmiany."
    exit 1
fi

git fetch origin main

REMOTE=$(git rev-parse origin/main)

if [ ! -f "$STATE_FILE" ]; then
    echo "Brak zapisanego stanu wdrożenia."
    echo "Najpierw trzeba go bezpiecznie zainicjalizować."
    exit 1
fi

DEPLOYED=$(cat "$STATE_FILE")

if [ "$DEPLOYED" = "$REMOTE" ]; then
    echo "Brak nowych zmian."
    exit 0
fi

if ! git merge-base --is-ancestor "$DEPLOYED" "$REMOTE"; then
    echo "Błąd: historia zmian wymaga ręcznej kontroli."
    exit 1
fi

if ! git merge-base --is-ancestor HEAD "$REMOTE"; then
    echo "Błąd: lokalna gałąź wymaga ręcznej kontroli."
    exit 1
fi

if git diff --quiet "$DEPLOYED" "$REMOTE" -- compose.yaml monitor.sh; then
    git merge --ff-only origin/main
    echo "$REMOTE" > "$STATE_FILE"
    echo "Zmiany pobrane. Wdrożenie nie było potrzebne."
    exit 0
fi

git merge --ff-only origin/main

docker compose config -q
docker compose pull
docker compose up -d

echo "$REMOTE" > "$STATE_FILE"
echo "Wdrożenie zakończone pomyślnie."
