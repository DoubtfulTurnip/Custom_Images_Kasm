# =========================
# Stage 1 - Source fetch
# =========================
FROM alpine/git AS source
WORKDIR /src
RUN git clone --depth=1 https://github.com/jurelou/epagneul.git

# =========================
# Stage 2 - Backend build
# =========================
FROM python:3.8-slim AS backend
WORKDIR /app

# Install build deps for lxml + evtx (Rust) + scipy
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ make libffi-dev libssl-dev python3-dev \
    libxml2-dev libxslt1-dev zlib1g-dev curl \
    rustc cargo && \
    rm -rf /var/lib/apt/lists/*

# Copy backend source
COPY --from=source /src/epagneul/backend /app

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

ENV HOME=/home/kasm-user \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Runtime deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq libnotify-bin python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Copy prebuilt backend + frontend from earlier stages
COPY --from=backend /app /epagneul-backend
COPY --from=frontend /app /epagneul-frontend

# Provide docker-compose file (no "build:", only images/volumes/networks)
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

# Permissions
RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME

