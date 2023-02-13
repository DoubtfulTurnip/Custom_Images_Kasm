#!/bin/sh
echo "Starting BloodHound..."

sleep 20s

cd /home/kasm-user/bloodhound-kasm/ && ./bloudhound.bin --no-sandbox &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:7474
