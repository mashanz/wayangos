# WayangOS v0.3.0 — Kernel 6.19.7

## What's New
- **Linux kernel upgraded to 6.19.7** (latest stable, from 6.12.6 LTS)
- Landing page accuracy overhaul — all claims now match shipped reality

## Editions

### Headless (14 MB)
- Linux 6.19.7 kernel
- BusyBox (shell + utils)
- Dropbear SSH server (port 22)
- curl with TLS/HTTPS
- Auto DHCP + syslog + NTP

### GUI (15 MB)
- Everything in Headless, plus:
- DRM/framebuffer kernel drivers
- SDL2 kiosk display stack
- Boots to framebuffer kiosk app

## System Requirements
- x86_64 processor
- 64 MB RAM minimum
- Boots from USB, CD, or VM

## Downloads
- `wayangos-0.3-x86_64.iso` — Headless Edition (14 MB)
- `wayangos-0.3-gui-x86_64.iso` — GUI Edition (15 MB)
