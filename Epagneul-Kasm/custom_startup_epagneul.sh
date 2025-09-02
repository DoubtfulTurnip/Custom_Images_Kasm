#!/bin/bash
# Simplified Epagneul startup script for Kasm (no pre-built images)

set -euo pipefail

# Configuration
readonly DESKTOP_DIR="$HOME/Desktop"
readonly LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
readonly STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
readonly COMPOSE_FILE="/epagneul/docker-compose-prod.yml"
readonly WEB_UI_URL="http://localhost:8080"
readonly BACKEND_URL="http://localhost:8000"
readonly NEO4J_URL="http://localhost:7474"

# Logging functions
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $*" | tee -a "$LOGFILE"; }
error() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $*" | tee -a "$LOGFILE"; }
warn() { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $*" | tee -a "$LOGFILE"; }

# Status update function
update_status() {
    local status="$1"
    local details="${2:-}"
    
    cat > "$STATUS_FILE" <<EOF
=== Epagneul Windows Event Log Analyzer ===
Last Updated: $(date)
Status: $status

$details

=== Service Endpoints ===
🌐 Web UI: $WEB_UI_URL
⚙️  Backend API: $BACKEND_URL  
🗄️  Neo4j Database: $NEO4J_URL

=== Container Management ===
Project Name: ${PROJECT_NAME:-"Not started"}
View containers: docker compose -f "$COMPOSE_FILE" -p "${PROJECT_NAME:-epagneul}" ps
View logs: docker compose -f "$COMPOSE_FILE" -p "${PROJECT_NAME:-epagneul}" logs
Stop services: docker compose -f "$COMPOSE_FILE" -p "${PROJECT_NAME:-epagneul}" down

Log file: $LOGFILE
EOF
    
    chmod 644 "$STATUS_FILE" 2>/dev/null || true
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    error "Startup failed at line $line_number with exit code $exit_code"
    
    update_status "❌ FAILED" "Epagneul startup failed at line $line_number.

Common issues:
• Docker service failed to start
• Port conflicts (8080, 8000, 7474 already in use)  
• Network connectivity issues
• Insufficient memory for services

Check the log file for detailed error information."
    
    notify-send -u critical -t 0 "Epagneul Startup Failed" \
        "Event log analyzer failed to start. Check Epagneul_Status.txt on desktop."
    
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Clean up existing containers
cleanup_existing() {
    log "Cleaning up any existing Epagneul containers"
    
    # Remove containers that might conflict
    local patterns=("epagneul" "frontend" "backend" "neo4j")
    for pattern in "${patterns[@]}"; do
        local containers=$(docker ps -aq --filter "name=${pattern}" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            log "Removing existing containers matching: $pattern"
            echo "$containers" | xargs docker rm -f >/dev/null 2>&1 || true
        fi
    done
}

# Start Docker service
start_docker() {
    log "Starting Docker service"
    update_status "🚀 INITIALIZING" "Starting Docker service for Epagneul..."
    
    sudo service docker start || true
    
    for i in {1..30}; do
        if docker info >/dev/null 2>&1; then
            log "Docker service is ready"
            return 0
        fi
        sleep 1
    done
    
    error "Docker failed to start within 30 seconds"
    return 1
}

# Pull required base images
pull_base_images() {
    log "Pre-pulling required base images"
    update_status "📥 PULLING" "Downloading required base images...

Pulling images:
• Python 3.8 (Backend runtime)
• Node.js 18 (Frontend runtime)
• Neo4j 4.4.2 (Graph database)

This ensures faster service startup."
    
    local images=("python:3.8-slim" "node:18-slim" "neo4j:4.4.2")
    local pulled=0
    
    for image in "${images[@]}"; do
        log "Pulling $image"
        if docker pull "$image" >/dev/null 2>&1; then
            log "Successfully pulled $image"
            ((pulled++))
        else
            warn "Failed to pull $image, will retry during service start"
        fi
    done
    
    log "Pre-pulled $pulled base images"
}

# Start the application stack
start_stack() {
    log "Starting Epagneul application stack"
    update_status "⏳ BUILDING" "Building and starting Epagneul services...

Services starting:
• 🗄️ Neo4j Graph Database (ready first)
• ⚙️ Backend API Server (builds Python dependencies)
• 🌐 Frontend Web Interface (builds Node.js app)

First startup includes dependency installation and may take 2-3 minutes."
    
    # Generate unique project name
    local timestamp=$(date +%s)
    local random_id=$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $RANDOM)
    PROJECT_NAME="epagneul-${timestamp}-${random_id}"
    export COMPOSE_PROJECT_NAME="$PROJECT_NAME"
    
    log "Using project name: $PROJECT_NAME"
    
    # Start services with compose
    if timeout 300 docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d; then
        log "Services started successfully"
    else
        error "Failed to start services within timeout"
        docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs --tail=20 | tee -a "$LOGFILE" 2>&1 || true
        return 1
    fi
}

# Wait for all services to be healthy
wait_for_services() {
    log "Waiting for services to become healthy"
    update_status "⌛ BUILDING" "Services are building and initializing...

🗄️ Neo4j Database: Starting (usually ready in 30-60s)
⚙️ Backend API: Installing Python dependencies (1-2 minutes)
🌐 Web Interface: Installing Node.js dependencies (1-2 minutes)

This is normal for first startup as dependencies are being installed."
    
    local max_wait=240  # 4 minutes total for first build
    local services_ready=0
    
    for ((i=1; i<=max_wait; i++)); do
        local neo4j_ready=0
        local backend_ready=0
        local frontend_ready=0
        
        # Check each service
        if curl -sf "$NEO4J_URL" >/dev/null 2>&1; then
            neo4j_ready=1
        fi
        
        if curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
            backend_ready=1
        fi
        
        if curl -sf "$WEB_UI_URL" >/dev/null 2>&1; then
            frontend_ready=1
        fi
        
        # Update status every 30 seconds
        if ((i % 30 == 0)); then
            local status_msg="Service startup in progress... (${i}s elapsed)

🗄️ Neo4j Database: $([ $neo4j_ready -eq 1 ] && echo "✅ Ready" || echo "⏳ Starting")
⚙️ Backend API: $([ $backend_ready -eq 1 ] && echo "✅ Ready" || echo "🔨 Building")
🌐 Web Interface: $([ $frontend_ready -eq 1 ] && echo "✅ Ready" || echo "🔨 Building")

Building includes installing all dependencies from source."
            
            update_status "⌛ BUILDING" "$status_msg"
        fi
        
        # Check if all services are ready
        if [[ $neo4j_ready -eq 1 && $backend_ready -eq 1 && $frontend_ready -eq 1 ]]; then
            log "All services are healthy and ready"
            services_ready=1
            break
        fi
        
        sleep 1
    done
    
    if [[ $services_ready -eq 0 ]]; then
        warn "Not all services became ready within timeout"
        # Show container status for debugging
        docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps | tee -a "$LOGFILE"
        
        # Check if any service is at least partially working
        if [[ $backend_ready -eq 1 || $neo4j_ready -eq 1 ]]; then
            warn "Some services are ready, continuing with launch"
        else
            error "No services are responding, startup may have failed"
            docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs --tail=30 | tee -a "$LOGFILE"
            return 1
        fi
    fi
    
    return 0
}

# Launch browser
launch_browser() {
    log "Preparing to launch browser"
    
    # Final verification that web interface is responding
    for i in {1..15}; do
        if curl -sf "$WEB_UI_URL" >/dev/null 2>&1; then
            log "Web interface confirmed ready, launching browser"
            break
        fi
        log "Web interface not ready, waiting... ($i/15)"
        sleep 3
    done
    
    sleep 2  # Small delay for UI to fully render
    
    log "Launching browser for Epagneul web interface"
    
    # Launch Chrome with container-friendly flags
    if google-chrome \
        --no-sandbox \
        --disable-dev-shm-usage \
        --start-maximized \
        --no-first-run \
        --no-default-browser-check \
        --disable-extensions \
        "$WEB_UI_URL" >/dev/null 2>&1 &
    then
        log "Browser launched successfully"
    else
        warn "Browser launch may have failed"
        
        # Create desktop shortcut as fallback
        cat > "$DESKTOP_DIR/Open_Epagneul.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Open Epagneul  
Comment=Launch Epagneul Web Interface
Exec=google-chrome --no-sandbox $WEB_UI_URL
Icon=web-browser
Terminal=false
Categories=Network;WebBrowser;
EOF
        chmod +x "$DESKTOP_DIR/Open_Epagneul.desktop"
        log "Created desktop shortcut as fallback"
    fi
}

# Create user guide
create_user_guide() {
    log "Creating user guide"
    
    cat > "$DESKTOP_DIR/Epagneul_User_Guide.txt" <<EOF
=== Epagneul Windows Event Log Analyzer ===
Started: $(date)
Deployment: Direct build approach

🎯 PURPOSE:
Epagneul is a powerful tool for visualizing and investigating Windows event logs
using graph-based analysis to reveal relationships between hosts, users, and logon events.

🌐 ACCESS POINTS:
• Web UI: $WEB_UI_URL (Main interface)
• Backend API: $BACKEND_URL (REST API)
• Neo4j Browser: $NEO4J_URL (Graph database)

🚀 DEPLOYMENT FEATURES:
• Direct source build (no Docker-in-Docker complexity)
• Fresh dependency installation for latest compatibility
• Reliable container orchestration
• Expected startup time: 2-3 minutes (first run), 30-60s (subsequent)

📊 KEY FEATURES:
• Graph visualization of Windows logon events
• Timeline analysis of authentication activities
• Relationship mapping between hosts and accounts
• Support for EVTX and JSONL file formats
• Neo4j graph database for complex queries

🔧 GETTING STARTED:
1. Upload Windows event logs (.evtx files) via the web interface
2. Explore the graph visualization to see relationships
3. Use timeline filters to focus on specific periods
4. Investigate suspicious patterns and lateral movement
5. Export findings for reporting

📋 COMMON WORKFLOWS:
• Incident Response: Upload logs from compromised systems
• Threat Hunting: Look for patterns across multiple systems  
• Compliance Auditing: Analyze authentication activities
• Forensic Analysis: Timeline reconstruction of events

⚙️ CONTAINER MANAGEMENT:
Project: $PROJECT_NAME
Status: docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps  
Logs: docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
Stop: docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
Restart: docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" restart

📚 RESOURCES:
• GitHub: https://github.com/jurelou/epagneul
• Neo4j Documentation: https://neo4j.com/docs/
• Windows Event ID Reference: Microsoft Security Auditing
• EVTX Format: Windows Event Log Analysis

💡 TROUBLESHOOTING:
• If web UI doesn't load: Check $WEB_UI_URL in browser, may need more time
• If upload fails: Verify backend API at $BACKEND_URL
• If graphs don't appear: Ensure Neo4j at $NEO4J_URL, check data import
• For slow performance: Check container resources, restart services if needed
• Build failures: Check logs for dependency installation errors

🔍 ANALYSIS TIPS:
• Start with small log files to familiarize yourself with the interface
• Use meaningful names when organizing your investigations
• Combine with other forensic tools for comprehensive analysis
• Export interesting findings for documentation and reporting

Log file: $LOGFILE
Status file: $STATUS_FILE
EOF
    
    chmod 644 "$DESKTOP_DIR/Epagneul_User_Guide.txt"
    log "User guide created successfully"
}

# Finalize setup
finalize_setup() {
    log "Finalizing Epagneul setup"
    
    local running_containers=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q --filter "status=running" | wc -l)
    local total_containers=$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps -q | wc -l)
    
    update_status "✅ READY" "Epagneul is ready for Windows event log analysis!

🌐 Access: $WEB_UI_URL  
📖 User Guide: See Epagneul_User_Guide.txt
📊 Services: $running_containers/$total_containers containers running
🔧 Build: Direct source build completed

🚀 QUICK START:
1. Browser opened automatically to web interface
2. Upload Windows .evtx files for analysis  
3. Explore graph visualization and timeline
4. Check desktop files for detailed documentation

Ready to investigate Windows event logs!"
    
    # Create user guide
    create_user_guide
    
    # Success notification
    notify-send -t 15000 "🔍 Epagneul Ready!" \
        "Windows Event Log Analyzer is ready!
🌐 Web Interface: $WEB_UI_URL
🔧 Direct build deployment completed
📖 Check desktop for user guide and status"
    
    log "Epagneul startup completed successfully"
}

