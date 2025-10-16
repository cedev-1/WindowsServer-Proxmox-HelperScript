#!/usr/bin/env bash

function header_info {
  clear
  cat <<"EOF"
 _        ___           _                   ____                          ____   ___ ____  ____  
\ \      / (_)_ __   __| | _____      _____/ ___|  ___ _ ____   _____ _ _|___ \ / _ \___ \|___ \ 
 \ \ /\ / /| | '_ \ / _` |/ _ \ \ /\ / / __\___ \ / _ \ '__\ \ / / _ \ '__|__) | | | |__) | __) |
  \ V  V / | | | | | (_| | (_) \ V  V /\__ \___) |  __/ |   \ V /  __/ |  / __/| |_| / __/ / __/ 
   \_/\_/  |_|_| |_|\__,_|\___/ \_/\_/ |___/____/ \___|_|    \_/ \___|_| |_____|\___/_____|_____|

EOF
}
header_info
echo -e "\n Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')

NEXTID=$(pvesh get /cluster/nextid)

YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
HA=$(echo "\033[1;34m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
function error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
  cleanup_vmid
}

function cleanup_vmid() {
  if qm status $VMID &>/dev/null; then
    qm stop $VMID &>/dev/null
    qm destroy $VMID &>/dev/null
  fi
}

function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle "Proxmox VE" --title "Windows Server VM" --yesno "This will create a New Windows Server 2022 VM. Proceed?" 10 58; then
  :
else
  header_info && echo -e "⚠ User exited script \n" && exit
fi

function msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
  echo 
}



function msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
  echo
}

function msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# ROOT CHECK
function check_root() {
  if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
    clear
    msg_error "Please run this script as root."
    echo -e "\nExiting..."
    sleep 2
    exit
  fi
}

