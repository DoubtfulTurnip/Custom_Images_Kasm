#!/bin/sh
echo "Starting BloodHound..."

echo "Acquiring Collectors and starting BloodHound..."
git clone https://github.com/BloodHoundAD/BloodHound.git $HOME/Desktop/BLOODHOUND \
&& mv $HOME/Desktop/BLOODHOUND/Collectors $HOME/Desktop/ \
&& rm $HOME/Desktop/Collectors/AzureHound.md \
&& rm -rf $HOME/Desktop/BLOODHOUND \
&& sleep 5s \
&& chmod +x $HOME/bloodhound-kasm/BloodHound \
&& $HOME/bloodhound-kasm/BloodHound --no-sandbox 




