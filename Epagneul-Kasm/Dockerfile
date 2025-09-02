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
WORKDIR /build/backend
COPY --from=source /src/epagneul/backend /build/backend
COPY backend/Dockerfile ./Dockerfile
RUN docker build -t bukshee/epagneul-backend:latest .
RUN mkdir -p /out && docker save bukshee/epagneul-backend:latest -o /out/epagneul-backend.tar

# =========================
# Stage 3 - Frontend image build
# =========================
FROM docker:24-dind AS frontend-builder
WORKDIR /build/frontend
COPY --from=source /src/epagneul/frontend /build/frontend
COPY frontend/Dockerfile ./Dockerfile
RUN docker build -t bukshee/epagneul-frontend:latest .
RUN mkdir -p /out && docker save bukshee/epagneul-frontend:latest -o /out/epagneul-frontend.tar

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

# Copy prebuilt tarballs
RUN mkdir -p /opt/epagneul-images
COPY --from=backend-builder /out/epagneul-backend.tar /opt/epagneul-images/epagneul-backend.tar
COPY --from=frontend-builder /out/epagneul-frontend.tar /opt/epagneul-images/epagneul-frontend.tar

# Provide docker-compose file
RUN mkdir -p /epagneul && \
    cat > /epagneul/docker-compose-prod.yml <<'EOF'
services:
  backend:
    image: bukshee/epagneul-backend:latest
    ports:
      - "8000:8000"
    depends_on:
      - neo4j
    networks: [epagneul-net]

  frontend:
    image: bukshee/epagneul-frontend:latest
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks: [epagneul-net]
    command: ["npm", "run", "serve", "--", "--host", "0.0.0.0"]

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

# Copy optimized startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Fix permissions
RUN mkdir -p $HOME && chown -R 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

USER 1000
WORKDIR $HOME
