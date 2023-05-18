# Custom Images for Kasm

Source files for my custom [Kasm](https://www.kasmweb.com/) images.


## Dockerfile

Each (working) application has a single-app and desktop version available for build. The single-app version is the one I push to dockerhub.

Read the Custom Images section from [Kasm's documentation](https://www.kasmweb.com/docs/latest/how_to/building_images.html)


``
git clone https://github.com/kasmtech/workspaces-images.git
``

``
cd workspaces-images
``

``
git clone https://github.com/DoubtfulTurnip/Custom_Images_Kasm.git
``

``
sudo docker build -t {application-name}:latest -f Custom_Image_Kasm/{application-name}/dockerfile_custom_{application-name}_{singleapp/desktopapp} .
``

Remove the workspace-images folder if no longer required and then configure your new Kasm Workspace with the {application-name}:latest image that you have just built.


## Doubful Turnip Kasm Registry

For a simpler time just add the Doubtful Turnip registry to your Kasm instance. [Kasm's documentation](https://kasmweb.com/docs/develop/guide/workspace_registry.html)

Just add the DoubtfulTurnip 3rd party registry to your Kasm instance

https://doubtfulturnip.github.io/doubtful-kasm-registry/



## Docker Hub

Find the application repository below and add this to the Workspace "Docker Image" field


## Current projects in this repo

* [LogonTracer](https://github.com/JPCERTCC/LogonTracer)
  
  [Docker Hub](https://hub.docker.com/r/bukshee/logontracer-kasm)
  
* [Spiderfoot](https://github.com/smicallef/spiderfoot)

  [Docker Hub](https://hub.docker.com/r/bukshee/spiderfoot-kasm)
  
* [BloodHound](https://github.com/BloodHoundAD/BloodHound)

  [Docker Hub](https://hub.docker.com/r/bukshee/bloodhound-kasm)

