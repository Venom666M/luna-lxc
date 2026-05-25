#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║          Luna: Absolute Cinema - Proxmox LXC Installer      ║
# ║                    Standalone verze                          ║
# ║  Spusť v Proxmox shellu:                                     ║
# ║    bash -c "$(curl -fsSL <URL_TOHOTO_SCRIPTU>)"             ║
# ╚══════════════════════════════════════════════════════════════╝
# Autor: Radeg / community
# Licence: MIT

set -euo pipefail

# ══════════════════ KONFIGURACE ══════════════════
APP="Luna: Absolute Cinema"
LUNA_VERSION="1.4.3"
LUNA_BINARY="luna-linux-amd64"
LUNA_PORT="7126"
LUNA_HTTPS_PORT="7127"
LUNA_DIR="/opt/luna"

# Výchozí LXC nastavení
CT_ID=""           # prázdné = auto (další volné)
CT_HOSTNAME="luna"
CT_RAM="128"       # MiB
CT_CORES="1"
CT_DISK="2"        # GB
CT_OS_TEMPLATE=""  # prázdné = auto-detect
CT_BRIDGE="vmbr0"
CT_IP="dhcp"       # nebo "192.168.1.100/24"
CT_GW=""           # brána pro statické IP
CT_UNPRIVILEGED=1
CT_TAGS="media;stremio;webshare;luna"

# ══════════════════ BARVY ══════════════════
BL='\033[1;34m'
GN='\033[1;32m'
YW='\033[1;33m'
RD='\033[1;31m'
CY='\033[0;36m'
BOLD='\033[1m'
CL='\033[0m'

# ══════════════════ HELPER FUNKCE ══════════════════
msg_info()  { echo -e "  ${BL}◆${CL} $1"; }
msg_ok()    { echo -e "  ${GN}✔${CL} ${BOLD}$1${CL}"; }
msg_warn()  { echo -e "  ${YW}⚠${CL} $1"; }
msg_error() { echo -e "  ${RD}✘${CL} ${BOLD}$1${CL}"; }
msg_title() { echo -e "\n${BOLD}${CY}  ── $1 ──${CL}"; }

# ══════════════════ BANNER ══════════════════
header_info() {
  clear
  echo -e "${CY}"
  cat << "EOF"
 ██╗     ██╗   ██╗███╗   ██╗ █████╗ 
 ██║     ██║   ██║████╗  ██║██╔══██╗
 ██║     ██║   ██║██╔██╗ ██║███████║
 ██║     ██║   ██║██║╚██╗██║██╔══██║
 ███████╗╚██████╔╝██║ ╚████║██║  ██║
 ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
EOF
  echo -e "${CL}"
  echo -e "  ${BOLD}Absolute Cinema${CL} — Proxmox LXC Installer"
  echo -e "  Stremio addon + WebShare.cz media server"
  echo -e "  verze ${LUNA_VERSION}\n"
  echo -e "  ${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}\n"
}

# ══════════════════ KONTROLY ══════════════════
check_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    msg_error "Spusť skript jako root!"
    exit 1
  fi
}

check_proxmox() {
  if ! command -v pveversion &>/dev/null; then
    msg_error "Tento skript je určen pro Proxmox VE!"
    exit 1
  fi
}

check_pve_version() {
  local PVE_VER
  PVE_VER="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"
  msg_ok "Detekována Proxmox VE ${PVE_VER}"
}

# ══════════════════ VÝBĚR TEMPLATE ══════════════════
get_os_template() {
  msg_info "Hledám dostupný Debian 12 template..."
  
  # Pokus najít existující template
  local TMPL
  TMPL=$(pveam list local 2>/dev/null | grep "debian-12" | awk '{print $1}' | head -1)
  
  if [ -z "$TMPL" ]; then
    # Template není stažen – stáhneme
    msg_info "Template nenalezen, stahuji debian-12-standard..."
    pveam update &>/dev/null
    local AVAIL
    AVAIL=$(pveam available --section system 2>/dev/null | grep "debian-12-standard" | awk '{print $2}' | head -1)
    if [ -z "$AVAIL" ]; then
      msg_error "Nelze najít debian-12-standard template!"
      exit 1
    fi
    pveam download local "$AVAIL" &>/dev/null
    TMPL="local:vztmpl/${AVAIL}"
    msg_ok "Template stažen: ${AVAIL}"
  else
    msg_ok "Template nalezen: ${TMPL}"
  fi
  
  CT_OS_TEMPLATE="$TMPL"
}

