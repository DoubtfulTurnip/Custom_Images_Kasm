#!/bin/sh
echo "Starting BloodHound..."
sleep 60s \
&& neo4j-admin set-initial-password blood \
&& /opt/BloodHound-linux-x64/BloodHound --no-sandbox &
