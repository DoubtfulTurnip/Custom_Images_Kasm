FROM kasmweb/ubuntu-noble-dind:1.17.0

USER root

# Set Kasm environment variables
ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

######### Customize Container Here ###########

# Create a working folder for BloodHound and download the docker-compose YAML file.
RUN mkdir -p /epagneul && \
    git clone https://github.com/jurelou/epagneul.git /epagneul
    

RUN apt-get update && apt-get install -y --no-install-recommends libnotify-bin

    
# Copy the custom startup script into the container.
COPY custom_startup_epagnuel.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh

######### End Customizations ###########

# Fix permissions for Kasm's default profile.
RUN chown 1000:0 $HOME && \
    $STARTUPDIR/set_user_permission.sh $HOME

# Switch HOME to the persistent user profile.
ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000