# ══════════════════ INTERAKTIVNÍ MENU (whiptail) ══════════════════
show_menu() {
  if ! command -v whiptail &>/dev/null; then
    msg_warn "whiptail není dostupný, používám výchozí nastavení"
    return
  fi
  
  CHOICE=$(whiptail --backtitle "Luna: Absolute Cinema LXC Installer" \
    --title "🌙 LUNA LXC INSTALLER" \
    --menu "\nZvol typ instalace:\n" 18 65 3 \
    "1" "⚡ Výchozí nastavení  (doporučeno)" \
    "2" "⚙️  Pokročilé nastavení (vlastní IP, port...)" \
    "3" "❌ Zrušit" \
    --default-item "1" 3>&1 1>&2 2>&3) || true

  case "$CHOICE" in
    1)
      echo -e "\n${GN}  → Výchozí nastavení${CL}"
      ;;
    2)
      advanced_menu
      ;;
    3|"")
      echo -e "\n${YW}  Instalace zrušena.${CL}\n"
      exit 0
      ;;
  esac
}

advanced_menu() {
  # Container ID
  NEXT_ID=$(pvesh get /cluster/nextid 2>/dev/null || echo "200")
  if CT_ID=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "Container ID" 8 50 "$NEXT_ID" \
    --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    [[ -z "$CT_ID" ]] && CT_ID="$NEXT_ID"
  fi
  
  # Hostname
  if HN=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "Hostname" 8 50 "$CT_HOSTNAME" \
    --title "HOSTNAME" 3>&1 1>&2 2>&3); then
    [[ -n "$HN" ]] && CT_HOSTNAME="$HN"
  fi
  
  # RAM
  if RAM=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "RAM v MiB (doporučeno: 128)" 8 50 "$CT_RAM" \
    --title "RAM" 3>&1 1>&2 2>&3); then
    [[ -n "$RAM" ]] && CT_RAM="$RAM"
  fi

  # Disk
  if DISK=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "Disk v GB (doporučeno: 2)" 8 50 "$CT_DISK" \
    --title "DISK" 3>&1 1>&2 2>&3); then
    [[ -n "$DISK" ]] && CT_DISK="$DISK"
  fi
  
  # HTTP Port
  if PORT=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "Luna HTTP port (výchozí: ${LUNA_PORT})" 8 50 "$LUNA_PORT" \
    --title "HTTP PORT" 3>&1 1>&2 2>&3); then
    [[ -n "$PORT" ]] && LUNA_PORT="$PORT"
  fi

  # HTTPS Port
  if HPORT=$(whiptail --backtitle "Luna LXC Installer" \
    --inputbox "Luna HTTPS port (výchozí: ${LUNA_HTTPS_PORT})" 8 50 "$LUNA_HTTPS_PORT" \
    --title "HTTPS PORT" 3>&1 1>&2 2>&3); then
    [[ -n "$HPORT" ]] && LUNA_HTTPS_PORT="$HPORT"
  fi

  # Síť
  NET_CHOICE=$(whiptail --backtitle "Luna LXC Installer" \
    --title "SÍŤOVÁ KONFIGURACE" \
    --menu "Zvolte metodu přidělení IP:" 12 55 2 \
    "dhcp"   "DHCP (automaticky, doporučeno)" \
    "static" "Statická IP adresa" \
    3>&1 1>&2 2>&3) || true
  
  if [[ "$NET_CHOICE" == "static" ]]; then
    if STATIC_IP=$(whiptail --backtitle "Luna LXC Installer" \
      --inputbox "Statická IPv4 (např. 192.168.1.50/24)" 8 55 "" \
      --title "STATICKÁ IP" 3>&1 1>&2 2>&3); then
      [[ -n "$STATIC_IP" ]] && CT_IP="$STATIC_IP"
    fi
    if GW=$(whiptail --backtitle "Luna LXC Installer" \
      --inputbox "Brána (gateway, např. 192.168.1.1)" 8 55 "" \
      --title "BRÁNA" 3>&1 1>&2 2>&3); then
      [[ -n "$GW" ]] && CT_GW=",gw=$GW"
    fi
  fi
}

