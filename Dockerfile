ARG BASE_TAG="develop"
ARG BASE_IMAGE="core-ubuntu-focal"
FROM kasmweb/$BASE_IMAGE:$BASE_TAG

USER root

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
WORKDIR $HOME

### Envrionment config
ENV DEBIAN_FRONTEND noninteractive
ENV KASM_RX_HOME $STARTUPDIR/kasmrx
ENV INST_SCRIPTS $STARTUPDIR/install

### Install Tools
COPY ./src/ubuntu/install/tools $INST_SCRIPTS/tools/
RUN bash $INST_SCRIPTS/tools/install_tools_deluxe.sh  && rm -rf $INST_SCRIPTS/tools/
# Install Utilities
COPY ./src/ubuntu/install/misc $INST_SCRIPTS/misc/
RUN bash $INST_SCRIPTS/misc/install_tools.sh && rm -rf $INST_SCRIPTS/misc/
# Install Firefox
COPY ./src/ubuntu/install/firefox/ $INST_SCRIPTS/firefox/
COPY ./src/ubuntu/install/firefox/firefox.desktop $HOME/Desktop/
RUN bash $INST_SCRIPTS/firefox/install_firefox.sh && rm -rf $INST_SCRIPTS/firefox/


##LOGONTRACER
#Configure Java
RUN add-apt-repository -y ppa:openjdk-r/ppa
RUN apt-get update

#Configure neo4j
RUN wget -O - https://debian.neo4j.com/neotechnology.gpg.key | apt-key add - \
    && echo 'deb https://debian.neo4j.com stable 4.0' | tee /etc/apt/sources.list.d/neo4j.list \
    && apt-get update
RUN apt-get install neo4j -y


#configure logontracer
RUN apt-get install python3-pip -y
RUN git clone https://github.com/JPCERTCC/LogonTracer.git \
    && pip3 install -r LogonTracer/requirements.txt 

CMD ["service", "neo4j", "start"]


    
#ADD ./src/common/scripts $STARTUPDIR
RUN $STARTUPDIR/set_user_permission.sh $HOME

RUN chown 0:0 $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 0:0 $HOME

USER 0



CMD ["--tail-log"]

