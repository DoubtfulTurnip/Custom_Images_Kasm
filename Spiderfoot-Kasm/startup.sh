#!/bin/sh
echo "Starting Spiderfoot..."

sleep 5s

cd /home/kasm-user/spiderfoot/ && python3 sf.py -l 127.0.0.1:5001 &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:5001