# ══════════════════ SOUHRN NASTAVENÍ ══════════════════
show_summary() {
  local NEXT_ID_DEFAULT
  NEXT_ID_DEFAULT=$(pvesh get /cluster/nextid 2>/dev/null || echo "auto")
  local DISPLAY_ID="${CT_ID:-$NEXT_ID_DEFAULT}"
  
  echo -e "\n${BOLD}${CY}  ╔══ NASTAVENÍ LXC CONTAINERU ══════════════╗${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Container ID:${CL}   ${GN}${DISPLAY_ID}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Hostname:${CL}       ${GN}${CT_HOSTNAME}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}OS:${CL}             ${GN}Debian 12 (Bookworm)${CL}"
  echo -e "  ${CY}║${CL}  ${YW}CPU jádra:${CL}      ${GN}${CT_CORES}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}RAM:${CL}            ${GN}${CT_RAM} MiB${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Disk:${CL}           ${GN}${CT_DISK} GB${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Síť:${CL}            ${GN}${CT_IP}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Bridge:${CL}         ${GN}${CT_BRIDGE}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Luna HTTP:${CL}      ${GN}:${LUNA_PORT}${CL}"
  echo -e "  ${CY}║${CL}  ${YW}Luna HTTPS:${CL}     ${GN}:${LUNA_HTTPS_PORT}${CL}"
  echo -e "  ${CY}╚═══════════════════════════════════════════╝${CL}\n"
}

# ══════════════════ VYTVOŘENÍ LXC ══════════════════
create_lxc() {
  msg_title "Vytváření LXC Containeru"
  
  # Auto-detect CT_ID pokud není nastaveno
  if [ -z "$CT_ID" ]; then
    CT_ID=$(pvesh get /cluster/nextid 2>/dev/null || echo "200")
  fi
  
  get_os_template

  msg_info "Vytvářím LXC container ${CT_ID} (${CT_HOSTNAME})..."

  # Sestavení příkazu
  local NET_OPTS="-net0 name=eth0,bridge=${CT_BRIDGE},ip=${CT_IP}${CT_GW}"
  
  pct create "${CT_ID}" "${CT_OS_TEMPLATE}" \
    --hostname "${CT_HOSTNAME}" \
    --cores "${CT_CORES}" \
    --memory "${CT_RAM}" \
    --rootfs "local-lvm:${CT_DISK}" \
    --unprivileged "${CT_UNPRIVILEGED}" \
    --features "keyctl=1,nesting=1" \
    --onboot 1 \
    --tags "${CT_TAGS}" \
    ${NET_OPTS} \
    --start 0 \
    &>/dev/null

  msg_ok "Container ${CT_ID} vytvořen"
  
  msg_info "Spouštím container..."
  pct start "${CT_ID}"
  
  # Čekání na start
  local RETRIES=0
  until pct exec "${CT_ID}" -- bash -c "true" &>/dev/null || [[ $RETRIES -ge 15 ]]; do
    sleep 2
    ((RETRIES++))
  done
  
  msg_ok "Container spuštěn"
}

