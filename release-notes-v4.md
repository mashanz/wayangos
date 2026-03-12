# WayangOS v0.4.0 — PREEMPT_RT Real-Time Kernel

## What's New
- **Real-time kernel**: Linux 6.19.3-rt1 with `CONFIG_PREEMPT_RT=y`
- **1000Hz tick rate** for sub-millisecond scheduling precision
- **High-resolution timers** enabled
- RTOS is now the **default** for all editions

## Kernel Config
```
CONFIG_PREEMPT_RT=y
CONFIG_HZ_1000=y
CONFIG_HZ=1000
CONFIG_HIGH_RES_TIMERS=y
```

## Editions

### Headless RT (14 MB)
- Linux 6.19.3-rt1 PREEMPT_RT kernel
- BusyBox (shell + utils)
- Dropbear SSH server (port 22)
- curl with TLS/HTTPS
- Auto DHCP + syslog + NTP

### GUI RT (15 MB)
- Everything in Headless, plus:
- DRM/framebuffer kernel drivers
- SDL2 kiosk display stack

## System Requirements
- x86_64 processor
- 64 MB RAM minimum
- Boots from USB, CD, or VM

## Downloads
- `wayangos-0.4-rt-x86_64.iso` — Headless RT Edition (14 MB)
- `wayangos-0.4-rt-gui-x86_64.iso` — GUI RT Edition (15 MB)
