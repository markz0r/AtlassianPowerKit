# Use the official PowerShell image as the base image
FROM mcr.microsoft.com/powershell:latest

# Set the working directory
WORKDIR /opt/osm/AtlassianPowerKit
ADD . .

# Install Git and required PowerShell modules
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /mnt/osm && \
    chmod 755 -R ./* && \
    pwsh -Command "Install-Module -Name PowerShellGet -Force" && \
    pwsh -Command "Install-Module -Name Microsoft.PowerShell.SecretManagement,Microsoft.PowerShell.SecretStore -Force"

# Set the OSM_HOME environment variable
ENV OSM_HOME=/mnt/osm

# Use CMD instead of ENTRYPOINT for overridable command
CMD ["pwsh", "./Run.ps1"]
