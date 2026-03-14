# Architecture Guide

## Supported Platforms

### x86_64 (AMD64)
- Intel/AMD 64-bit processors
- Tested on: QEMU/KVM, bare metal
- Primary development target

### ARM64 (AArch64)
- ARMv8-A 64-bit processors
- Targets: Raspberry Pi 4/5, NVIDIA Jetson, various SBCs
- Cross-compile: `aarch64-linux-gnu-`

### RISC-V (rv64gc)
- 64-bit RISC-V with G (IMAFDZicsr_Zifencei) and C extensions
- Targets: SiFive boards, StarFive VisionFive 2
- Cross-compile: `riscv64-linux-gnu-`

## Build Host Requirements

- Linux x86_64 (or WSL2 on Windows)
- GCC 12+ or Clang 16+
- GNU Make, flex, bison, bc
- libelf-dev, libssl-dev
- ~2GB disk space per architecture build
- Cross-compiler packages for non-native architectures

## Boot Flow

```
Firmware (BIOS/UEFI/U-Boot)
  → Bootloader (optional: GRUB/syslinux/direct kernel boot)
    → Kernel (bzImage/Image)
      → initramfs (cpio.gz)
        → /sbin/init (custom shell script)
          → /etc/init.d/rcS
            → getty on serial console
```

## Memory Layout (minimal profile)

| Component | Size |
|-----------|------|
| Kernel | ~4-6 MB |
| initramfs | ~2-3 MB |
| Runtime RAM | ~20 MB |
| **Total minimum** | **~64 MB** |
