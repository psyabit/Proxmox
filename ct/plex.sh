#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/psyabit/Proxmox/main/misc/install.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
    ____  __             __  ___         ___          _____                          
   / __ \/ /__  _  __   /  |/  /__  ____/ (_)___ _   / ___/___  ______   _____  _____
  / /_/ / / _ \| |/_/  / /|_/ / _ \/ __  / / __ `/   \__ \/ _ \/ ___/ | / / _ \/ ___/
 / ____/ /  __/>  <   / /  / /  __/ /_/ / / /_/ /   ___/ /  __/ /   | |/ /  __/ /    
/_/   /_/\___/_/|_|  /_/  /_/\___/\__,_/_/\__,_/   /____/\___/_/    |___/\___/_/     
                                                                                      
EOF
}
header_info
echo -e "Loading..."
APP="Plex"
var_disk="8"
var_cpu="2"
var_ram="2048"
var_os="ubuntu"
var_version="22.04"
nfs_server="192.168.1.250"  # Hier IP deines NFS-Servers anpassen
nfs_share="/nfs/tank/media"      # Hier den Pfad zum NFS-Share anpassen
nfs_mount_point="/mnt/media"  # Ziel-Verzeichnis im Container
container_id="903"          # Hier die ID des Containers anpassen
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE="192.168.1.1"
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
if [[ ! -f /etc/apt/sources.list.d/plexmediaserver.list ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
UPD=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --radiolist --cancel-button Exit-Script "Spacebar = Select \nplexupdate info >> https://github.com/mrworf/plexupdate" 10 59 2 \
  "1" "Update LXC" ON \
  "2" "Install plexupdate" OFF \
  3>&1 1>&2 2>&3)

header_info
if [ "$UPD" == "1" ]; then
msg_info "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated ${APP} LXC"
exit
fi
if [ "$UPD" == "2" ]; then
set +e
bash -c "$(wget -qO - https://raw.githubusercontent.com/mrworf/plexupdate/master/extras/installer.sh)"
exit
fi
}

function enable_nfs_for_lxc() {
  # NFS für den LXC-Container aktivieren
  msg_info "Enabling NFS support for LXC container"

  # AppArmor-Profil kopieren und anpassen
  cp -i /etc/apparmor.d/lxc/lxc-default-cgns /etc/apparmor.d/lxc/lxc-default-with-nfs
  sed -i 's/profile lxc-container-default-cgns/profile lxc-container-default-with-nfs/' /etc/apparmor.d/lxc/lxc-default-with-nfs

  # NFS-Konfiguration zum AppArmor-Profil hinzufügen
  echo -e "\n  mount fstype=nfs,\n  mount fstype=nfs4,\n  mount fstype=nfsd,\n  mount fstype=rpc_pipefs,\n}" >> /etc/apparmor.d/lxc/lxc-default-with-nfs

  # AppArmor neu laden
  systemctl reload apparmor
  msg_ok "NFS configuration applied to AppArmor"

  # Profil im LXC-Container konfigurieren
  echo "lxc.apparmor.profile: lxc-container-default-with-nfs" >> /etc/pve/lxc/${container_id}.conf

  # Container neu starten
  pct stop ${container_id} && pct start ${container_id}
  msg_ok "NFS enabled for LXC container ${container_id}"
}


start
build_container
enable_nfs_for_lxc
setup_fstab_mount_in_lxc
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
             ${BL}http://${IP}:32400/web${CL}\n"
