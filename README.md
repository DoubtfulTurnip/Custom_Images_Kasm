# Custom Images for Kasm

Very messy dockerfiles for [Kasm](https://www.kasmweb.com/)

I can almost guarantee there is a better way to do what I have done here but I am but a simple mind

## Dockerfile

You can build the image from scratch but I will be pushing the images to Docker Hub when possible

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
sudo docker build -t {application-name}:latest -f Custom_Image_Kasm/{application-name}/dockerfile_custom_{application-name} .
``

Remove the workspace-images folder if no longer required and then configure your new Kasm Workspace with the {application-name}:latest image that you have just built

## Docker Hub

Find the application repository below and add this to the Workspace "Docker Image" field


## Current projects in this repo

* [LogonTracer](https://github.com/JPCERTCC/LogonTracer)
  
  [Docker Hub](https://hub.docker.com/r/bukshee/logontracer)
  
* [Spiderfoot](https://github.com/smicallef/spiderfoot)

