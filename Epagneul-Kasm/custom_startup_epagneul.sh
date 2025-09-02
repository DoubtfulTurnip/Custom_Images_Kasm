#!/bin/bash
# Epagneul optimized startup for Kasm (prebuilt tarball images)

set -euo pipefail

# Config
readonly EPAGNEUL_DIR="/epagneul"
readonly DESKTOP_DIR="/home/kasm-user/Desktop"
readonly LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
readonly STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
readonly GUIDE_FILE="$DESKTOP_DIR/Epagneul_User_Guide.txt"
readonly IMAGES_DIR="/opt/epagneul-images"

readonly WEB_UI_URL="http://localhost:8080"
readonly BACKEND_URL="http://localhost:8000"
readonly NEO4J_URL="http://localhost:7474"

mkdir -p "$DESKTOP_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOGFILE"
}

update_status() {
    cat > "$STATUS_FILE" << EOF
=== Epagneul Status ===
Last Updated: $(date)
Status: $1

$2

🌐 Web UI: $WEB_UI_URL
⚙️ Backend: $BACKEND_URL
🗄️ Neo4j: $NEO4J_URL

Logs: $LOGFILE
EOF
}

# Cleanup old containers
cleanup() {
    log INFO "Cleaning old containers"
    docker ps -aq --filter "name=epagneul" | xargs -r docker rm -f || true
}

# Load prebuilt images
load_images() {
    log INFO "Loading prebuilt images"
    for img in epagneul-backend epagneul-frontend; do
        if [[ -f "$IMAGES_DIR/${img}.tar" ]]; then
            log INFO "Loading $img from tar"
            docker load -i "$IMAGES_DIR/${img}.tar" >>"$LOGFILE" 2>&1 || {
                log WARN "Failed to load $img, will pull/build at runtime"
            }
        else
            log WARN "Tarball not found for $img"
        fi
    done
}

# Start services
start_services() {
    log INFO "Starting Epagneul stack"
    cd "$EPAGNEUL_DIR"
    update_status "⏳ DEPLOYING" "Starting services from prebuilt images..."
    docker compose -p epagneul -f docker-compose-prod.yml up -d >>"$LOGFILE" 2>&1
}

# Wait for readiness
wait_ready() {
    log INFO "Waiting for services to come online"
    for i in {1..90}; do
        if curl -sf "$WEB_UI_URL" >/dev/null && \
           curl -sf "$BACKEND_URL" >/dev/null && \
           curl -sf "$NEO4J_URL" >/dev/null; then
            log INFO "All services are ready"
            return 0
        fi
        sleep 1
    done
    log WARN "Timeout waiting for services"
}

# Open Chrome
launch_browser() {
    log INFO "Launching browser to $WEB_UI_URL"
    google-chrome --no-sandbox --disable-dev-shm-usage "$WEB_UI_URL" >/dev/null 2>&1 &
}

# Main
{
    echo "=== Epagneul Optimized Startup ===" >"$LOGFILE"
    echo "Started: $(date)" >>"$LOGFILE"

    update_status "🚀 STARTING" "Initializing Epagneul..."
    cleanup
    load_images
    start_services
    wait_ready

    update_status "✅ READY" "Epagneul is running and ready for use"
    launch_browser

    log INFO "Startup complete"
} || {
    update_status "❌ FAILED" "Startup failed, check $LOGFILE"
    exit 1
}
