# =========================
# Stage 1 - Fetch source
# =========================
FROM alpine/git AS source
WORKDIR /src
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git

# =========================
# Stage 2 - Backend filesystem export
# =========================
FROM python:3.8-slim AS backend
WORKDIR /app

# Build deps (for lxml, evtx, scipy)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev rustc cargo && \
    rm -rf /var/lib/apt/lists/*

COPY --from=source /src/epagneul/backend /app
RUN pip install --no-cache-dir .

# Export filesystem snapshot (to import as image later)
RUN mkdir -p /out && tar -cf /out/epagneul-backend.tar -C / .

# =========================
# Stage 3 - Frontend filesystem export
# =========================
FROM node:18 AS frontend
WORKDIR /app
COPY --from=source /src/epagneul/frontend /app

# Install deps
RUN npm install

# Export filesystem snapshot
RUN mkdir -p /out && tar -cf /out/epagneul-frontend.tar -C / .

# =========================
# Stage 4 - Final Kasm image
# =========================
FROM kasmweb/ubuntu-noble-dind:1.17.0
USER root

ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq libnotify-bin python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy filesystem tars
RUN mkdir -p /opt/epagneul-images
COPY --from=backend /out/epagneul-backend.tar /opt/epagneul-images/epagneul-backend.tar
COPY --from=frontend /out/epagneul-frontend.tar /opt/epagneul-images/epagneul-frontend.tar

# Compose file (services use images imported from tar)
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml << 'EOF'
services:
  backend:
    image: epagneul-backend:latest
    container_name: epagneul-backend
    ports:
      - "8000:8000"
    networks:
      - epagneul-net
    restart: unless-stopped

  frontend:
    image: epagneul-frontend:latest
    container_name: epagneul-frontend
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks:
      - epagneul-net
    restart: unless-stopped
    command: ["npm", "run", "serve", "--", "--host", "0.0.0.0"]

  neo4j:
    image: neo4j:4.4.2
    container_name: epagneul-neo4j
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/password
    volumes:
      - neo4j_data:/data
    networks:
      - epagneul-net
    restart: unless-stopped

volumes:
  neo4j_data:

networks:
  epagneul-net:
    driver: bridge
EOF

# Copy startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
