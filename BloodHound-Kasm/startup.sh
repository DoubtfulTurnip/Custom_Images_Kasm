#!/bin/sh
echo "Starting BloodHound..."

#Download BH collectors
wget https://github.com/BloodHoundAD/AzureHound/releases/latest/download/azurehound-linux-amd64.zip \
    && unzip azurehound-linux-amd64.zip \
    && rm azurehound-linux-amd64.zip \
    && mv azurehound /usr/bin

git clone https://github.com/BloodHoundAD/BloodHound.git $HOME/Desktop/BLOODHOUND
mv $HOME/Desktop/BLOODHOUND/Collectors $HOME/Desktop/ 
rm -rf $HOME/Desktop/BLOODHOUND

sleep 5s

cd /home/kasm-user/bloodhound-kasm/ && ./bloudhound.bin --no-sandbox &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:7474