# ══════════════════ INSTALACE LUNA DO CONTAINERU ══════════════════
install_luna() {
  msg_title "Instalace Luna do Containeru ${CT_ID}"
  
  # Inline install script spuštěný uvnitř containeru
  pct exec "${CT_ID}" -- bash -c "
set -euo pipefail

BL='\033[1;34m'; GN='\033[1;32m'; YW='\033[1;33m'; RD='\033[1;31m'; CL='\033[0m'; BOLD='\033[1m'
msg_info() { echo -e \"  \${BL}◆\${CL} \$1\"; }
msg_ok()   { echo -e \"  \${GN}✔\${CL} \${BOLD}\$1\${CL}\"; }
msg_error(){ echo -e \"  \${RD}✘\${CL} \${BOLD}\$1\${CL}\"; }

LUNA_DIR='${LUNA_DIR}'
LUNA_BINARY='${LUNA_BINARY}'
LUNA_PORT='${LUNA_PORT}'
LUNA_HTTPS_PORT='${LUNA_HTTPS_PORT}'
LUNA_VERSION='${LUNA_VERSION}'

# Aktualizace systému
msg_info 'Aktualizuji systém...'
apt-get update -qq &>/dev/null
apt-get install -y -qq curl ca-certificates wget &>/dev/null
msg_ok 'Systém připraven'

# Stažení Luna
msg_info 'Stahuji Luna ${LUNA_VERSION}...'
mkdir -p \"\${LUNA_DIR}\"

# Pokus 1: přímý download
DOWNLOAD_OK=false
if curl -fsSL --retry 3 --retry-delay 3 \
   'https://webshare.cz/api/file/q1oSHbCPl2/luna-linux-amd64-1-4-3' \
   -o \"\${LUNA_DIR}/\${LUNA_BINARY}\" 2>/dev/null; then
  # Ověření, zda je soubor spustitelný binárka (ne HTML chybová stránka)
  if file \"\${LUNA_DIR}/\${LUNA_BINARY}\" 2>/dev/null | grep -qi 'ELF\|executable'; then
    DOWNLOAD_OK=true
    msg_ok 'Luna binary stažena (curl)'
  fi
fi

# Pokus 2: wget
if [ \"\$DOWNLOAD_OK\" = false ]; then
  if wget -q --tries=3 \
     'https://webshare.cz/api/file/q1oSHbCPl2/luna-linux-amd64-1-4-3' \
     -O \"\${LUNA_DIR}/\${LUNA_BINARY}\" 2>/dev/null; then
    if file \"\${LUNA_DIR}/\${LUNA_BINARY}\" 2>/dev/null | grep -qi 'ELF\|executable'; then
      DOWNLOAD_OK=true
      msg_ok 'Luna binary stažena (wget)'
    fi
  fi
fi

if [ \"\$DOWNLOAD_OK\" = false ]; then
  echo -e \"\"
  echo -e \"  \${YW}⚠ Automatické stažení selhalo!\"
  echo -e \"  Webshare vyžaduje přihlášení nebo změnil API.\"
  echo -e \"  \"
  echo -e \"  MANUÁLNÍ POSTUP:\"
  echo -e \"  1. Stáhni soubor: https://webshare.cz/#/file/q1oSHbCPl2/luna-linux-amd64-1-4-3\"
  echo -e \"  2. Zkopíruj ho do containeru:\"
  echo -e \"     pct push ${CT_ID} luna-linux-amd64 \${LUNA_DIR}/\${LUNA_BINARY}\"
  echo -e \"  3. Spusť: pct exec ${CT_ID} -- chmod +x \${LUNA_DIR}/\${LUNA_BINARY}\"
  echo -e \"  4. Spusť: pct exec ${CT_ID} -- systemctl start luna\${CL}\"
  echo -e \"  \"
  # Vytvoří placeholder pro pokračování nastavení
  echo '#!/bin/bash' > \"\${LUNA_DIR}/\${LUNA_BINARY}\"
  echo 'echo Luna binary nenalezena - viz MOTD' >> \"\${LUNA_DIR}/\${LUNA_BINARY}\"
fi

# Oprávnění
chmod +x \"\${LUNA_DIR}/\${LUNA_BINARY}\"
msg_ok 'Oprávnění nastavena'

# systemd service
msg_info 'Vytvářím systemd service...'
cat > /etc/systemd/system/luna.service << 'SVCEOF'
[Unit]
Description=Luna Absolute Cinema Server
Documentation=https://github.com/Emperix
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=LUNA_DIR_PLACEHOLDER
ExecStart=LUNA_DIR_PLACEHOLDER/LUNA_BINARY_PLACEHOLDER --https --port LUNA_PORT_PLACEHOLDER --https-port LUNA_HTTPS_PORT_PLACEHOLDER
Restart=always
RestartSec=5
StartLimitInterval=0
StandardOutput=journal
StandardError=journal
SyslogIdentifier=luna
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=LUNA_DIR_PLACEHOLDER

[Install]
WantedBy=multi-user.target
SVCEOF

# Nahrazení placeholderů
sed -i 's|LUNA_DIR_PLACEHOLDER|'\"${LUNA_DIR}\"'|g' /etc/systemd/system/luna.service
sed -i 's|LUNA_BINARY_PLACEHOLDER|'\"${LUNA_BINARY}\"'|g' /etc/systemd/system/luna.service
sed -i 's|LUNA_PORT_PLACEHOLDER|'\"${LUNA_PORT}\"'|g' /etc/systemd/system/luna.service
sed -i 's|LUNA_HTTPS_PORT_PLACEHOLDER|'\"${LUNA_HTTPS_PORT}\"'|g' /etc/systemd/system/luna.service

systemctl daemon-reload
systemctl enable luna.service &>/dev/null

if [ \"\$DOWNLOAD_OK\" = true ]; then
  systemctl start luna.service
  sleep 3
  msg_ok 'Luna service spuštěna'
else
  msg_ok 'Luna service nakonfigurována (čeká na binary)'
fi

# MOTD
IP=\$(hostname -I | awk '{print \$1}' 2>/dev/null || echo 'NEZNAMA')
IP_DASHES=\$(echo \"\$IP\" | tr '.' '-')

cat > /etc/motd << MOTDEOF

  ╔══════════════════════════════════════════════════╗
  ║        🌙 Luna: Absolute Cinema Server           ║
  ║                  v\${LUNA_VERSION}                          ║
  ╠══════════════════════════════════════════════════╣
  ║  HTTP port:   \${LUNA_PORT}                                ║
  ║  HTTPS port:  \${LUNA_HTTPS_PORT}  (pro Stremio LAN addon)   ║
  ╠══════════════════════════════════════════════════╣
  ║  Stremio LAN URL:                                ║
  ║  https://\${IP_DASHES}.local-ip.co:\${LUNA_HTTPS_PORT}         ║
  ╠══════════════════════════════════════════════════╣
  ║  Příkazy:                                        ║
  ║    systemctl status luna                         ║
  ║    systemctl restart luna                        ║
  ║    journalctl -u luna -f                         ║
  ╚══════════════════════════════════════════════════╝

MOTDEOF

echo '' > /etc/issue
msg_ok 'MOTD nastaveno'
"

  msg_ok "Luna nainstalována v containeru ${CT_ID}"
}

# ══════════════════ ZÁVĚREČNÁ ZPRÁVA ══════════════════
show_result() {
  local CT_IP_RESULT
  CT_IP_RESULT=$(pct exec "${CT_ID}" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "neznámá")
  local IP_DASHES
  IP_DASHES=$(echo "$CT_IP_RESULT" | tr '.' '-')
  
  echo -e "\n${GN}${BOLD}"
  echo -e "  ╔══════════════════════════════════════════════════╗"
  echo -e "  ║   ✅  Luna LXC úspěšně nainstalována!           ║"
  echo -e "  ╚══════════════════════════════════════════════════╝${CL}"
  echo ""
  echo -e "  ${YW}Container ID:${CL}   ${GN}${CT_ID}${CL}"
  echo -e "  ${YW}Hostname:${CL}       ${GN}${CT_HOSTNAME}${CL}"
  echo -e "  ${YW}IP adresa:${CL}      ${GN}${CT_IP_RESULT}${CL}"
  echo ""
  echo -e "  ${YW}Stremio LAN addon URL:${CL}"
  echo -e "  ${GN}https://${IP_DASHES}.local-ip.co:${LUNA_HTTPS_PORT}${CL}"
  echo ""
  echo -e "  ${YW}Správa:${CL}"
  echo -e "  ${CY}pct enter ${CT_ID}${CL}                  — vstup do containeru"
  echo -e "  ${CY}pct exec ${CT_ID} -- systemctl status luna${CL}"
  echo -e "  ${CY}pct exec ${CT_ID} -- journalctl -u luna -f${CL}"
  echo ""
  echo -e "  ${YW}⚠️  Nezapomeň nakonfigurovat Luna v Stremio!${CL}"
  echo -e "  ${YW}   (přihlašení přes web UI na HTTPS adrese výše)${CL}"
  echo ""
}

# ══════════════════ HLAVNÍ PRŮBĚH ══════════════════
main() {
  header_info
  check_root
  check_proxmox
  check_pve_version
  
  show_menu
  show_summary
  
  # Potvrzení
  if command -v whiptail &>/dev/null; then
    if ! whiptail --backtitle "Luna LXC Installer" \
      --yesno "Vytvořit Luna LXC container s výše uvedeným nastavením?" \
      8 60; then
      echo -e "\n${YW}  Instalace zrušena.${CL}\n"
      exit 0
    fi
  else
    echo -ne "  Pokračovat? [y/N]: "
    read -r CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && { echo -e "\n  Zrušeno.\n"; exit 0; }
  fi
  
  create_lxc
  install_luna
  show_result
}

main "$@"