# Main execution
main() {
    # Ensure desktop directory exists
    mkdir -p "$DESKTOP_DIR"
    
    # Initialize log file
    cat > "$LOGFILE" <<EOF
=== Epagneul Direct Build Startup Log ===
Started: $(date)
Workspace: $(hostname)
User: $(whoami)
Approach: Direct source build (no Docker-in-Docker)
=============================================

EOF
    
    log "Starting Epagneul deployment with direct build approach"
    
    # Initial notification
    notify-send -t 10000 "🔍 Epagneul Starting" \
        "Windows Event Log Analyzer starting...
🔧 Using direct build approach
Expected time: 2-3 minutes (first run)
Progress updates on desktop"
    
    # Initial status
    update_status "🚀 INITIALIZING" "Starting Epagneul deployment with direct build...

This version builds services directly from source for maximum reliability.
First startup includes dependency installation and may take 2-3 minutes.

Features:
• Graph-based Windows event log analysis
• Timeline visualization  
• Relationship mapping
• Neo4j backend for complex queries

Status will update automatically as services build and start."
    
    # Execute startup sequence
    cleanup_existing
    start_docker
    pull_base_images
    start_stack
    wait_for_services
    launch_browser  
    finalize_setup
    
    # Brief pause for stability
    sleep 3
    log "All startup tasks completed successfully"
}

# Execute main function with error handling
main "$@" 2>&1
