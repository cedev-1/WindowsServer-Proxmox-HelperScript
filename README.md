# Windows Server VM Deployment Script for Proxmox
 
## Introduction
This Bash script automates the creation of a Windows Server 2022 virtual machine on Proxmox VE. It provides an interactive setup using Whiptail, allowing users to configure VM settings easily. 

-> inspired by https://github.com/community-scripts/ProxmoxVE

##

![Example Default settings](/images/defaultSettingStart.png)

##

To use this script on your own Proxmox VE server, you need to copy this line into your proxmox terminal (with root privileges):

    bash -c "$(wget -qLO - https://raw.githubusercontent.com/cedev-1/WindowsServer-Proxmox-HelperScript/main/windows-server-vm.sh)"

##

### You can help me to improve this script, report bugs or request new features by creating an issue on this repository.