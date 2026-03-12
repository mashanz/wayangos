# [DistroName]OS

**Ultra-minimal Linux distribution for the edge.**

Built from the ground up for embedded systems, real-time applications, IoT devices, robotics, server clustering, and virtualization. No bloat. No compromises. Just Linux.

---

## Overview

[DistroName]OS is a custom Linux distribution built on the latest stable kernel (v6.13+) with PREEMPT_RT support. It uses musl libc and BusyBox for a tiny userspace footprint, boots in seconds, and runs comfortably on **64MB of RAM**.

There is no systemd. No D-Bus. No polkit. Just a clean, auditable init system you can read in 5 minutes.

## Key Features

| Feature | Details |
|---------|---------|
| **Kernel** | Linux 6.13+ with PREEMPT_RT patches |
| **Libc** | musl — small, correct, static-linking friendly |
| **Userspace** | BusyBox — 400+ utilities in a single binary |
| **Init** | Custom shell-based init (no systemd) |
| **Architectures** | x86_64, ARM64 (aarch64), RISC-V (rv64) |
| **Min RAM** | 64MB (minimal profile) |
| **Boot time** | < 2 seconds to shell (on modern hardware) |
| **Root FS** | ~8MB compressed initramfs |

## Target Use Cases

- **Embedded / IoT** — Sensor nodes, gateways, edge compute
- **Real-time / Robotics** — PREEMPT_RT for deterministic scheduling, GPIO/I2C/SPI support
- **Server / Virtualization** — KVM host, container nodes, minimal attack surface
- **Clustering** — Lightweight nodes for distributed computing
- **Education** — Learn Linux internals with a system small enough to understand completely

## Configuration Profiles

Three kernel configurations ship with the project:

### `minimal.config`
Absolute minimum. Strips everything non-essential. Perfect for IoT and embedded targets where every kilobyte matters.
- No sound, GPU, WiFi, Bluetooth
- Serial console, networking, ext4/btrfs
- Namespaces + cgroups for containers
- Optimized for size (`CC_OPTIMIZE_FOR_SIZE`)

### `server.config`
Server and virtualization focused. Includes KVM, advanced networking (BBR, nftables, bonding, OVS), NVMe, RAID, NFS, and full container support.
- KVM (Intel + AMD)
- TCP BBR congestion control
- Device mapper (dm-crypt, thin provisioning)
- MD RAID 0/1/5/6/10
- BPF/XDP support

### `rt.config`
Real-time variant with `PREEMPT_RT` enabled. Tuned for deterministic, low-latency operation.
- `CONFIG_PREEMPT_RT=y`
- 1000Hz tick rate
- IRQ forced threading
- CPU isolation support
- GPIO/I2C/SPI for hardware interfaces
- No transparent hugepages (latency killer)

## Project Structure

```
linux-distro/
├── kernel/          # Linux kernel source (shallow clone)
├── configs/         # Kernel configurations
│   ├── minimal.config
│   ├── server.config
│   └── rt.config
├── userspace/       # Init scripts, BusyBox config
├── build/           # Build scripts
│   ├── build-kernel.sh
│   └── build-rootfs.sh
├── docs/            # Documentation
├── landing-page/    # Project website
└── README.md
```

## Quick Start

### Prerequisites

- Linux build host (or WSL2)
- GCC toolchain (native or cross-compile)
- `make`, `flex`, `bison`, `bc`, `libelf-dev`, `libssl-dev`
- For cross-compilation: `gcc-aarch64-linux-gnu` or `gcc-riscv64-linux-gnu`

### Build the Kernel

```bash
# x86_64 minimal
./build/build-kernel.sh x86_64 minimal

# ARM64 server
./build/build-kernel.sh arm64 server

# RISC-V real-time
./build/build-kernel.sh riscv rt
```

### Build Root Filesystem

```bash
./build/build-rootfs.sh x86_64
```

### Test with QEMU

```bash
qemu-system-x86_64 \
  -kernel build/output/x86_64-minimal/bzImage \
  -initrd build/output/rootfs/x86_64-initramfs.cpio.gz \
  -append "console=ttyS0" \
  -nographic \
  -m 64M
```

## Philosophy

1. **If you don't need it, don't include it.** Every enabled kernel option is a conscious choice.
2. **Understand your system.** The entire userspace fits in your head.
3. **Security through minimalism.** Fewer packages = fewer CVEs.
4. **Real-time is not optional.** Deterministic behavior should be the default, not an afterthought.

## Roadmap

- [ ] Automated CI/CD build pipeline
- [ ] Pre-built images for popular SBCs (RPi, BeagleBone, VisionFive 2)
- [ ] Package manager (apk-tools or custom)
- [ ] Secure boot support
- [ ] OTA update mechanism
- [ ] Kubernetes node image
- [ ] Documentation site

## Contributing

This project is in early development. Contributions welcome — especially:
- Kernel config tuning for specific hardware
- ARM64/RISC-V testing
- Init system improvements
- Documentation

## License

Kernel: GPLv2 (as required by Linux)
Userspace & configs: MIT

---

**Built by [Hans Sumardhi](https://github.com/mashanz)**

*[DistroName]OS — Because your OS should be smaller than your application.*
