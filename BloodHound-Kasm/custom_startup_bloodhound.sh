#!/bin/sh
# Custom startup script for BloodHound CE in a full desktop environment using Google Chrome.

sudo service docker start

# Display a desktop notification to inform the user.
notify-send -t 60000 "BloodHound is starting" "Please wait while BloodHound services are being deployed."

cd /bloodhound

docker compose up -d

sleep 60

BLOODHOUND_PASS=$(docker compose logs | grep "Initial Password Set To:" | head -n 1 | awk -F'Initial Password Set To:' '{print $2}' | awk -F'#' '{print $1}' | xargs)

if [ -n "$BLOODHOUND_PASS" ]; then
    printf "BloodHound Password: %s" "$BLOODHOUND_PASS" > /home/kasm-user/Desktop/BloodHound_Password.txt
fi

google-chrome --start-maximized http://localhost:8080/ui/login &