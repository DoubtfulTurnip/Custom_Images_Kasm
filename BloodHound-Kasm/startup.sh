#!/bin/sh
echo "Starting BloodHound..."

#Download BH collectors
git clone https://github.com/BloodHoundAD/BloodHound.git $HOME/Desktop/BLOODHOUND
mv $HOME/Desktop/BLOODHOUND/Collectors $HOME/Desktop/ 
rm $HOME/Desktop/BLOODHOUND/Collectors/AzureHound.md
rm -rf $HOME/Desktop/BLOODHOUND

sleep 5s

bloudhound.bin --no-sandbox &

sleep 10s

echo "Starting Firefox..."


firefox --new-window http://localhost:7474
