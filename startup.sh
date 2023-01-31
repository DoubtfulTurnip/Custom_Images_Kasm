#!/bin/sh
echo "Starting LogonTracer..."


cd /home/kasm-user/LogonTracer/ && python3 logontracer.py -r -o 8080 -u neo4j -p neo4j -s localhost

sleep 10s

firefox --new-window http://localhost:8080

