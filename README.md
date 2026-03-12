# WayangOS v0.1 (x86_64)

Minimal Linux distribution.

## Components
- Linux kernel 6.12.6 (minimal config)
- BusyBox 1.37.0 (static)
- initramfs rootfs

## Boot with QEMU
```bash
./run-qemu.sh
```

## Manual boot
```bash
qemu-system-x86_64 -kernel vmlinuz -initrd initramfs.img -append "console=ttyS0" -nographic -m 128M
```

## Boot on real hardware
Use a bootloader (GRUB/syslinux) pointing to vmlinuz with initramfs.img as initrd.
