#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# Modified by ChatGPT for Homarr Docker version
# License: MIT

function header_info {
clear
cat <<"EOF"
    __  __
   / / / /___  ____ ___  ____ ___________
  / /_/ / __ \/ __ `__ \/ __ `/ ___/ ___/
 / __  / /_/ / / / / / / /_/ / /  / /
/_/ /_/\____/_/ /_/ /_/\__,_/_/  /_/

          Docker Version Installer
EOF
}
header_info
echo -e "Loading..."
APP="Homarr (Docker)"
var_disk="8"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
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
  GATE=""
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

function install_homarr_docker() {
  msg_info "Instaluję Dockera..."
  apt-get update -y
  apt-get install -y curl ca-certificates gnupg lsb-release
  curl -fsSL https://get.docker.com | sh
  msg_ok "Docker zainstalowany."

  msg_info "Tworzę katalog aplikacji Homarr..."
  mkdir -p /opt/homarr/appdata
  msg_ok "Katalog /opt/homarr/appdata utworzony."

  msg_info "Uruchamiam Homarr w Dockerze..."
  docker run -d \
    --name homarr \
    --restart unless-stopped \
    -p 7575:7575 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /opt/homarr/appdata:/appdata \
    -e SECRET_ENCRYPTION_KEY='137d0495f54d76c2dc3bb525b8dcbdb97171a38f3fd5701a34df36883cf5402f' \
    ghcr.io/homarr-labs/homarr:latest

  msg_ok "Homarr uruchomiony w Dockerze."
}

start
build_container
description
onfinish() {
  install_homarr_docker
  msg_ok "Instalacja zakończona pomyślnie!"
  echo -e "\nHomarr powinien być dostępny pod adresem:"
  echo -e "${BL}http://${IP}:7575${CL}\n"
}
onfinish




