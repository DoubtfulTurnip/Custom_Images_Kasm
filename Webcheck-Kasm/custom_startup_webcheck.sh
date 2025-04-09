#!/bin/bash
# Custom startup script for single-app Webcheck using Firefox

# Wait for the Kasm desktop environment to be fully ready.
# (This is needed so that your startup commands run after the environment loads.)
/usr/bin/desktop_ready && \

# Start the webcheck development server in the background.
# Make sure the repository is cloned at /web-check.
yarn dev --cwd /web-check &

# Wait a few seconds to allow the dev server to initialize.
sleep 5 && \

# Launch Firefox in kiosk mode to display the webcheck UI.
firefox --kiosk http://localhost:3000 &
