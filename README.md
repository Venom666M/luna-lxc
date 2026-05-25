# 🌙 Luna: Absolute Cinema — Proxmox LXC Installer

Automatický installer pro vytvoření LXC containeru s **Luna: Absolute Cinema** serverem na Proxmox VE.

> Stremio addon + WebShare.cz media server pro celou domácnost přes LAN.

---

## ⚡ Instalace

Spusť v **Proxmox shellu** (jako root):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Venom666M/luna-lxc/main/luna-standalone.sh)"
```

Skript se postará o vše — vytvoří LXC container, nainstaluje Lunu a spustí ji jako službu.

---

## ⚙️ Co skript vytvoří

| Parametr | Hodnota |
|----------|---------|
| OS | Debian 12 (Bookworm) |
| CPU | 1 jádro |
| RAM | 128 MiB |
| Disk | 2 GB |
| Typ | Unprivileged |
| Síť | DHCP |
| Luna HTTP port | 7126 |
| Luna HTTPS port | 7127 |

---

## 🌐 Stremio LAN addon URL

Po instalaci skript zobrazí přesnou adresu. Formát je:

```
https://192-168-X-Y.local-ip.co:7127
```

*(IP adresa containeru s pomlčkami místo teček)*

---

## 🔧 Správa služby

```bash
# Vstup do containeru
pct enter <CT_ID>

# Stav / restart / logy
systemctl status luna
systemctl restart luna
journalctl -u luna -f
```

---

## 📦 Verze

- Luna binary: **v1.4.3**
- Zdroj: [GitHub Releases](https://github.com/Venom666M/luna-lxc/releases/tag/v1.4.3)
