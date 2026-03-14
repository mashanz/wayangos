# WayangOS v0.5.0 — Choose Your Edition

4 editions. Pick the one that fits your use case.

## Download Matrix

| Edition | Kernel | RT | Display | Size | Best For |
|---------|--------|----|---------|------|----------|
| **Headless** | 6.19.7 | ❌ | None | 14 MB | Servers, VMs, general deployment |
| **Headless RT** | 6.19.3-rt1 | ✅ | None | 14 MB | IoT, robotics, industrial control |
| **GUI** | 6.19.7 | ❌ | SDL2/fbdev | 15 MB | Kiosk, signage, dashboards |
| **GUI RT** | 6.19.3-rt1 | ✅ | SDL2/fbdev | 15 MB | Real-time kiosk, POS, HMI |

## What's in Every Edition
- BusyBox (shell + 300 utils)
- Dropbear SSH server (port 22, auto-start)
- curl with TLS/HTTPS
- Auto DHCP + syslog + NTP
- 64 MB minimum RAM
- Boot in <2 seconds

## RT Editions Include
- `CONFIG_PREEMPT_RT=y` — full real-time preemption
- `CONFIG_HZ_1000=y` — 1000Hz tick (1ms precision)
- `CONFIG_HIGH_RES_TIMERS=y` — sub-millisecond timer resolution
- Deterministic scheduling for latency-critical workloads

## GUI Editions Include
- DRM/KMS + framebuffer kernel drivers
- SDL2 with fbdev backend (no X11, no Wayland)
- Boots directly into kiosk application on `/dev/fb0`

## Downloads
- `wayangos-0.5-headless-x86_64.iso` — Headless (14 MB)
- `wayangos-0.5-headless-rt-x86_64.iso` — Headless RT (14 MB)
- `wayangos-0.5-gui-x86_64.iso` — GUI (15 MB)
- `wayangos-0.5-gui-rt-x86_64.iso` — GUI RT (15 MB)
