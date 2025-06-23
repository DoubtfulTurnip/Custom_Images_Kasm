FROM kasmweb/ubuntu-noble-desktop:1.17.0

USER root

# Set Kasm environment variables
ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

########## Install System Dependencies ##########
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-pip \
        python3-venv \
        curl \
        git \
        libnotify-bin && \
    rm -rf /var/lib/apt/lists/*

########## Copy and Prepare App ##########
COPY . /app
WORKDIR /app

# Create Python virtual environment
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Upgrade pip and install dependencies (including Streamlit)
RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt streamlit

# Install TruffleHog v3.89.2 as binary
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | \
    sh -s -- -b /usr/local/bin v3.89.2

# Ensure kasm-user can access /app
RUN chown -R 1000:0 /app

########## Kasm Custom Startup ##########
COPY custom_startup_trufflehog.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

# Fix permissions for default profile
RUN chown 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

# Switch to persistent user profile
ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
# No CMD needed; Kasm will run custom_startup.sh
