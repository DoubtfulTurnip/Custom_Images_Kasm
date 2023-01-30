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
RUN add-apt-repository -y ppa:openjdk-r/ppa
RUN apt-get update

#RUN wget https://dist.neo4j.org/cypher-shell/cypher-shell_5.4.0_all.deb \
#    && dpkg -i cypher-shell_5.4.0_all.deb
#RUN apt-get install openjdk-11-jre-headless java11-runtime-headless -y
#RUN wget https://dist.neo4j.org/deb/neo4j_4.4.16_all.deb  \
#    && dpkg -i neo4j_4.4.16_all.deb

RUN wget -O - https://debian.neo4j.com/neotechnology.gpg.key | sudo apt-key add - \
    && echo 'deb https://debian.neo4j.com stable 4.0' | sudo tee /etc/apt/sources.list.d/neo4j.list \
    && sudo apt-get update
RUN apt-get install neo4j -y

RUN apt-get install python3-pip -y
RUN git clone https://github.com/JPCERTCC/LogonTracer.git \
    && pip3 install -r LogonTracer/requirements.txt 
    
    
#ADD ./src/common/scripts $STARTUPDIR
RUN $STARTUPDIR/set_user_permission.sh $HOME

RUN chown 1000:0 $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER root

CMD ["--tail-log"]
