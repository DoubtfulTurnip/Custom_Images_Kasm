#!/bin/sh
echo "Starting BloodHound..."

#Download BH collectors

echo "Acquiring Collectors..."
git clone https://github.com/BloodHoundAD/BloodHound.git $HOME/Desktop/BLOODHOUND
mv $HOME/Desktop/BLOODHOUND/Collectors $HOME/Desktop/ 
rm $HOME/Desktop/Collectors/AzureHound.md
rm -rf $HOME/Desktop/BLOODHOUND

sleep 5s

chmod +x $HOME/bloodhound-kasm/BloodHound
$HOME/bloodhound-kasm/BloodHound --no-sandbox 




