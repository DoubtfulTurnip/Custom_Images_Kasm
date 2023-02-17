#!/bin/sh
echo "Starting BloodHound..."
sleep 30s \
&& /opt/BloodHound-linux-x64/BloodHound --no-sandbox &
