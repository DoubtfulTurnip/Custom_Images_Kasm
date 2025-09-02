FROM kasmweb/ubuntu-noble-dind:1.17.0

USER root

# Set Kasm environment variables
ENV HOME=/home/kasm-default-profile \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$STARTUPDIR/install
WORKDIR $HOME

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        jq \
        libnotify-bin \
        netcat-openbsd \
        python3 \
        python3-pip && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Create Epagneul directory and clone source
RUN mkdir -p /epagneul && \
    git clone https://github.com/jurelou/epagneul.git /epagneul-source && \
    chown -R 1000:0 /epagneul /epagneul-source

# Create a simple compose file for runtime
RUN cat > /epagneul/docker-compose-prod.yml << 'EOF'
version: '3.8'
services:
  backend:
    build:
      context: /epagneul-source
      dockerfile: backend/Dockerfile
    ports:
      - "8000:8000"
    depends_on:
      - neo4j
    networks:
      - backend
    restart: unless-stopped
  frontend:
    build:
      context: /epagneul-source  
      dockerfile: frontend/Dockerfile
    ports:
      - "8080:8080"
    depends_on:
      - backend
    networks:
      - backend
    restart: unless-stopped
  neo4j:
    image: neo4j:4.4-community
    ports:
      - "7474:7474"
      - "7687:7687"
    environment:
      - NEO4J_AUTH=neo4j/password
    volumes:
      - neo4j_data:/data
    networks:
      - backend
    restart: unless-stopped
volumes:
  neo4j_data:
networks:
  backend:
EOF

# Copy startup script
COPY custom_startup_epagneul.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Create health check script using standard approach
RUN echo '#!/bin/bash' > /usr/local/bin/epagneul-health-check && \
    echo 'curl -sf http://localhost:8080 >/dev/null 2>&1 && echo "Healthy" || echo "Not ready"' >> /usr/local/bin/epagneul-health-check && \
    chmod +x /usr/local/bin/epagneul-health-check

# Add container health check
HEALTHCHECK --interval=30s --timeout=15s --start-period=180s --retries=3 \
    CMD /usr/local/bin/epagneul-health-check

# Fix permissions
RUN chown -R 1000:0 /epagneul && \
    chown 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

# Switch to persistent user profile
ENV HOME=/home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
