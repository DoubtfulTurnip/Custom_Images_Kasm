#!/bin/bash
set -euo pipefail

EPAGNEUL_DIR="/epagneul"
DESKTOP_DIR="/home/kasm-user/Desktop"
LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
GUIDE_FILE="$DESKTOP_DIR/Epagneul_User_Guide.txt"
PREBUILT_DIR="/opt/epagneul-images"

WEB_UI_URL="http://localhost:8080"
BACKEND_URL="http://localhost:8000"
NEO4J_URL="http://localhost:7474"

log() {
    echo "$(date '+%F %T') [$1] $2" >> "$LOGFILE"
}

update_status() {
    local status="$1"
    local message="$2"
    cat > "$STATUS_FILE" <<EOF
=== Epagneul Event Log Analyzer ===
Last Updated: $(date)
Status: $status

$message

🌐 Web UI: $WEB_UI_URL
⚙️  Backend API: $BACKEND_URL
🗄️  Neo4j: $NEO4J_URL
EOF
}

load_prebuilt_images() {
    log INFO "Loading prebuilt images"
    if [[ -f "$PREBUILT_DIR/backend.tar" && -f "$PREBUILT_DIR/frontend.tar" ]]; then
        docker load < "$PREBUILT_DIR/backend.tar"
        docker load < "$PREBUILT_DIR/frontend.tar"
        log SUCCESS "Loaded backend & frontend images"
    else
        log ERROR "Prebuilt images missing"
        exit 1
    fi
}

start_services() {
    cd "$EPAGNEUL_DIR"
    docker compose -f docker-compose-prod.yml up -d
    log SUCCESS "Epagneul services started"
}

wait_ready() {
    for i in {1..90}; do
        if curl -sf "$WEB_UI_URL" >/dev/null && curl -sf "$BACKEND_URL" >/dev/null; then
            log SUCCESS "Services ready"
            return 0
        fi
        sleep 2
    done
    log WARN "Services not ready in time"
}

finalize() {
    update_status "✅ READY" "Epagneul is running at $WEB_UI_URL"
    google-chrome --no-sandbox "$WEB_UI_URL" >/dev/null 2>&1 &
}

main() {
    mkdir -p "$DESKTOP_DIR"
    echo "=== Epagneul Startup ===" > "$LOGFILE"
    load_prebuilt_images
    start_services
    wait_ready
    finalize
}
main "$@"
