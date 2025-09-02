# =========================
# Stage 1 - Fetch source
# =========================
FROM alpine/git AS source
WORKDIR /src
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git

# =========================
# Stage 2 - Backend build
# =========================
FROM python:3.8-slim AS backend
WORKDIR /app

# Build deps (for lxml, evtx, scipy, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev rustc cargo && \
    rm -rf /var/lib/apt/lists/*

# Copy backend source
COPY --from=source /src/epagneul/backend /app

# Patch python_requires and install with pinned pip (<24.1 required for uvicorn==0.14.0)
RUN sed -i 's/>=3\.8\.\*/>=3.8/' setup.py && \
    pip install --upgrade "pip<24.1" && \
    pip install --no-cache-dir .

# Save backend image as tarball
RUN mkdir -p /out && tar -cf /out/epagneul-backend.tar -C /app .

# =========================
# Stage 3 - Frontend build
# =========================
FROM node:18 AS frontend
WORKDIR /app
COPY --from=source /src/epagneul/frontend /app

# Install dependencies (lockfile-aware)
RUN npm ci || npm install

# Save frontend as tarball
RUN mkdir -p /out && tar -cf /out/epagneul-frontend.tar -C /app .

# =========================
# Stage 4 - Final Kasm image
# =========================
FROM kasmweb/ubuntu-noble-dind:1.17.0
USER root

ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq libnotify-bin python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy prebuilt backend + frontend tarballs
RUN mkdir -p /opt/epagneul-images
COPY --from=backend /out/epagneul-backend.tar /opt/epagneul-images/epagneul-backend.tar
COPY --from=frontend /out/epagneul-frontend.tar /opt/epagneul-images/epagneul-frontend.tar

# Provide docker-compose file (services reference prebuilt images)
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml << 'EOF'
version: "3.8"

services:
  backend:
    image: epagneul-backend:latest
    container_name: epagneul-backend
    ports:
      - "8000:8000"
    depends_on:
      - neo4j
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

# Copy optimized startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Fix permissions
RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
