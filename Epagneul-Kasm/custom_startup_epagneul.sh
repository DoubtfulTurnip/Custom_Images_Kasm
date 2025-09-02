#!/bin/bash
# Epagneul startup script for Kasm (CI-friendly, no prebuilt tarball logic)

set -euo pipefail

# Configuration
readonly EPAGNEUL_DIR="/epagneul"
readonly DESKTOP_DIR="/home/kasm-user/Desktop"
readonly LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
readonly STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
readonly GUIDE_FILE="$DESKTOP_DIR/Epagneul_User_Guide.txt"
readonly MAX_RETRIES=3
readonly COMPOSE_TIMEOUT=120
readonly SERVICE_TIMEOUT=90

# Service endpoints
readonly WEB_UI_URL="http://localhost:8080"
readonly BACKEND_URL="http://localhost:8000"
readonly NEO4J_URL="http://localhost:7474"

# Logging function
log() {
    local level="$1"; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOGFILE"
}

# Update status file
update_status() {
    local status="$1"; local message="$2"
    cat > "$STATUS_FILE" << EOF
=== Epagneul Event Log Analyzer Status ===
Last Updated: $(date)
Status: $status

$message

=== Service Endpoints ===
🌐 Web UI: $WEB_UI_URL
⚙️  Backend API: $BACKEND_URL
🗄️  Neo4j Database: $NEO4J_URL

=== Container Management ===
Project Name: ${PROJECT_NAME:-"Not started"}
View containers: docker compose -p "${PROJECT_NAME:-epagneul}" ps
View logs: docker compose -p "${PROJECT_NAME:-epagneul}" logs
Stop services: docker compose -p "${PROJECT_NAME:-epagneul}" down
EOF
    chmod 644 "$STATUS_FILE" 2>/dev/null || true
}

# Error handler
handle_error() {
    local exit_code=$?; local line_number=$1
    log "ERROR" "Startup failed at line $line_number with exit code $exit_code"

    update_status "❌ FAILED" "Epagneul startup failed. Check the log file for details.

Common issues:
• Docker service not starting
• Port conflicts (8080, 8000, 7474 already in use)
• Docker compose file issues

Log file: $LOGFILE"

    notify-send -u critical -t 0 "Epagneul Startup Failed" \
        "Event log analyzer failed to start. Check Epagneul_Status.txt on desktop for troubleshooting."

    exit $exit_code
}
trap 'handle_error $LINENO' ERR

# Cleanup existing containers
cleanup_existing() {
    log "INFO" "Cleaning up existing Epagneul containers"
    local patterns=("epagneul" "frontend" "backend" "neo4j")
    for pattern in "${patterns[@]}"; do
        local containers
        containers=$(docker ps -aq --filter "name=${pattern}" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            log "INFO" "Removing containers matching: $pattern"
            echo "$containers" | xargs docker rm -f >/dev/null 2>&1 || true
        fi
    done
    log "INFO" "Container cleanup completed"
}

# Start Docker service
start_docker_service() {
    log "INFO" "Starting Docker service"
    update_status "🚀 STARTING" "Initializing Docker service for Epagneul..."
    if docker info >/dev/null 2>&1; then
        log "INFO" "Docker is already running"
        return 0
    fi
    local retry=0
    while [[ $retry -lt $MAX_RETRIES ]]; do
        if sudo service docker start >/dev/null 2>&1; then
            for ((i=1; i<=30; i++)); do
                if docker info >/dev/null 2>&1; then
                    log "INFO" "Docker service ready"
                    return 0
                fi
                sleep 1
            done
        fi
        ((retry++))
        log "WARN" "Docker start attempt $retry failed"
        sleep 3
    done
    log "ERROR" "Failed to start Docker service"
    return 1
}

# Start Epagneul services
start_epagneul_services() {
    log "INFO" "Starting Epagneul services"
    update_status "⏳ DEPLOYING" "Starting Epagneul services...

Services:
• 🌐 Web UI (Vue.js frontend)
• ⚙️ Backend API (Python/FastAPI)
• 🗄️ Neo4j Graph Database

Expected startup: 60–90 seconds"

    local ts random_id
    ts=$(date +%s)
    random_id=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $RANDOM)
    PROJECT_NAME="epagneul-${ts}-${random_id}"
    export COMPOSE_PROJECT_NAME="$PROJECT_NAME"
    log "INFO" "Using project name: $PROJECT_NAME"

    cd "$EPAGNEUL_DIR"
    if [[ ! -f "docker-compose-prod.yml" ]]; then
        log "ERROR" "docker-compose-prod.yml missing in $EPAGNEUL_DIR"
        return 1
    fi

    timeout "$COMPOSE_TIMEOUT" docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml up -d || {
        log "ERROR" "Failed to start Epagneul services"
        docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml logs --tail=20 >> "$LOGFILE" 2>&1 || true
        return 1
    }
    log "SUCCESS" "Epagneul containers started"
}

# Wait for services
wait_for_services() {
    log "INFO" "Waiting for Epagneul services"
    update_status "⌛ INITIALIZING" "Services are starting up..."
    local ready=0
    for ((i=1; i<=SERVICE_TIMEOUT; i++)); do
        local n=0 b=0 f=0
        curl -sf "$NEO4J_URL" >/dev/null 2>&1 && n=1
        curl -sf "$BACKEND_URL" >/dev/null 2>&1 && b=1
        curl -sf "$WEB_UI_URL" >/dev/null 2>&1 && f=1
        if [[ $n -eq 1 && $b -eq 1 && $f -eq 1 ]]; then
            log "SUCCESS" "All services ready"
            ready=1; break
        fi
        sleep 1
    done
    [[ $ready -eq 0 ]] && log "WARN" "Services not ready within timeout"
    return 0
}

# Create user guide
create_user_guide() {
    cat > "$GUIDE_FILE" << EOF
=== Epagneul Windows Event Log Analyzer ===
Generated: $(date)

🌐 ACCESS:
• Web UI: $WEB_UI_URL
• Backend API: $BACKEND_URL
• Neo4j: $NEO4J_URL

📊 FEATURES:
• Graph visualization of Windows logons
• Timeline analysis
• EVTX + JSONL import
• Neo4j query support

⚙️ MANAGEMENT:
docker compose -p "$PROJECT_NAME" ps
docker compose -p "$PROJECT_NAME" logs
docker compose -p "$PROJECT_NAME" down

Log file: $LOGFILE
EOF
    chmod 644 "$GUIDE_FILE"
    log "INFO" "User guide written"
}

# Finalize
finalize_setup() {
    local running
    running=$(docker compose -p "$PROJECT_NAME" ps -q | wc -l)
    update_status "✅ READY" "Epagneul is ready!

🌐 $WEB_UI_URL
📖 See Epagneul_User_Guide.txt
📊 $running containers running"

    google-chrome --start-maximized --no-first-run --no-sandbox \
        --disable-dev-shm-usage "$WEB_UI_URL" >/dev/null 2>&1 &

    notify-send -t 10000 "🔍 Epagneul Ready!" \
        "Web Interface: $WEB_UI_URL"
    log "SUCCESS" "Epagneul startup complete"
}

# Main
main() {
    mkdir -p "$DESKTOP_DIR"
    echo "=== Epagneul Startup Log ===" > "$LOGFILE"
    log "INFO" "Launching startup"
    cleanup_existing
    start_docker_service
    start_epagneul_services
    wait_for_services
    create_user_guide
    finalize_setup
    sleep 3
}
main "$@" 2>&1
