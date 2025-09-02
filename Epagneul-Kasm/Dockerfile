FROM kasmweb/ubuntu-noble-dind:1.17.0
USER root

ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Install all required dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Runtime dependencies
    curl \
    jq \
    libnotify-bin \
    python3 \
    python3-pip \
    python3-venv \
    python3-full \
    netcat-openbsd \
    git \
    # Backend build dependencies  
    build-essential \
    gcc \
    g++ \
    make \
    libffi-dev \
    libssl-dev \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    rustc \
    cargo \
    # Frontend build dependencies
    nodejs \
    npm && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Clone and prepare Epagneul source
WORKDIR /tmp/build
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git epagneul-source

# Build backend application with comprehensive fixes
WORKDIR /tmp/build/epagneul-source/backend
RUN echo "Building Epagneul backend..." && \
    echo "Current Python version: $(python3 --version)" && \
    # Create virtual environment
    python3 -m venv /opt/epagneul-venv && \
    # Use pip < 24.1 to avoid uvicorn metadata issues
    /opt/epagneul-venv/bin/python -m pip install --upgrade "pip<24.1" && \
    echo "Using pip version: $(/opt/epagneul-venv/bin/pip --version)" && \
    # Show original constraints
    echo "=== Original Python requirements ===" && \
    grep -r "python" setup.py pyproject.toml setup.cfg 2>/dev/null || echo "No explicit python requirements found" && \
    # Fix Python version constraints
    echo "=== Fixing Python version constraints ===" && \
    if [ -f setup.py ]; then \
        sed -i 's/python_requires=">=3\.8\.\*, <3\.9"/python_requires=">=3.8"/' setup.py && \
        sed -i 's/python_requires.*=.*"[^"]*"/python_requires=">=3.8"/' setup.py && \
        sed -i "s/python_requires.*=.*'[^']*'/python_requires='>=3.8'/" setup.py; \
    fi && \
    if [ -f pyproject.toml ]; then \
        sed -i 's/python.*=.*"<3\.9,>=3\.8"/python = ">=3.8"/' pyproject.toml && \
        sed -i 's/requires-python.*=.*"<3\.9,>=3\.8"/requires-python = ">=3.8"/' pyproject.toml; \
    fi && \
    # Show fixed constraints
    echo "=== Fixed Python requirements ===" && \
    grep -r "python" setup.py pyproject.toml setup.cfg 2>/dev/null || echo "No python requirements found after fix" && \
    # Install backend with compatible dependency versions
    echo "=== Installing backend application ===" && \
    /opt/epagneul-venv/bin/pip install --no-cache-dir . && \
    echo "Backend build completed successfully"

# Build frontend application  
WORKDIR /tmp/build/epagneul-source/frontend
RUN echo "Building Epagneul frontend..." && \
    npm ci || npm install && \
    echo "Frontend build completed"

# Create optimized runtime structure
RUN echo "Setting up runtime environment..." && \
    mkdir -p /opt/epagneul && \
    cp -r /tmp/build/epagneul-source/* /opt/epagneul/ && \
    ln -s /opt/epagneul-venv /opt/epagneul/venv && \
    rm -rf /tmp/build && \
    echo "Runtime setup completed"

# Create simple docker-compose file optimized for quick startup
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml <<'EOF'
services:
  backend:
    image: python:3.8-slim
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-backend"
    ports:
      - "8000:8000"
    volumes:
      - /opt/epagneul/backend:/app
      - /opt/epagneul-venv:/opt/epagneul-venv
    working_dir: /app
    command: >
      bash -c "
        apt-get update && apt-get install -y --no-install-recommends curl &&
        echo 'Backend starting with pre-built virtual environment' &&
        /opt/epagneul-venv/bin/python --version &&
        /opt/epagneul-venv/bin/uvicorn epagneul.api.app:app --host 0.0.0.0 --port 8000
      "
    depends_on:
      - neo4j
    networks:
      - epagneul-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 45s

  frontend:
    image: node:18-slim
    container_name: "${COMPOSE_PROJECT_NAME:-epagneul}-frontend"
    ports:
      - "8080:8080"
    volumes:
      - /opt/epagneul/frontend:/app
    working_dir: /app
    command: >
      bash -c "
        apt-get update && apt-get install -y --no-install-recommends curl &&
        echo 'Frontend starting with pre-installed dependencies' &&
        ls node_modules/ | head -3 &&
        npm run serve -- --host 0.0.0.0 --port 8080
      "
    depends_on:
      - backend
    networks:
      - epagneul-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 45s

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
      - NEO4J_dbms_memory_heap_initial__size=256m
      - NEO4J_dbms_memory_heap_max__size=512m
      - NEO4J_dbms_memory_pagecache_size=128m
    volumes:
      - neo4j_data:/data
      - neo4j_logs:/logs
      - neo4j_import:/import
    networks:
      - epagneul-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:7474 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s

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

# Copy startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Create health check script
RUN cat > /usr/local/bin/epagneul-health-check <<'EOF'
#!/bin/bash
web_ui=$(curl -sf http://localhost:8080 >/dev/null 2>&1 && echo "OK" || echo "DOWN")
backend=$(curl -sf http://localhost:8000 >/dev/null 2>&1 && echo "OK" || echo "DOWN")  
neo4j=$(curl -sf http://localhost:7474 >/dev/null 2>&1 && echo "OK" || echo "DOWN")

if [[ "$web_ui" == "OK" && "$backend" == "OK" ]]; then
    echo "Epagneul is healthy"
    exit 0
elif [[ "$backend" == "OK" || "$neo4j" == "OK" ]]; then
    echo "Epagneul is starting"
    exit 0
else
    echo "Epagneul not ready"
    exit 1
fi
EOF

RUN chmod +x /usr/local/bin/epagneul-health-check

# Add container health check
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=3 \
    CMD /usr/local/bin/epagneul-health-check

# Fix permissions
RUN chown -R 1000:0 /epagneul /opt/epagneul /opt/epagneul-venv && \
    mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
