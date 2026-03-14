# Building WayangOS

Complete guide to building WayangOS from source.

## Prerequisites

### Environment
- **WSL2 Ubuntu** on Windows (tested with Ubuntu 22.04+)
- Build dir: `~/wayangos-build/`
- Repo dir: `/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/`

### Packages
```bash
sudo apt install build-essential gcc make flex bison bc libelf-dev libssl-dev \
    cpio gzip grub-pc-bin grub-efi-amd64-bin xorriso mtools \
    qemu-system-x86 wget git
```

### Source Trees (in `~/wayangos-build/`)
| Component | Version | Path |
|-----------|---------|------|
| Linux kernel | 6.19.7 | `linux-6.19.7/` |
| BusyBox | 1.37.0 | `busybox-1.37.0/busybox` (pre-built static) |
| Dropbear SSH | 2024.86 | `dropbear-2024.86/` |
| SQLite | amalgamation | `sqlite3.c`, `sqlite3.h` |

### POS Application (separate repo)
| Component | Path |
|-----------|------|
| POS binary | `~/wayangos-pos-lvgl/wayang-pos-static` |
| LVGL | `~/wayangos-pos-lvgl/lvgl/` (v9.2.2) |

---

## Quick Start

Build everything and get a bootable POS ISO:

```bash
cd /mnt/c/Users/Desktop\ PC/.openclaw/workspace/linux-distro

# Full POS ISO pipeline (kernel + rootfs + POS binary + ISO)
./scripts/build-pos-iso.sh defconfig-qemu wayangos-pos-qemu.iso
```

---

## Step-by-Step

### 1. Build Kernel

```bash
# Using an existing config
./scripts/build-kernel.sh defconfig-qemu

# For GPU-specific builds
./scripts/build-kernel.sh defconfig-qemu bzImage-intel  # then add i915
```

Available configs in `configs/`:
- `defconfig-qemu` — QEMU testing (recommended starting point)

See `configs/README.md` for GPU-specific config generation.

### 2. Build Rootfs

Creates a base initramfs with BusyBox + Dropbear SSH + curl:

```bash
./scripts/build-rootfs.sh
# Output: ~/wayangos-build/wayangos-initramfs.img
```

Includes:
- BusyBox (static, all applets)
- Dropbear SSH server (auto-starts on port 22)
- curl with TLS
- Auto DHCP networking
- Root login (no password — add SSH key to `/root/.ssh/authorized_keys`)

### 3. Build POS Binary

```bash
cd ~/wayangos-pos-lvgl
make clean && make
# Output: wayang-pos-static
```

The POS app uses:
- LVGL v9.2.2 for GUI rendering
- Direct framebuffer (`/dev/fb0`)
- Linux evdev for touch/keyboard/mouse input
- SQLite for transaction storage

### 4. Assemble ISO

**Plain OS (no POS):**
```bash
./scripts/build-iso.sh ~/wayangos-build/bzImage-qemu ~/wayangos-build/wayangos-initramfs.img
```

**POS ISO (includes POS app):**
```bash
./scripts/build-pos-iso.sh defconfig-qemu
```

---

## QEMU Testing

### Basic boot test (serial console)
```bash
qemu-system-x86_64 \
    -kernel ~/wayangos-build/bzImage-qemu \
    -initrd ~/wayangos-build/wayangos-initramfs.img \
    -append "console=ttyS0" \
    -nographic -m 128M \
    -nic user
```

### GUI/POS test (graphical)
```bash
qemu-system-x86_64 \
    -cdrom ~/wayangos-build/wayangos-pos-qemu.iso \
    -m 256M -vga std -display gtk \
    -nic user,hostfwd=tcp::2222-:22
```

### SSH into QEMU instance
```bash
ssh -p 2222 root@localhost
```

### QEMU with monitor (for sendkey debugging)
```bash
qemu-system-x86_64 \
    -cdrom wayangos.iso \
    -m 256M -vga std -display gtk \
    -nic user,hostfwd=tcp::2222-:22 \
    -monitor unix:/tmp/qemu-mon,server,nowait

# Send keys via monitor
echo 'sendkey 1' | socat - UNIX-CONNECT:/tmp/qemu-mon
echo 'screendump /tmp/screen.ppm' | socat - UNIX-CONNECT:/tmp/qemu-mon
```

---

## Known Issues

### Keyboard not working in QEMU
**Symptom:** Boot works, framebuffer shows UI, but keyboard input is dead.

**Cause:** Custom minimal kernel configs miss the i8042 PS/2 controller and AT keyboard drivers that QEMU's virtual keyboard requires.

**Fix:** Use `defconfig` as base (includes i8042/atkbd). The `defconfig-qemu` config has this working.

**Required kernel options:**
```
CONFIG_SERIO=y
CONFIG_SERIO_I8042=y
CONFIG_KEYBOARD_ATKBD=y
CONFIG_INPUT_EVDEV=y
```

### Large kernel size with AMD GPU
The `bzImage-amd` is ~19MB vs ~14MB for others because AMD GPU support (amdgpu + radeon) includes significant firmware handling code.

### UEFI boot
GRUB ISOs default to BIOS boot. For UEFI, ensure `grub-efi-amd64-bin` is installed and `grub-mkrescue` will automatically include EFI boot support.

---

## Directory Structure

```
wayangos/
├── configs/              # Kernel configs
│   ├── README.md
│   └── defconfig-qemu   # Current working config
├── scripts/              # Build scripts
│   ├── build-kernel.sh   # Build kernel from config
│   ├── build-rootfs.sh   # Build base rootfs
│   ├── build-iso.sh      # Assemble ISO
│   └── build-pos-iso.sh  # Full POS ISO pipeline
├── landing-page/         # Website (DO NOT MODIFY in builds)
├── wayangos-pos/         # Old POS v3 (reference)
├── BUILDING.md           # This file
└── README.md
```
