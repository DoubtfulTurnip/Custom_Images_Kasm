#!/bin/sh
echo "Starting Spiderfoot..."

sleep 20s

cd /home/kasm-user/spiderfoot/ && python3 sf.py &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:8080
