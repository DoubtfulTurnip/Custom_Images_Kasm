#!/bin/bash
# Optimized Epagneul startup script for Kasm

set -euo pipefail

EPAGNEUL_DIR="/epagneul"
DESKTOP_DIR="/home/kasm-user/Desktop"
LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
GUIDE_FILE="$DESKTOP_DIR/Epagneul_User_Guide.txt"
PREBUILT_BACKEND="/opt/epagneul-images/epagneul-backend.tar"
PREBUILT_FRONTEND="/opt/epagneul-images/epagneul-frontend.tar"

WEB_UI_URL="http://localhost:8080"
BACKEND_URL="http://localhost:8000"
NEO4J_URL="http://localhost:7474"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" >> "$LOGFILE"
}

update_status() {
    cat > "$STATUS_FILE" <<EOF
=== Epagneul Status ===
Last Updated: $(date)
Status: $1

$2

Web UI: $WEB_UI_URL
Backend: $BACKEND_URL
Neo4j: $NEO4J_URL
EOF
}

start_docker_service() {
    log "INFO" "Starting Docker service"
    if docker info >/dev/null 2>&1; then
        log "INFO" "Docker already running"
        return 0
    fi
    local retries=0
    while [[ $retries -lt 5 ]]; do
        if sudo service docker start >/dev/null 2>&1; then
            for i in {1..30}; do
                if docker info >/dev/null 2>&1; then
                    log "INFO" "Docker is ready"
                    return 0
                fi
                sleep 1
            done
        fi
        retries=$((retries+1))
        log "WARN" "Docker start attempt $retries failed"
        sleep 3
    done
    log "ERROR" "Docker service could not be started"
    return 1
}

load_prebuilt_images() {
    log "INFO" "Loading prebuilt images"
    if [[ -f "$PREBUILT_BACKEND" ]]; then
        log "INFO" "Loading backend image"
        docker load -i "$PREBUILT_BACKEND" || log "WARN" "Backend load failed"
    fi
    if [[ -f "$PREBUILT_FRONTEND" ]]; then
        log "INFO" "Loading frontend image"
        docker load -i "$PREBUILT_FRONTEND" || log "WARN" "Frontend load failed"
    fi
}

start_epagneul() {
    cd "$EPAGNEUL_DIR"
    docker compose -p epagneul -f docker-compose-prod.yml up -d
    log "INFO" "Epagneul stack started"
}

launch_browser() {
    sleep 5
    google-chrome --no-sandbox --disable-dev-shm-usage "$WEB_UI_URL" >/dev/null 2>&1 &
}

main() {
    mkdir -p "$DESKTOP_DIR"
    echo "=== Epagneul Optimized Startup ===" > "$LOGFILE"
    echo "Started: $(date)" >> "$LOGFILE"

    update_status "🚀 STARTING" "Initializing Epagneul..."

    start_docker_service
    load_prebuilt_images
    start_epagneul
    update_status "✅ READY" "Epagneul is running!"
    launch_browser
}

main "$@"
