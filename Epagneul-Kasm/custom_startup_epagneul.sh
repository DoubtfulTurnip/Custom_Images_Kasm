#!/bin/bash
# Optimized Epagneul startup script for Kasm

set -euo pipefail

LOGFILE="$HOME/Desktop/Epagneul_startup.log"
STATUS_FILE="$HOME/Desktop/Epagneul_Status.txt"
PREBUILT_DIR="/opt/epagneul-images"
COMPOSE_FILE="/epagneul/docker-compose-prod.yml"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOGFILE"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOGFILE"
}

update_status() {
    cat > "$STATUS_FILE" <<EOF
=== Epagneul Optimized Startup ===
Started: $(date)
$1
EOF
}

start_docker() {
    log "Starting Docker service"
    sudo service docker start || true
    for i in {1..20}; do
        if docker info >/dev/null 2>&1; then
            log "Docker is ready"
            return
        fi
        sleep 1
    done
    error "Docker failed to start"
    exit 1
}

load_images() {
    log "Loading prebuilt images"
    for tar in "$PREBUILT_DIR"/*.tar; do
        if [ ! -f "$tar" ]; then
            error "Missing tarball: $tar"
            exit 1
        fi
        name=$(basename "$tar")
        log "Loading $name"
        docker load -i "$tar" || {
            error "Failed to load $name"
            exit 1
        }
    done
}

start_stack() {
    log "Starting Epagneul stack"
    update_status "Starting Epagneul services..."
    docker compose -p epagneul -f "$COMPOSE_FILE" up -d
}

wait_for_services() {
    log "Waiting for services"
    for i in {1..60}; do
        if curl -sf http://localhost:8080 >/dev/null && \
           curl -sf http://localhost:8000 >/dev/null; then
            update_status "✅ Epagneul is ready at http://localhost:8080"
            return
        fi
        sleep 2
    done
    error "Services did not come online in time"
}

launch_browser() {
    log "Launching browser"
    if command -v google-chrome >/dev/null; then
        google-chrome --no-sandbox --disable-dev-shm-usage "http://localhost:8080" >/dev/null 2>&1 &
    elif command -v chromium-browser >/dev/null; then
        chromium-browser --no-sandbox --disable-dev-shm-usage "http://localhost:8080" >/dev/null 2>&1 &
    else
        error "No Chrome/Chromium installed in this Kasm image"
    fi
}

main() {
    mkdir -p "$(dirname "$LOGFILE")"
    : > "$LOGFILE"
    start_docker
    load_images
    start_stack
    wait_for_services
    launch_browser
    log "Startup complete"
}

main "$@"
