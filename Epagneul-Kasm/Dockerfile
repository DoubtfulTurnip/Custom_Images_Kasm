# =========================
# Stage 1 - Source fetch
# =========================
FROM alpine/git AS source
WORKDIR /src
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git

# =========================
# Stage 2 - Backend build
# =========================
FROM python:3.11-slim AS backend
WORKDIR /app

# Install build deps for Python packages (lxml, evtx needs Rust)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev curl \
    rustc cargo && \
    rm -rf /var/lib/apt/lists/*

# Copy backend source
COPY --from=source /src/epagneul/backend /app

# Patch invalid evtx version (if still pinned to 0.7.2)
RUN sed -i 's/evtx==0.7.2/evtx==0.7.3/' setup.py

# Install backend via setup.py
RUN pip install --no-cache-dir .

CMD ["uvicorn", "epagneul.api.app:app", "--host", "0.0.0.0", "--port", "8000"]



# =========================
# Stage 3 - Frontend build
# =========================
FROM node:18 AS frontend
WORKDIR /app
COPY --from=source /src/epagneul/frontend /app
RUN npm install
CMD ["npm", "run", "serve"]

# =========================
# Stage 4 - Final Kasm image
# =========================
FROM kasmweb/ubuntu-noble-dind:1.17.0
USER root

# Kasm environment
ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq libnotify-bin python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy built contexts
COPY --from=backend /app /epagneul-backend
COPY --from=frontend /app /epagneul-frontend

# Preload docker images inside DinD
RUN docker build -t epagneul-backend /epagneul-backend && \
    docker build -t epagneul-frontend /epagneul-frontend && \
    docker pull neo4j:4.4.2

# Compose file using prebuilt images
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml << 'EOF'
version: '3.8'
services:
  neo4j:
    image: neo4j:4.4.2
    container_name: neo4j
    restart: unless-stopped
    ports:
      - 7474:7474
      - 7687:7687
    environment:
      - NEO4J_AUTH=neo4j/password
      - NEO4J_dbms_security_procedures_unrestricted=algo.*,gds.*,apoc.*
      - NEO4J_apoc_import_file_enabled=true
    volumes:
      - neo4j_data:/data
    networks:
      - backend

  backend:
    image: epagneul-backend
    container_name: backend
    restart: unless-stopped
    ports:
      - 8000:8000
    depends_on:
      - neo4j
    networks:
      - backend
    command: ["uvicorn", "epagneul.api.app:app", "--host", "0.0.0.0", "--port", "8000"]

  frontend:
    image: epagneul-frontend
    container_name: frontend
    restart: unless-stopped
    ports:
      - 8080:8080
    depends_on:
      - backend
    networks:
      - backend

volumes:
  neo4j_data:

networks:
  backend:
EOF

# Copy startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Permissions
RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