function pve_check() {
  if ! pveversion | grep -Eq "pve-manager/[6-9][0-9]*"; then
    msg_error "This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires Proxmox Virtual Environment Version 6.0 or later."
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

function arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    msg_error "This script will not work with PiMox! \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# SSH CHECK
function ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --backtitle "Proxmox VE" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

function exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

function default_settings() {
  VMID="$NEXTID"
  FORMAT=",efitype=4m"
  MACHINE=""
  DISK_CACHE=""
  NAME="windowsServer"
  CPU_TYPE=""
  CORES=4
  RAM=4096
  BRG="vmbr0"
  MAC="$GEN_MAC"
  VLAN=""
  MTU=""
  DISK_SIZE="64"
  echo -e "${DGN}Using Virtual Machine ID: ${BGN}${VMID}${CL}"
  echo -e "${DGN}Using Machine Type: ${BGN}i440fx${CL}"
  echo -e "${DGN}Using Disk Cache: ${BGN}None${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}${HN}${CL}"
  echo -e "${DGN}Using CPU Model: ${BGN}KVM64${CL}"
  echo -e "${DGN}Allocated Cores: ${BGN}${CORES}${CL}"
  echo -e "${DGN}Allocated RAM: ${BGN}${RAM}${CL}"
  echo -e "${DGN}Using Bridge: ${BGN}${BRG}${CL}"
  echo -e "${DGN}Using MAC Address: ${BGN}${MAC}${CL}"
  echo -e "${DGN}Using VLAN: ${BGN}Default${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${BL}Creating a Windows Server 2022 VM using the above default settings${CL}"
}

function advanced_settings() {
  while true; do
    if VMID=$(whiptail --backtitle "Proxmox VE" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
      if [ -z "$VMID" ]; then
        VMID="$NEXTID"
      fi
      if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
        echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
        sleep 2
        continue
      fi
      echo -e "${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
      break
    else
      exit-script
    fi
  done

  if DISK_SIZE=$(whiptail --backtitle "Proxmox VE" --inputbox "Set Disk Size in GB" 8 58 64 --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $DISK_SIZE ]; then
      DISK_SIZE="64"
      echo -e "${DGN}Allocated Disk Size: ${BGN}$DISK_SIZE${CL}"
    else
      echo -e "${DGN}Allocated Disk Size: ${BGN}$DISK_SIZE${CL}"
    fi
  else
    exit-script
  fi


  if MACH=$(whiptail --backtitle "Proxmox VE" --title "MACHINE TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
    "i440fx" "Machine i440fx" ON \
    "q35" "Machine q35" OFF \
    3>&1 1>&2 2>&3); then
    if [ $MACH = q35 ]; then
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=""
      MACHINE=" -machine q35"
    else
      echo -e "${DGN}Using Machine Type: ${BGN}$MACH${CL}"
      FORMAT=",efitype=4m"
      MACHINE=""
    fi
  else
    exit-script
  fi

  if DISK_CACHE=$(whiptail --backtitle "Proxmox VE" --title "DISK CACHE" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "None (Default)" ON \
    "1" "Write Through" OFF \
    3>&1 1>&2 2>&3); then
    if [ $DISK_CACHE = "1" ]; then
      echo -e "${DGN}Using Disk Cache: ${BGN}Write Through${CL}"
      DISK_CACHE="cache=writethrough,"
    else
      echo -e "${DGN}Using Disk Cache: ${BGN}None${CL}"
      DISK_CACHE=""
    fi
  else
    exit-script
  fi

  if VM_NAME=$(whiptail --backtitle "Proxmox VE" --inputbox "Set Hostname" 8 58 WindowsServer --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VM_NAME ]; then
      NAME="WindowsServer"
      echo -e "${DGN}Using Hostname: ${BGN}$NAME${CL}"
    else
      NAME=$(echo ${VM_NAME,,} | tr -d ' ')
      echo -e "${DGN}Using Hostname: ${BGN}$NAME${CL}"
    fi
  else
    exit-script
  fi

  if CPU_TYPE1=$(whiptail --backtitle "Proxmox VE" --title "CPU MODEL" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
    "0" "KVM64 (Default)" ON \
    "1" "Host" OFF \
    3>&1 1>&2 2>&3); then
    if [ $CPU_TYPE1 = "1" ]; then
      echo -e "${DGN}Using CPU Model: ${BGN}Host${CL}"
      CPU_TYPE=" -cpu host"
    else
      echo -e "${DGN}Using CPU Model: ${BGN}KVM64${CL}"
      CPU_TYPE=""
    fi
  else
    exit-script
  fi

  if CORES=$(whiptail --backtitle "Proxmox VE" --inputbox "Allocate CPU Cores" 8 58 4 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $CORES ]; then
      CORES="4"
      echo -e "${DGN}Allocated Cores: ${BGN}$CORES${CL}"
    else
      echo -e "${DGN}Allocated Cores: ${BGN}$CORES${CL}"
    fi
  else
    exit-script
  fi

  if RAM=$(whiptail --backtitle "Proxmox VE" --inputbox "Allocate RAM in MiB" 8 58 4096 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $RAM ]; then
      RAM="4096"
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM${CL}"
    else
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --backtitle "Proxmox VE" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $BRG ]; then
      BRG="vmbr0"
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  if MAC1=$(whiptail --backtitle "Proxmox VE" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC="$GEN_MAC"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC${CL}"
    else
      MAC="$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --backtitle "Proxmox VE" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    else
      VLAN=",tag=$VLAN1"
      echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
    fi
  else
    exit-script
  fi

  if MTU1=$(whiptail --backtitle "Proxmox VE" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    else
      MTU=",mtu=$MTU1"
      echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
    fi
  else
    exit-script
  fi

  if (whiptail --backtitle "Proxmox VE" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create a Windows Server 2022 VM?" --no-button Do-Over 10 58); then
    echo -e "${RD}Creating a Windows Server 2022 VM using the above advanced settings${CL}"
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

function start_script() {
  if (whiptail --backtitle "Proxmox VE" --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

check_root
arch_check
pve_check
ssh_check
start_script

msg_info "Validating Storage"
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{printf "%-10s", $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
  ITEM="  Type: $TYPE Free: $FREE "
  OFFSET=2
  if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
    MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
  fi
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')

if [ -z "$VALID" ]; then
  msg_error "Unable to detect a valid storage location."
  exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
  STORAGE=${STORAGE_MENU[0]}
else
  while [ -z "${STORAGE:+x}" ]; do
    STORAGE=$(whiptail --backtitle "Proxmox VE" --title "Storage Pools" --radiolist \
      "Which storage pool you would like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
      16 $(($MSG_MAX_LENGTH + 23)) 6 \
      "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
  done
fi

msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."

#------------------------------------------------------------------------------
ISO_STORAGE="local"
ISO_FILE="WindowsServer2022.iso"
VIRTIO_FILE="virtio-win.iso"

ISO_PATH="/var/lib/vz/template/iso/$ISO_FILE"
VIRTIO_PATH="/var/lib/vz/template/iso/$VIRTIO_FILE"

#----------------------------------------
#      Use this link to find iso
#----------------------------------------
# https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022
URL_ISO_WINDOWS="https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
URL_VIRTIO="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
#-------------  -----------------------------------------------------------------

msg_info "Checking Internet connectivity..."
if ! ping -c 1 google.com &>/dev/null; then
  msg_error "No Internet connection. Check your network."
  exit 1
fi

msg_info "Checking if Windows Server 2022 ISO is already downloaded..."
if ! pvesm list $ISO_STORAGE | grep -q $ISO_FILE; then
  msg_info "Downloading Windows Server 2022 ISO..."
  
  if ! wget --quiet --show-progress --tries=3 --timeout=30 -O "$ISO_PATH" "$URL_ISO_WINDOWS"; then
    msg_error "Failed to download Windows Server 2022 ISO. Please check the URL or your connection."
    exit 1
  fi
  
  msg_ok "Windows Server 2022 ISO downloaded: $ISO_PATH"
else
  msg_ok "Windows Server 2022 ISO already exists: $ISO_PATH"
fi

msg_info "Checking if VirtIO ISO is already downloaded..."
if ! pvesm list $ISO_STORAGE | grep -q $VIRTIO_FILE; then
  msg_info "Downloading VirtIO ISO..."
  
  if ! wget --quiet --show-progress --tries=3 --timeout=30 -O "$VIRTIO_PATH" "$URL_VIRTIO"; then
    msg_error "Failed to download VirtIO ISO. Please check the URL or your connection."
    exit 1
  fi

  msg_ok "VirtIO ISO downloaded: $VIRTIO_PATH"
else
  msg_ok "VirtIO ISO already exists: $VIRTIO_PATH"
fi

echo -en "\e[1A\e[0K"
msg_ok "All ISOs are downloaded successfully."

msg_info "Creating LVM Disk..."

if [[ -z "$VMID" || -z "$NAME" || -z "$BRG" || -z "$CORES" || -z "$RAM" || -z "$STORAGE" || -z "$DISK_SIZE" ]]; then
  msg_error "ERROR : Check your configuration."
  exit 1
fi

msg_info "Creating a Windows Server 2022 VM (${NAME})"
qm create $VMID \
  -agent 1 \
  ${MACHINE:+-machine $MACHINE} \
  -tablet 0 \
  -localtime 1 \
  -bios ovmf \
  ${CPU_TYPE:+-cpu $CPU_TYPE} \
  -cores $CORES \
  -memory $RAM \
  -name $NAME \
  -tags Windows-Server \
  -net0 virtio,bridge=$BRG,macaddr=$MAC${VLAN:+$VLAN}${MTU:+,mtu=$MTU}

msg_ok "VM ${NAME} (${VMID}) created successfully."

qm set $VMID --ide0 $ISO_STORAGE:iso/$ISO_FILE,media=cdrom
qm set $VMID --ide1 $ISO_STORAGE:iso/$VIRTIO_FILE,media=cdrom
qm set $VMID --serial0 socket
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --vga qxl
qm set $VMID --usb0 host=0627:0001,usb3=1


msg_info "Allocating Disk Size: ${DISK_SIZE} on Storage: ${STORAGE}"
qm set $VMID --sata0 "$STORAGE":$DISK_SIZE,format=raw

msg_ok "Installation completed successfully!"