#!/bin/sh

sudo neo4j start

sleep 30s

cd /home/kasm-user/LogonTracer/ && python3 logontracer.py -r -o 8080 -u neo4j -p neo4j -s localhost &


sleep 5s

echo "Starting Firefox..."


firefox --new-window http://localhost:8080

