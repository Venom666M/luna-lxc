# 🌙 Luna: Absolute Cinema — Proxmox LXC Installer

Jednoduchý instalátor pro Luna: Absolute Cinema na Proxmox VE. Vytvoří LXC container, stáhne binary z GitHub Releases a spustí službu automaticky.

## Instalace

Spusť v Proxmox shellu jako root:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Venom666M/luna-lxc/main/luna-standalone.sh)"
```

## Co to udělá

- Vytvoří LXC container v Proxmoxu.
- Nainstaluje Luna server.
- Stáhne správnou binary z GitHub Releases.
- Nastaví službu `systemd`, aby se Luna spouštěla po restartu.

## Výchozí nastavení

- Debian 12 (Bookworm)
- 1 CPU
- 128 MiB RAM
- 2 GB disk
- DHCP síť
- HTTP port `7126`
- HTTPS port `7127`

## Stremio URL

Po instalaci použij adresu ve tvaru:

```text
https://10-0-1-6.local-ip.co:7127
```

## Správa služby

```bash
pct exec <CT_ID> -- systemctl status luna
pct exec <CT_ID> -- systemctl restart luna
pct exec <CT_ID> -- journalctl -u luna -f
```

## Verze

- Luna: `v1.4.3`
- Release: [GitHub Releases](https://github.com/Venom666M/luna-lxc/releases/tag/v1.4.3)
