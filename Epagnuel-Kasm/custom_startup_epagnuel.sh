#!/bin/bash
# Enhanced Epagneul startup script for Kasm (background execution)
# Windows Event Log Visualization and Investigation Tool

set -euo pipefail

# Configuration
readonly EPAGNEUL_DIR="/epagneul"
readonly DESKTOP_DIR="/home/kasm-user/Desktop"
readonly LOGFILE="$DESKTOP_DIR/Epagneul_startup.log"
readonly STATUS_FILE="$DESKTOP_DIR/Epagneul_Status.txt"
readonly GUIDE_FILE="$DESKTOP_DIR/Epagneul_User_Guide.txt"
readonly UPLOAD_SCRIPT="$EPAGNEUL_DIR/upload.py"
readonly MAX_RETRIES=3
readonly COMPOSE_TIMEOUT=300  # 5 minutes
readonly SERVICE_TIMEOUT=120  # 2 minutes per service

# Service endpoints
readonly WEB_UI_URL="http://localhost:8080"
readonly BACKEND_URL="http://localhost:8000"
readonly NEO4J_URL="http://localhost:7474"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "$LOGFILE"
}

# Update status file
update_status() {
    local status="$1"
    local message="$2"
    
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

=== Documentation ===
📖 User Guide: See Epagneul_User_Guide.txt
📋 Upload Tool: Available at $UPLOAD_SCRIPT
🔍 Log Analysis: Check $LOGFILE for details
EOF
    
    chmod 644 "$STATUS_FILE" 2>/dev/null || true
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    log "ERROR" "Startup failed at line $line_number with exit code $exit_code"
    
    update_status "❌ FAILED" "Epagneul startup failed. Check the log file for details.

Common issues:
• Docker service not starting
• Port conflicts (8080, 8000, 7474 already in use)
• Insufficient disk space for Neo4j database
• Docker compose file issues

Troubleshooting:
1. Check if ports are available: netstat -tlnp | grep -E '(8080|8000|7474)'
2. Restart Docker: sudo service docker restart
3. Clean up containers: docker system prune -f
4. Check disk space: df -h

Log file: $LOGFILE"
    
    notify-send -u critical -t 0 "Epagneul Startup Failed" \
        "Event log analyzer failed to start. Check Epagneul_Status.txt on desktop for troubleshooting."
    
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Cleanup existing containers
cleanup_existing() {
    log "INFO" "Cleaning up existing Epagneul containers"
    
    # Stop and remove containers with common Epagneul names
    local container_patterns=("workspace" "epagneul" "frontend" "backend" "neo4j")
    
    for pattern in "${container_patterns[@]}"; do
        local containers=$(docker ps -aq --filter "name=${pattern}" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            log "INFO" "Removing existing containers matching: $pattern"
            echo "$containers" | xargs docker rm -f >/dev/null 2>&1 || true
        fi
    done
    
    # Clean up any orphaned compose projects from previous runs
    cd "$EPAGNEUL_DIR"
    
    # Try to clean up with various possible project names
    local possible_projects=("workspace" "epagneul" "$(basename "$EPAGNEUL_DIR")")
    for project in "${possible_projects[@]}"; do
        docker compose -p "$project" -f docker-compose-prod.yml down --remove-orphans >/dev/null 2>&1 || true
    done
    
    # Generic cleanup for any compose file in the directory
    docker compose -f docker-compose-prod.yml down --remove-orphans >/dev/null 2>&1 || true
    
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
    
    local retry_count=0
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        if sudo service docker start >/dev/null 2>&1; then
            # Wait for Docker daemon
            for ((i=1; i<=30; i++)); do
                if docker info >/dev/null 2>&1; then
                    log "INFO" "Docker service ready"
                    return 0
                fi
                sleep 1
            done
        fi
        
        ((retry_count++))
        log "WARN" "Docker start attempt $retry_count failed"
        sleep 3
    done
    
    log "ERROR" "Failed to start Docker service"
    return 1
}

# Check and prepare compose file
prepare_compose_environment() {
    log "INFO" "Preparing Epagneul environment"
    update_status "📋 PREPARING" "Checking Epagneul configuration..."
    
    cd "$EPAGNEUL_DIR"
    
    # Check for required compose file
    if [[ ! -f "docker-compose-prod.yml" ]]; then
        log "ERROR" "docker-compose-prod.yml not found"
        
        # Check for alternative compose files
        if [[ -f "docker-compose.yml" ]]; then
            log "INFO" "Using docker-compose.yml as fallback"
            cp docker-compose.yml docker-compose-prod.yml
        else
            log "ERROR" "No docker-compose files found"
            return 1
        fi
    fi
    
    # Generate unique project name to ensure container uniqueness
    PROJECT_NAME="epagneul_$(date +%s)_$"
    export PROJECT_NAME
    log "INFO" "Using unique project name: $PROJECT_NAME"
    
    # Verify compose file is valid
    if ! docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml config >/dev/null 2>&1; then
        log "WARN" "Compose file validation had warnings, but continuing"
    fi
    
    log "SUCCESS" "Compose environment ready with unique project name"
}

# Start Epagneul services
start_epagneul_services() {
    log "INFO" "Starting Epagneul services"
    update_status "⏳ DEPLOYING" "Deploying Epagneul services with unique identifiers...

Services being started:
• 🌐 Web UI (Vue.js frontend)
• ⚙️ Backend API (Python/FastAPI)  
• 🗄️ Neo4j Graph Database
• 🔧 Additional components

Project: $PROJECT_NAME

Please wait - the system needs time to:
• Download and start containers
• Initialize the Neo4j database
• Set up the web interface
• Configure service communication"
    
    log "INFO" "Project name: $PROJECT_NAME"
    
    # Verify project name is valid before using it
    if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        log "ERROR" "Invalid project name: $PROJECT_NAME"
        # Generate a simple fallback name
        PROJECT_NAME="epagneul-$(date +%s)"
        log "INFO" "Using fallback project name: $PROJECT_NAME"
    fi
    
    # Start services with timeout and unique project name
    timeout "$COMPOSE_TIMEOUT" docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml up -d || {
        log "ERROR" "Failed to start Epagneul services within timeout"
        log "INFO" "Checking for container conflicts..."
        
        # Show any conflicting containers
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | head -10 >> "$LOGFILE" 2>&1 || true
        
        # Get detailed logs
        docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml logs --tail=30 >> "$LOGFILE" 2>&1 || true
        return 1
    }
    
    log "SUCCESS" "Epagneul containers started with project: $PROJECT_NAME"
}

# Wait for services to be ready
wait_for_services() {
    log "INFO" "Waiting for Epagneul services to be ready"
    update_status "⌛ INITIALIZING" "Services are starting up...

🗄️ Neo4j Database: Initializing
⚙️ Backend API: Starting  
🌐 Web Interface: Loading

This process typically takes 2-3 minutes for first startup.
Progress will update automatically."
    
    local services_ready=0
    local max_wait=180  # 3 minutes total
    
    for ((i=1; i<=max_wait; i++)); do
        # Check Neo4j (most critical service)
        local neo4j_ready=0
        if curl -sf "$NEO4J_URL" >/dev/null 2>&1; then
            neo4j_ready=1
            log "INFO" "Neo4j database is ready"
        fi
        
        # Check Backend API
        local backend_ready=0
        if curl -sf "$BACKEND_URL/health" >/dev/null 2>&1 || curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
            backend_ready=1
            log "INFO" "Backend API is ready"
        fi
        
        # Check Web UI
        local webui_ready=0
        if curl -sf "$WEB_UI_URL" >/dev/null 2>&1; then
            webui_ready=1
            log "INFO" "Web UI is ready"
        fi
        
        # Update status every 30 seconds
        if ((i % 30 == 0)); then
            local status_msg="Service startup in progress... (${i}s elapsed)

🗄️ Neo4j Database: $([ $neo4j_ready -eq 1 ] && echo "✅ Ready" || echo "⏳ Starting")
⚙️ Backend API: $([ $backend_ready -eq 1 ] && echo "✅ Ready" || echo "⏳ Starting")  
🌐 Web Interface: $([ $webui_ready -eq 1 ] && echo "✅ Ready" || echo "⏳ Starting")

Please be patient - graph databases take time to initialize."
            
            update_status "⌛ INITIALIZING" "$status_msg"
        fi
        
        # Check if all services are ready
        if [[ $neo4j_ready -eq 1 && $backend_ready -eq 1 && $webui_ready -eq 1 ]]; then
            log "SUCCESS" "All Epagneul services are ready"
            services_ready=1
            break
        fi
        
        sleep 1
    done
    
    if [[ $services_ready -eq 0 ]]; then
        log "WARN" "Not all services ready within timeout, but continuing"
        # Check which services are still starting
        docker compose -p "$PROJECT_NAME" ps >> "$LOGFILE" 2>&1 || true
    fi
    
    return 0
}

# Create user guide
create_user_guide() {
    log "INFO" "Creating user guide"
    
    cat > "$GUIDE_FILE" << EOF
=== Epagneul Windows Event Log Analyzer ===
Generated: $(date)

🎯 PURPOSE:
Epagneul is a powerful tool for visualizing and investigating Windows event logs.
It uses graph-based analysis to reveal relationships between hosts, users, and logon events.

🌐 ACCESS POINTS:
• Web UI: $WEB_UI_URL (Main interface)
• Backend API: $BACKEND_URL (REST API)  
• Neo4j Browser: $NEO4J_URL (Graph database)

📊 KEY FEATURES:
• Graph visualization of Windows logon events
• Timeline analysis of authentication activities  
• Relationship mapping between hosts and accounts
• Support for EVTX and JSONL file formats
• Neo4j graph database for complex queries

🔧 GETTING STARTED:

1. UPLOAD EVENT LOGS:
   Method 1 - Web Interface:
   • Open $WEB_UI_URL
   • Use the upload interface to add EVTX files
   
   Method 2 - Command Line (if available):
   cd $EPAGNEUL_DIR
   python upload.py --input-path /path/to/logs --folder-name "Investigation_1" --console-url http://127.0.0.1

2. SUPPORTED LOG SOURCES:
   • Windows Security Event Logs (.evtx)
   • Sysmon Event Logs (.evtx)
   • JSONL formatted event data
   • Event IDs: 4624, 4625, 4648, 4672, 4768, 4769, 4771, 4776, 4728, 4732, 4756

3. ANALYSIS WORKFLOW:
   • Upload your Windows event logs
   • Explore the graph visualization
   • Use timeline filters to focus on specific periods
   • Investigate suspicious logon patterns
   • Export findings for reporting

🔍 INVESTIGATION TECHNIQUES:
• Look for unusual logon times or patterns
• Identify lateral movement between systems
• Track privilege escalation events
• Analyze failed logon attempts
• Map user-to-host relationships

⚙️ CONTAINER MANAGEMENT:
Project Name: $PROJECT_NAME
View status: docker compose -p "$PROJECT_NAME" ps
View logs: docker compose -p "$PROJECT_NAME" logs -f
Restart: docker compose -p "$PROJECT_NAME" restart
Stop: docker compose -p "$PROJECT_NAME" down

🐛 TROUBLESHOOTING:
• If web UI doesn't load: Check if port 8080 is available
• If upload fails: Verify backend API at $BACKEND_URL
• If graphs don't appear: Ensure Neo4j is running at $NEO4J_URL
• For performance issues: Monitor container resources

📚 RESOURCES:
• GitHub: https://github.com/jurelou/epagneul
• Similar Tool: LogonTracer by JPCERT
• Neo4j Documentation: https://neo4j.com/docs/
• Windows Event ID Reference: Microsoft Security Auditing

💡 TIPS:
• Start with a small dataset to familiarize yourself with the interface
• Use meaningful folder names when uploading logs
• Combine with other forensic tools for comprehensive analysis
• Export interesting graph views for documentation

📝 LOG FILES:
• Startup Log: $LOGFILE
• Status Monitor: $STATUS_FILE
• Container Logs: docker compose -p "$PROJECT_NAME" logs
EOF
    
    chmod 644 "$GUIDE_FILE"
    log "INFO" "User guide created: $GUIDE_FILE"
}

# Perform health check
perform_health_check() {
    log "INFO" "Performing final health check"
    
    local health_status="Services Health Check:
"
    
    # Check container status
    local running_containers=$(docker compose -p "$PROJECT_NAME" ps -q | wc -l)
    local healthy_containers=0
    
    # Test each service
    if curl -sf "$NEO4J_URL" >/dev/null 2>&1; then
        health_status+="🗄️ Neo4j Database: ✅ Online
"
        ((healthy_containers++))
    else
        health_status+="🗄️ Neo4j Database: ❌ Offline
"
    fi
    
    if curl -sf "$BACKEND_URL" >/dev/null 2>&1; then
        health_status+="⚙️ Backend API: ✅ Online
"  
        ((healthy_containers++))
    else
        health_status+="⚙️ Backend API: ❌ Offline
"
    fi
    
    if curl -sf "$WEB_UI_URL" >/dev/null 2>&1; then
        health_status+="🌐 Web Interface: ✅ Online
"
        ((healthy_containers++))
    else
        health_status+="🌐 Web Interface: ❌ Offline
"
    fi
    
    health_status+="
📊 Containers: $running_containers total, $healthy_containers responding"
    
    log "INFO" "$health_status"
    
    if [[ $healthy_containers -ge 2 ]]; then
        return 0
    else
        log "WARN" "Health check shows some services may not be ready"
        return 1
    fi
}

# Launch browser
launch_browser() {
    log "INFO" "Launching web browser"
    
    # Small delay to ensure everything is settled
    sleep 3
    
    # Launch Chrome with appropriate settings
    google-chrome \
        --start-maximized \
        --no-first-run \
        --no-default-browser-check \
        --disable-extensions \
        --disable-plugins-discovery \
        "$WEB_UI_URL" >/dev/null 2>&1 &
    
    log "SUCCESS" "Browser launched for Epagneul UI"
}

# Final status update
finalize_setup() {
    log "INFO" "Finalizing Epagneul setup"
    
    local running_containers=$(docker compose -p "$PROJECT_NAME" ps -q | wc -l)
    local final_status
    
    if perform_health_check; then
        final_status="✅ READY"
        local final_message="Epagneul is ready for Windows event log analysis!

🌐 Access: $WEB_UI_URL
📖 User Guide: See Epagneul_User_Guide.txt  
📊 Services: $running_containers containers running
🗄️ Database: Neo4j graph database initialized

🚀 QUICK START:
1. Browser will open automatically
2. Upload Windows .evtx files via the web interface
3. Explore the graph visualization
4. Use timeline controls for temporal analysis

Ready to investigate Windows event logs!"
    else
        final_status="⚠️ PARTIAL"
        local final_message="Epagneul started with some issues.

🌐 Web UI: $WEB_UI_URL (try this first)
⚙️ Backend: $BACKEND_URL  
🗄️ Database: $NEO4J_URL

Some services may still be starting up.
Check the log file for details: $LOGFILE

Try refreshing the web interface in a few minutes."
    fi
    
    update_status "$final_status" "$final_message"
    
    # Success notification
    notify-send -t 15000 "🔍 Epagneul Ready!" \
        "Windows Event Log Analyzer is ready
🌐 Web Interface: $WEB_UI_URL
📖 Check desktop for user guide
🚀 Browser opening automatically"
    
    log "SUCCESS" "Epagneul startup completed"
}

# Main execution
main() {
    # Ensure desktop directory exists
    mkdir -p "$DESKTOP_DIR"
    
    # Initialize log
    cat > "$LOGFILE" << EOF
=== Epagneul Windows Event Log Analyzer Startup ===
Started: $(date)
Workspace: $(hostname)
User: $(whoami)
Target Directory: $EPAGNEUL_DIR
====================================================

EOF
    
    log "INFO" "Starting Epagneul deployment"
    
    # Initial notification
    notify-send -t 10000 "🔍 Epagneul Starting" \
        "Windows Event Log Analyzer starting...
This will take 3-5 minutes.
Progress updates on your desktop."
    
    # Initial status
    update_status "🚀 STARTING" "Initializing Epagneul Windows Event Log Analyzer...

This tool provides graph-based visualization for:
• Windows Security Event Logs
• Authentication and logon analysis  
• Lateral movement detection
• Timeline-based investigation

Setup typically takes 3-5 minutes.
Status will update automatically."
    
    # Execute startup sequence
    cleanup_existing
    start_docker_service
    prepare_compose_environment
    start_epagneul_services
    wait_for_services
    create_user_guide
    launch_browser
    finalize_setup
    
    # Keep script alive briefly for stability
    sleep 5
}

# Execute main function with output redirection
main "$@" 2>&1
