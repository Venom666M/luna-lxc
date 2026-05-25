#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Luna: Absolute Cinema - LXC Install Script (běží uvnitř containeru)
# License: MIT

# Načtení helper funkcí předaných přes proměnné prostředí
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
STAGING="${STAGING:-false}"
set -euo pipefail

# Konstanty
LUNA_VERSION="1.4.3"
LUNA_BINARY="luna-linux-amd64"
LUNA_URL="https://webshare.cz/api/file/q1oSHbCPl2/luna-linux-amd64-1-4-3"
LUNA_DIR="/opt/luna"
LUNA_PORT="7126"
LUNA_HTTPS_PORT="7127"
LUNA_USER="luna"

# Barvy (fallback pokud nejsou nastaveny)
BL='\033[1;34m'
GN='\033[1;32m'
YW='\033[33m'
RD='\033[1;31m'
CL='\033[0m'

msg_info() { echo -e "${BL}[INFO]${CL} $1"; }
msg_ok()   { echo -e "${GN}[OK]${CL} $1"; }
msg_error(){ echo -e "${RD}[CHYBA]${CL} $1"; }

# ────────────────────────────────────────────
# 1. Aktualizace systému
# ────────────────────────────────────────────
msg_info "Aktualizuji systémové balíčky"
apt-get update -qq &>/dev/null
apt-get upgrade -y -qq &>/dev/null
msg_ok "Systém aktualizován"

# ────────────────────────────────────────────
# 2. Instalace závislostí
# ────────────────────────────────────────────
msg_info "Instaluji závislosti (curl, ca-certificates)"
apt-get install -y -qq \
  curl \
  ca-certificates \
  wget \
  &>/dev/null
msg_ok "Závislosti nainstalovány"

# ────────────────────────────────────────────
# 3. Stažení Luna binary
# ────────────────────────────────────────────
msg_info "Vytvářím adresář ${LUNA_DIR}"
mkdir -p "${LUNA_DIR}"
msg_ok "Adresář vytvořen"

msg_info "Stahuji Luna ${LUNA_VERSION} binary"

# Primární zdroj: Webshare přímý odkaz  
DOWNLOAD_SUCCESS=false

# Pokus 1: Přímý odkaz z Webshare
if curl -fsSL --retry 3 --retry-delay 2 \
   "https://webshare.cz/api/file/q1oSHbCPl2/luna-linux-amd64-1-4-3" \
   -o "${LUNA_DIR}/${LUNA_BINARY}" 2>/dev/null; then
  DOWNLOAD_SUCCESS=true
  msg_ok "Luna stažena z Webshare"
fi

# Pokus 2: Fallback - wget
if [ "$DOWNLOAD_SUCCESS" = false ]; then
  msg_info "Zkouším alternativní stažení..."
  if wget -q --tries=3 \
     "https://webshare.cz/api/file/q1oSHbCPl2/luna-linux-amd64-1-4-3" \
     -O "${LUNA_DIR}/${LUNA_BINARY}" 2>/dev/null; then
    DOWNLOAD_SUCCESS=true
    msg_ok "Luna stažena (wget)"
  fi
fi

if [ "$DOWNLOAD_SUCCESS" = false ]; then
  msg_error "Nepodařilo se stáhnout Luna binary!"
  msg_error "Zkontrolujte připojení nebo stáhněte manuálně z:"
  msg_error "https://webshare.cz/#/file/q1oSHbCPl2/luna-linux-amd64-1-4-3"
  msg_error "a uložte do: ${LUNA_DIR}/${LUNA_BINARY}"
  exit 1
fi

# ────────────────────────────────────────────
# 4. Nastavení oprávnění
# ────────────────────────────────────────────
msg_info "Nastavuji oprávnění pro Luna binary"
chmod +x "${LUNA_DIR}/${LUNA_BINARY}"
msg_ok "Oprávnění nastavena"

# ────────────────────────────────────────────
# 5. Vytvoření systemd service
# ────────────────────────────────────────────
msg_info "Vytvářím systemd service"

cat > /etc/systemd/system/luna.service << EOF
[Unit]
Description=Luna Absolute Cinema Server
Documentation=https://webshare.cz
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${LUNA_DIR}
ExecStart=${LUNA_DIR}/${LUNA_BINARY} --https --port ${LUNA_PORT} --https-port ${LUNA_HTTPS_PORT}
Restart=always
RestartSec=5
StartLimitInterval=0
StandardOutput=journal
StandardError=journal
SyslogIdentifier=luna

# Bezpečnostní omezení
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${LUNA_DIR}

[Install]
WantedBy=multi-user.target
EOF

msg_ok "systemd service vytvořena"

# ────────────────────────────────────────────
# 6. Aktivace a spuštění služby
# ────────────────────────────────────────────
msg_info "Aktivuji a spouštím Luna službu"
systemctl daemon-reload
systemctl enable luna.service &>/dev/null
systemctl start luna.service
sleep 3
msg_ok "Luna služba spuštěna"

# ────────────────────────────────────────────
# 7. MOTD (zpráva při přihlášení)
# ────────────────────────────────────────────
msg_info "Nastavuji MOTD"

CONTAINER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "zjistěte-ip-ručně")

cat > /etc/motd << EOF

  ╔════════════════════════════════════════════════╗
  ║        Luna: Absolute Cinema Server            ║
  ║              verze ${LUNA_VERSION}                        ║
  ╠════════════════════════════════════════════════╣
  ║  HTTP port:   ${LUNA_PORT}                              ║
  ║  HTTPS port:  ${LUNA_HTTPS_PORT}                              ║
  ╠════════════════════════════════════════════════╣
  ║  Správa služby:                                ║
  ║    systemctl status luna                       ║
  ║    systemctl restart luna                      ║
  ║    journalctl -u luna -f                       ║
  ╠════════════════════════════════════════════════╣
  ║  Stremio addon URL (LAN):                      ║
  ║    https://IP-ADRESA-POMLCKY.local-ip:${LUNA_HTTPS_PORT}   ║
  ╚════════════════════════════════════════════════╝

EOF

msg_ok "MOTD nastaveno"

# ────────────────────────────────────────────
# 8. Výsledná zpráva
# ────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GN}═══════════════════════════════════════════════${CL}"
echo -e "${GN}   Luna: Absolute Cinema úspěšně nainstalován!${CL}"
echo -e "${GN}═══════════════════════════════════════════════${CL}"
echo ""
echo -e "  ${YW}IP adresa containeru:${CL}  ${GN}${IP}${CL}"
echo -e "  ${YW}HTTP port:${CL}             ${GN}${LUNA_PORT}${CL}"
echo -e "  ${YW}HTTPS port:${CL}            ${GN}${LUNA_HTTPS_PORT}${CL}"
echo ""
echo -e "  ${YW}Pro Stremio LAN addon použij:${CL}"

# Převod IP na local-ip.co formát (192.168.1.100 → 192-168-1-100)
IP_DASHES=$(echo "$IP" | tr '.' '-')
echo -e "  ${GN}https://${IP_DASHES}.local-ip.co:${LUNA_HTTPS_PORT}${CL}"
echo ""
echo -e "  ${YW}Stav služby:${CL}"
systemctl is-active luna.service && echo -e "  ${GN}● Luna běží${CL}" || echo -e "  ${RD}✗ Luna neběží - zkontroluj: journalctl -u luna -f${CL}"
echo ""
