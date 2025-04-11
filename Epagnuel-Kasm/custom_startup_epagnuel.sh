#!/bin/sh
# Custom startup script for Epagneul in a full desktop environment using Google Chrome.

sudo service docker start

# Display a desktop notification to inform the user.
notify-send -t 60000 "Epagneul is starting" "Please wait while Epagneul services are being deployed."

cd /epagneul

docker compose -f docker-compose-prod.yml up -d

sleep 60



notify-send -t 60000 "Epagneul has started" 

google-chrome --start-maximized http://localhost:8080/ &