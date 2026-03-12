# ꦮꦪꦁ WayangOS v0.2.0 — The Shadow that Powers the Machine

## What's New
- **Networking**: Auto DHCP on boot (udhcpc, ifconfig, route)
- **SSH Server**: Dropbear SSH (port 22, ed25519 keys auto-generated)
- **curl + TLS**: Static curl with HTTPS support — pull configs, hit APIs
- **Proper init**: BusyBox init with /etc/inittab + init.d scripts
- **Syslog + NTP**: Logging and time sync out of the box

## Philosophy
Deployment OS. No package manager. All binaries are static-linked.
Deploy apps by `scp`-ing a static binary. That's your package manager.

## x86_64 Build
| Component | Size |
|-----------|------|
| Kernel (Linux 6.12.6) | 2.8 MB |
| BusyBox (shell + utils) | 2.4 MB |
| Dropbear SSH | 1.8 MB |
| curl + TLS | 6.2 MB |
| **ISO (bootable)** | **13 MB** |
| **tar.gz** | **7.3 MB** |

## Quick Start
1. Download `.iso`
2. Flash to USB with [Rufus](https://rufus.ie) or [balenaEtcher](https://etcher.balena.io)
3. Boot → WayangOS is ready with networking + SSH in <2 seconds

## Default Access
- Root login, no password (set with `passwd`)
- SSH on port 22 (add key to `/root/.ssh/authorized_keys`)
- DHCP auto-configures networking
