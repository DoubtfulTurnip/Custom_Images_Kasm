FROM kasmweb/ubuntu-noble-dind:1.17.0 

USER root

# Set Kasm environment variables
ENV HOME=/home/kasm-default-profile \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

######### Pre-build Optimization for Faster Deployment ###########

# Install all required packages in a single layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        jq \
        libnotify-bin \
        netcat-openbsd \
        python3 \
        python3-pip \
        nodejs \
        npm \
        build-essential && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Clone Epagnuel source and pre-build application images during Docker build
RUN echo "Pre-building Epagnuel application..." && \
    git clone https://github.com/jurelou/epagneul.git /epagneul-source && \
    cd /epagneul-source && \
    \
    # Build the application images during Docker build time
    if [ -f "docker-compose-prod.yml" ]; then \
        COMPOSE_FILE="docker-compose-prod.yml"; \
    else \
        COMPOSE_FILE="docker-compose.yml"; \
    fi && \
    \
    # Start Docker daemon in background for building
    dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2376 & \
    sleep 10 && \
    \
    # Build application images
    docker compose -f "$COMPOSE_FILE" build && \
    \
    # Save built images as tar files for faster loading
    mkdir -p /opt/epagneul-images && \
    docker save $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(epagneul|frontend|backend)" | head -5) \
        > /opt/epagneul-images/epagneul-apps.tar 2>/dev/null || \
        echo "Image save failed, will build at runtime" && \
    \
    # Stop Docker daemon
    pkill -f dockerd && \
    sleep 5 && \
    \
    # Clean up source but keep tar file
    rm -rf /epagneul-source && \
    \
    # Create optimized directory structure
    mkdir -p /epagneul && \
    chown -R 1000:0 /epagneul /opt/epagneul-images

# Create optimized compose file that loads pre-built images
COPY <<'EOF' /epagneul/docker-compose-prod.yml
version: '3.8'

services:
  backend:
    image: epagneul-backend:latest
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-backend"
    ports:
      - "8000:8000"
    depends_on:
      - neo4j
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  frontend:
    image: epagneul-frontend:latest
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-frontend"
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  neo4j:
    image: neo4j:4.4-community
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-neo4j"
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/password
      - NEO4J_apoc_export_file_enabled=true
      - NEO4J_apoc_import_file_enabled=true
      - NEO4J_apoc_import_file_use__neo4j__config=true
      - NEO4J_dbms_memory_heap_initial__size=512m
      - NEO4J_dbms_memory_heap_max__size=1G
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
      - neo4j_import:/import
    networks:
      - backend
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7474"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

volumes:
  neo4j_data:
    name: "${COMPOSE_PROJECT_NAME:-epagneul}_neo4j_data"
  neo4j_logs:
    name: "${COMPOSE_PROJECT_NAME:-epagneul}_neo4j_logs"
  neo4j_import:
    name: "${COMPOSE_PROJECT_NAME:-epagneul}_neo4j_import"

networks:
  backend:
    name: "${COMPOSE_PROJECT_NAME:-epagneul}_backend"
    driver: bridge
EOF

# Pre-pull Neo4j image to avoid runtime download
RUN dockerd --host=unix:///var/run/docker.sock & \
    sleep 10 && \
    docker pull neo4j:4.4-community && \
    pkill -f dockerd && sleep 5

# Create optimized startup script
COPY <<'EOF' /opt/fast-startup.sh
#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%H:%M:%S')] $*" | tee -a /home/kasm-user/Desktop/Epagneul_startup.log
}

# Start Docker service
sudo service docker start
sleep 5

log "Loading pre-built Epagnuel images..."

# Load pre-built images if they exist
if [[ -f "/opt/epagneul-images/epagneul-apps.tar" ]]; then
    docker load < /opt/epagneul-images/epagneul-apps.tar
    log "Pre-built images loaded successfully"
else
    log "No pre-built images found, will build at runtime"
fi

# Generate unique project name
PROJECT_NAME="epagneul-$(date +%s)-$(shuf -i 1000-9999 -n 1 2>/dev/null || echo $RANDOM)"
export COMPOSE_PROJECT_NAME="$PROJECT_NAME"

log "Starting Epagneul with project: $PROJECT_NAME"

# Start services
cd /epagneul
docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml up -d

# Wait for services
log "Waiting for services to be ready..."
for i in {1..120}; do
    if curl -sf http://localhost:8080 >/dev/null 2>&1; then
        log "Epagneul web interface is ready!"
        break
    fi
    sleep 2
done

# Launch browser
sleep 3
google-chrome --start-maximized --no-first-run http://localhost:8080 &

# Create desktop files
cat > /home/kasm-user/Desktop/Epagneul_Info.txt << EOL
=== Epagneul Windows Event Log Analyzer ===
Started: $(date)

🌐 Web Interface: http://localhost:8080
⚙️  Backend API: http://localhost:8000  
🗄️  Neo4j Browser: http://localhost:7474

Project: $PROJECT_NAME
Container Status: docker compose -p "$PROJECT_NAME" ps
EOL

notify-send -t 15000 "🔍 Epagnuel Ready!" \
    "Windows Event Log Analyzer is ready
Web Interface: http://localhost:8080
Check desktop for more information"

log "Epagnuel startup completed successfully"
EOF

RUN chmod +x /opt/fast-startup.sh

# Copy the enhanced startup script (fallback if provided)
COPY custom_startup_epagnuel.sh $STARTUPDIR/custom_startup.sh 2>/dev/null || \
     cp /opt/fast-startup.sh $STARTUPDIR/custom_startup.sh

RUN chmod +x $STARTUPDIR/custom_startup.sh

# Create health check script
COPY <<'EOF' /usr/local/bin/epagneul-health-check
#!/bin/bash
web_ui=$(curl -sf http://localhost:8080 >/dev/null 2>&1 && echo "OK" || echo "DOWN")
backend=$(curl -sf http://localhost:8000 >/dev/null 2>&1 && echo "OK" || echo "DOWN")
neo4j=$(curl -sf http://localhost:7474 >/dev/null 2>&1 && echo "OK" || echo "DOWN")

if [[ "$web_ui" == "OK" ]]; then
    echo "Epagneul is healthy (WebUI: $web_ui, Backend: $backend, Neo4j: $neo4j)"
    exit 0
else
    echo "Epagneul not ready (WebUI: $web_ui, Backend: $backend, Neo4j: $neo4j)"
    exit 1
fi
EOF

RUN chmod +x /usr/local/bin/epagneul-health-check

# Add container health check
HEALTHCHECK --interval=30s --timeout=15s --start-period=180s --retries=3 \
    CMD /usr/local/bin/epagneul-health-check

######### End Optimizations ###########

# Fix permissions
RUN chown -R 1000:0 /epagneul /opt && \
    chown 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

# Switch to persistent user profile
ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000

# Pre-built optimization markers for GitHub Actions
# Single self-contained Kasm workspace image
