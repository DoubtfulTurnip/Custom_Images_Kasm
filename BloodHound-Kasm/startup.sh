#!/bin/sh
echo "Starting BloodHound..."

echo "Acquiring Collectors and starting BloodHound..."
git clone https://github.com/BloodHoundAD/BloodHound.git $HOME/Desktop/BLOODHOUND \
&& mv $HOME/Desktop/BLOODHOUND/Collectors $HOME/Desktop/Bloodhound-Collectors \
&& rm $HOME/Desktop/Collectors/AzureHound.md \
&& rm -rf $HOME/Desktop/BLOODHOUND \
&& sleep 5s \
&& /opt/BloodHound-linux-x64/BloodHound --no-sandbox




