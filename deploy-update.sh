#!/bin/bash
set -euo pipefail

PROJECT_DIR="/home/emil-paziuk/network-checker-compose"
STATE_DIR="/home/emil-paziuk/.local/state/network-checker-compose"
STATE_FILE="$STATE_DIR/last-deployed-commit"
LOG_FILE="$PROJECT_DIR/logs/wyniki.log"

cd "$PROJECT_DIR"
mkdir -p "$STATE_DIR"

if [ -n "$(git status --porcelain)" ]; then
    echo "Błąd: repozytorium zawiera lokalne zmiany."
    exit 1
fi

git fetch origin main
REMOTE=$(git rev-parse origin/main)

if [ ! -f "$STATE_FILE" ]; then
    echo "Błąd: brak zapisanego stanu wdrożenia."
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
    printf '%s\n' "$REMOTE" > "$STATE_FILE"
    echo "Zmiany pobrane. Wdrożenie nie było potrzebne."
    exit 0
fi

# Przygotuj komplet poprzedniej wersji przed wdrożeniem.
PREVIOUS_IMAGE=$(git show "$DEPLOYED:compose.yaml" |
    sed -n 's/^[[:space:]]*image:[[:space:]]*//p')

if [ -z "$PREVIOUS_IMAGE" ] || [ "$(printf '%s\n' "$PREVIOUS_IMAGE" | wc -l)" -ne 1 ]; then
    echo "Błąd: nie można jednoznacznie ustalić poprzedniego obrazu."
    exit 1
fi

case "$PREVIOUS_IMAGE" in
    ghcr.io/emil123p/network-checker:*) ;;
    *)
        echo "Błąd: poprzedni obraz ma nieoczekiwaną nazwę."
        exit 1
        ;;
esac

git show "$DEPLOYED:monitor.sh" > "$STATE_DIR/previous-monitor.sh"

cat > "$STATE_DIR/rollback-compose.yaml" <<ROLLBACK
services:
  network-checker:
    image: $PREVIOUS_IMAGE
    entrypoint: ["/bin/sh", "/app/monitor.sh"]
    environment:
      CHECK_HOST: \${CHECK_HOST:-github.com}
      CHECK_INTERVAL: \${CHECK_INTERVAL:-30}
      CHECK_TIMEOUT: \${CHECK_TIMEOUT:-3}
    volumes:
      - $PROJECT_DIR/logs:/app/logs
      - $STATE_DIR/previous-monitor.sh:/app/monitor.sh:ro
    restart: unless-stopped
ROLLBACK

health_check() {
    local baseline="$1"
    local compose_file="$2"
    local container_id
    local running
    local current_lines
    local attempt

    for attempt in $(seq 1 30); do
        container_id=$(docker compose --project-directory "$PROJECT_DIR" -f "$compose_file" ps -q network-checker 2>/dev/null || true)
        running="false"

        if [ -n "$container_id" ]; then
            running=$(docker inspect -f '{{.State.Running}}' "$container_id" 2>/dev/null || echo false)
        fi

        current_lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)

        if [ "$running" = "true" ] && [ "$current_lines" -gt "$baseline" ]; then
            return 0
        fi

        sleep 2
    done

    return 1
}

rollback() {
    echo "Rozpoczynam przywracanie poprzedniej wersji..."

    local baseline
    baseline=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)

    if docker compose \
        --project-directory "$PROJECT_DIR" \
        -f "$STATE_DIR/rollback-compose.yaml" \
        up -d --force-recreate \
        && health_check "$baseline" "$STATE_DIR/rollback-compose.yaml"; then
        echo "Rollback zakończony: poprzednia wersja działa."
    else
        echo "ALARM: rollback nie powiódł się lub kontrola zdrowia nie przeszła."
    fi

    # Celowo pozostawiamy STATE_FILE bez zmian.
    # System ponowi próbę przy następnym uruchomieniu timera.
    exit 1
}

git merge --ff-only origin/main

if ! docker compose config -q; then
    echo "Błąd konfiguracji Compose."
    rollback
fi

if ! docker compose pull; then
    echo "Błąd pobierania nowego obrazu."
    rollback
fi

BASELINE=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)

if ! docker compose up -d --force-recreate; then
    echo "Błąd uruchamiania nowej wersji."
    rollback
fi

if ! health_check "$BASELINE" "$PROJECT_DIR/compose.yaml"; then
    echo "Błąd: nowa wersja nie przeszła kontroli zdrowia."
    rollback
fi

printf '%s\n' "$REMOTE" > "$STATE_FILE"
echo "Wdrożenie zakończone pomyślnie. Kontener działa i zapisał nowy pomiar."
