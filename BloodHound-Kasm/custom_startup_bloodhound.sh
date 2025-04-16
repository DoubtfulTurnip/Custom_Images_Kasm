#!/bin/sh
# Custom startup script for BloodHound CE in a full desktop environment using Google Chrome.

# Start Docker service if it’s not already running.
sudo service docker start

# Display a desktop notification to inform the user.
notify-send -t 60000 "BloodHound is starting" "Please wait while BloodHound services are being deployed."

# Change to the BloodHound directory.
cd /bloodhound

# Generate a unique project name using the current timestamp.
PROJECT_NAME="bloodhound_$(date +%s)"


# Start the services using the unique project name.
docker compose -p "$PROJECT_NAME" up -d

# Give the services time to start.
sleep 60

# Retrieve the BloodHound initial password from the logs.
BLOODHOUND_PASS=$(docker compose -p "$PROJECT_NAME" logs | grep "Initial Password Set To:" | head -n 1 | awk -F'Initial Password Set To:' '{print $2}' | awk -F'#' '{print $1}' | xargs)

# If a password was found, save it to the user's desktop.
if [ -n "$BLOODHOUND_PASS" ]; then
    printf "BloodHound Password: %s" "$BLOODHOUND_PASS" > /home/kasm-user/Desktop/BloodHound_Password.txt
fi

# Notify the user that BloodHound has started.
notify-send -t 60000 "BloodHound has started" "The initial password is located on the desktop."

# Launch BloodHound in Google Chrome.
google-chrome --start-maximized http://localhost:8080/ui/login &
