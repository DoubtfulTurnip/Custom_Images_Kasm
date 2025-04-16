#!/bin/sh
# Custom startup script for Epagneul in a full desktop environment using Google Chrome.

# Start the Docker service if it's not already running.
sudo service docker start

# Display a desktop notification to inform the user.
notify-send -t 60000 "Epagneul is starting" "Please wait while Epagneul services are being deployed."

# Change to the Epagneul directory.
cd /epagneul

# Generate a unique project name using the current timestamp.
PROJECT_NAME="workspace_$(date +%s)"

# Start all the services using the unique project name.
docker compose -p "$PROJECT_NAME" -f docker-compose-prod.yml up -d

# Wait for the services to start.
sleep 60

# Notify the user that Epagneul has started.
notify-send -t 60000 "Epagneul has started"

# Open the interface in Google Chrome.
google-chrome --start-maximized http://localhost:8080/ &
