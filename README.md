# Windows Server VM Deployment Script for Proxmox
 
## Introduction
This Bash script automates the creation of a Windows Server 2022 virtual machine on Proxmox VE. It provides an interactive setup using Whiptail, allowing users to configure VM settings easily. 

-> inspired by https://github.com/community-scripts/ProxmoxVE

##

![Example Default settings](/images/defaultSettingStart.png)

##

To use this script on your own Proxmox VE server, you need to copy this line into your proxmox terminal (with root privileges):

> [!IMPORTANT]
> The script change if you are using Proxmox VE 9 or Proxmox VE 8. Please check the script name before running it.


for Proxmox **VE 8.x**:
```bash
    bash -c "$(wget -qLO - https://raw.githubusercontent.com/cedev-1/WindowsServer-Proxmox-HelperScript/main/windows-server-vm.sh)"
```

for Proxmox **VE 9.x**:
```bash
    bash -c "$(wget -qLO - https://raw.githubusercontent.com/cedev-1/WindowsServer-Proxmox-HelperScript/main/windows-server-vm-proxmox-9.sh)"
```

##

### You can help me to improve this script, report bugs or request new features by creating an issue on this repository.

## Future Improvements

- [x] Add support for Proxmox VE 9
- [ ] Add multi-language support (with multi ISO download)
- [ ] Add support for Windows Server 2024 / 2025
- [ ] Add full auto mode
- [ ] Add Client possibility
- [ ] Add more...