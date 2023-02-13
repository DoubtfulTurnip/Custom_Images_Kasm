#!/bin/sh
echo "Starting LogonTracer..."

sleep 20s

cd /home/kasm-user/LogonTracer-Kasm/ && python3 logontracer.py -r -o 8080 -u neo4j -p neo4j -s localhost &

sleep 10s

echo "Starting Firefox..."


firefox --new-window --kiosk http://localhost:8080
