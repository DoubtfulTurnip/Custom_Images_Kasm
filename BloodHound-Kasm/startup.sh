#!/bin/sh
echo "Starting LogonTracer..."

sleep 20s

cd /home/kasm-user/bloodhound-Kasm/ && ./bloudhound.bin --no-sandbox &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:7474
