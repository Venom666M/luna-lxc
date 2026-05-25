#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Luna: Absolute Cinema LXC Install Script
# License: MIT
# https://github.com/community-scripts/ProxmoxVE

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# App konfigurace
APP="Luna: Absolute Cinema"
var_tags="media;stremio;webshare"
var_cpu="1"
var_ram="128"
var_disk="2"
var_os="debian"
var_version="12"
var_unprivileged="1"

# Úvodní banner
header_info() {
  clear
  cat <<"EOF"
    __                    
   / /   __  ______  ____ _
  / /   / / / / __ \/ __ `/
 / /___/ /_/ / / / / /_/ / 
/_____/\__,_/_/ /_/\__,_/  
                            
  Absolute Cinema Server - Proxmox LXC Installer
EOF
}

header_info
echo -e "Načítám funkce..."
variables
color
catch_errors

# Spuštění instalačního procesu
start
