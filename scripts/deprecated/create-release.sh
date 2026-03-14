#!/bin/bash
cd "$(dirname "$0")"

cat > /tmp/release-notes.md << 'NOTES'
# ꦮꦪꦁ WayangOS v0.1.0 — The Shadow that Powers the Machine

## x86_64 Build
- **Kernel**: Linux 6.12.6 (minimal config, 2.77 MB)
- **Rootfs**: BusyBox 1.37.0 static initramfs (1.25 MB)
- **Total**: 3.99 MB

## Quick Start
```bash
# Test with QEMU
qemu-system-x86_64 -kernel vmlinuz -initrd wayangos-initramfs-x86_64.img \
  -append "console=ttyS0" -nographic -m 128M

# Or extract the full package
tar xzf wayangos-0.1-x86_64.tar.gz
cd wayangos-0.1-x86_64
./run-qemu.sh
```

## Features
- Ultra-minimal (under 4MB total)
- Custom init (no systemd)
- Virtio support (KVM/QEMU ready)
- Serial console, EXT4, networking
- Boots in under 2 seconds

ARM64 and RISC-V builds coming soon.
NOTES

gh release create v0.1.0 \
  wayangos-0.1-x86_64.tar.gz \
  vmlinuz \
  wayangos-initramfs-x86_64.img \
  --repo mashanz/wayangos \
  --title "WayangOS v0.1.0 - First Release" \
  --notes-file /tmp/release-notes.md
