# =========================
# Stage 1 - Fetch source
# =========================
FROM alpine/git AS source
WORKDIR /src
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git
  
# =========================
# Stage 2 - Backend image build
# =========================
FROM docker:24-dind AS backend-builder

# Enable Docker daemon to run in background
ENV DOCKER_TLS_CERTDIR=""
ENV DOCKER_HOST=unix:///var/run/docker.sock

WORKDIR /build

# Start Docker daemon with proper configuration
RUN dockerd \
    --host=unix:///var/run/docker.sock \
    --host=tcp://0.0.0.0:2376 \
    --storage-driver=vfs \
    --iptables=false \
    --pidfile=/var/run/docker.pid \
    --exec-root=/var/run/docker \
    --data-root=/var/lib/docker \
    --debug & \
    sleep 15 && \
    docker info

# Copy source and backend Dockerfile
COPY --from=source /src/epagneul/backend /build/backend
COPY backend/Dockerfile /build/backend/Dockerfile

# Build backend image with Docker daemon running
RUN dockerd \
    --host=unix:///var/run/docker.sock \
    --host=tcp://0.0.0.0:2376 \
    --storage-driver=vfs \
    --iptables=false \
    --pidfile=/var/run/docker.pid \
    --exec-root=/var/run/docker \
    --data-root=/var/lib/docker \
    --debug & \
    sleep 15 && \
    cd /build/backend && \
    docker build -t bukshee/epagneul-backend:latest . && \
    mkdir -p /out && \
    docker save bukshee/epagneul-backend:latest -o /out/epagneul-backend.tar && \
    pkill dockerd || true

# =========================
# Stage 3 - Frontend image build
# =========================
FROM docker:24-dind AS frontend-builder

# Enable Docker daemon to run in background
ENV DOCKER_TLS_CERTDIR=""
ENV DOCKER_HOST=unix:///var/run/docker.sock

WORKDIR /build

# Copy source and frontend Dockerfile
COPY --from=source /src/epagneul/frontend /build/frontend
COPY frontend/Dockerfile /build/frontend/Dockerfile

# Build frontend image with Docker daemon running
RUN dockerd \
    --host=unix:///var/run/docker.sock \
    --host=tcp://0.0.0.0:2376 \
    --storage-driver=vfs \
    --iptables=false \
    --pidfile=/var/run/docker.pid \
    --exec-root=/var/run/docker \
    --data-root=/var/lib/docker \
    --debug & \
    sleep 15 && \
    cd /build/frontend && \
    docker build -t bukshee/epagneul-frontend:latest . && \
    mkdir -p /out && \
    docker save bukshee/epagneul-frontend:latest -o /out/epagneul-frontend.tar && \
    pkill dockerd || true

# =========================
# Stage 4 - Final Kasm image
# =========================
FROM kasmweb/ubuntu-noble-dind:1.17.0
USER root

ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    libnotify-bin \
    python3 \
    python3-pip \
    netcat-openbsd && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy prebuilt tarballs from previous stages
RUN mkdir -p /opt/epagneul-images
COPY --from=backend-builder /out/epagneul-backend.tar /opt/epagneul-images/epagneul-backend.tar
COPY --from=frontend-builder /out/epagneul-frontend.tar /opt/epagneul-images/epagneul-frontend.tar

# Create docker-compose file with health checks
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml <<'EOF'
services:
  backend:
    image: bukshee/epagneul-backend:latest
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-backend"
    ports:
      - "8000:8000"
    depends_on:
      - neo4j
    networks:
      - epagneul-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  frontend:
    image: bukshee/epagneul-frontend:latest
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-frontend"
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks:
      - epagneul-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  neo4j:
    image: neo4j:4.4.2
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-neo4j"
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/password
      - NEO4J_apoc_export_file_enabled=true
      - NEO4J_apoc_import_file_enabled=true
      - NEO4J_dbms_memory_heap_initial__size=512m
      - NEO4J_dbms_memory_heap_max__size=1G
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
      - neo4j_import:/import
    networks:
      - epagneul-net
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
  epagneul-net:
    name: "${COMPOSE_PROJECT_NAME:-epagneul}_network"
    driver: bridge
EOF

# Pre-pull Neo4j image during build (with proper Docker daemon setup)
RUN export DOCKER_TLS_CERTDIR="" && \
    dockerd \
        --host=unix:///var/run/docker.sock \
        --host=tcp://0.0.0.0:2376 \
        --storage-driver=vfs \
        --iptables=false \
        --pidfile=/var/run/docker.pid \
        --exec-root=/var/run/docker \
        --data-root=/var/lib/docker \
        --debug & \
    sleep 15 && \
    docker pull neo4j:4.4.2 && \
    docker save neo4j:4.4.2 -o /opt/epagneul-images/neo4j.tar && \
    pkill dockerd || true && \
    sleep 5

# Copy optimized startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Create health check script
RUN cat > /usr/local/bin/epagneul-health-check <<'EOF'
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

# Fix permissions
RUN chown -R 1000:0 /epagneul /opt/epagneul-images && \
    mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
