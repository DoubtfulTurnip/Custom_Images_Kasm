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

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev rustc cargo && \
    rm -rf /var/lib/apt/lists/*

COPY --from=source /src/epagneul/backend /app

RUN sed -i 's/>=3\.8\.\*/>=3.8/' setup.py && \
    pip install --upgrade "pip<24.1" && \
    pip install --no-cache-dir .

# Save backend environment into tarball
RUN mkdir -p /out && tar -cf /out/epagneul-backend.tar -C /app .

# =========================
# Stage 3 - Frontend build
# =========================
FROM node:18 AS frontend
WORKDIR /app
COPY --from=source /src/epagneul/frontend /app

RUN npm ci || npm install

# Save frontend app into tarball
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq libnotify-bin python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy tarballs
RUN mkdir -p /opt/epagneul-images
COPY --from=backend /out/epagneul-backend.tar /opt/epagneul-images/epagneul-backend.tar
COPY --from=frontend /out/epagneul-frontend.tar /opt/epagneul-images/epagneul-frontend.tar

# Provide docker-compose
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml <<'EOF'
services:
  backend:
    image: epagneul-backend:latest
    build: /app
    ports:
      - "8000:8000"
    depends_on: [neo4j]
    networks: [epagneul-net]

  frontend:
    image: epagneul-frontend:latest
    build: /app
    ports:
      - "8080:8080"
    depends_on: [backend]
    networks: [epagneul-net]

  neo4j:
    image: neo4j:4.4.2
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/password
    volumes: [neo4j_data:/data]
    networks: [epagneul-net]

volumes:
  neo4j_data:

networks:
  epagneul-net:
    driver: bridge
EOF

COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
