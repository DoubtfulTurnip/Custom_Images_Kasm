#!/bin/sh
# Custom startup script for BloodHound CE in a full desktop environment using Google Chrome.

sleep 5 

sudo service docker start

# Display a desktop notification to inform the user.
notify-send -t 60000 "LogonTracer is starting" "Please wait while LogonTracer services are being deployed."

docker container run --detach --publish=7474:7474 --publish=7687:7687 --publish=8080:8080 -e LTHOSTNAME=127.0.0.1 jpcertcc/docker-logontracer

sleep 60

notify-send -t 30000 "LogonTracer has started" 

google-chrome --start-maximized http://127.0.0.1:8080 &