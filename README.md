# 🌙 Luna: Absolute Cinema — Proxmox LXC Installer

Automatický installer pro vytvoření LXC containeru s Luna serverem na Proxmox VE.
Inspirováno stylem [community-scripts.org](https://community-scripts.org).

---

## 🚀 Použití

### Metoda 1: Standalone skript (doporučeno)

Zkopíruj `luna-standalone.sh` na Proxmox host a spusť v **Proxmox shellu**:

```bash
bash luna-standalone.sh
```

Nebo přes curl (pokud máš skript na serveru/GitHub):
```bash
bash -c "$(curl -fsSL https://tvůj-server/luna-standalone.sh)"
```

---

### Metoda 2: Ve stylu community-scripts (pokročilé)

Vyžaduje community-scripts infrastrukturu:
1. `luna.sh` → hlavní skript (Proxmox node)
2. `luna-install.sh` → install skript (běží uvnitř containeru)

---

## ⚙️ Výchozí nastavení LXC

| Parametr | Hodnota |
|----------|---------|
| OS | Debian 12 (Bookworm) |
| CPU | 1 jádro |
| RAM | 128 MiB |
| Disk | 2 GB |
| Typ | Unprivileged |
| IP | DHCP |
| Luna HTTP port | 7126 |
| Luna HTTPS port | 7127 |

---

## 📋 Po instalaci

### Stav služby
```bash
pct exec <CT_ID> -- systemctl status luna
pct exec <CT_ID> -- journalctl -u luna -f
```

### Vstup do containeru
```bash
pct enter <CT_ID>
```

### Stremio LAN addon URL
Formát: `https://192-168-X-Y.local-ip.co:7127`
(IP s pomlčkami místo teček)

---

## ⚠️ Poznámka k stahování binary

Webshare.cz může vyžadovat přihlášení pro stažení souboru.
Pokud automatické stažení selže, stáhni soubor ručně:

1. Stáhni z: https://webshare.cz/#/file/q1oSHbCPl2/luna-linux-amd64-1-4-3
2. Zkopíruj do containeru:
   ```bash
   pct push <CT_ID> luna-linux-amd64 /opt/luna/luna-linux-amd64
   pct exec <CT_ID> -- chmod +x /opt/luna/luna-linux-amd64
   pct exec <CT_ID> -- systemctl start luna
   ```

---

## 🔧 Parametry Luna

```bash
# Manuální spuštění (pro testování)
pct exec <CT_ID> -- /opt/luna/luna-linux-amd64 --https --port 7126 --https-port 7127

# Změna portu (v /etc/systemd/system/luna.service)
pct exec <CT_ID> -- systemctl edit luna
```

---

## 🌐 LAN provoz

Luna běží s `--https` parametrem, což vytváří SSL server pro LAN streaming.
Pro Stremio musíš použít **local-ip.co doménu** s pomlčkami:

```
https://192-168-1-100.local-ip.co:7127
```
