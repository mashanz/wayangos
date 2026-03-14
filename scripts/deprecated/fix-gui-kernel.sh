#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

echo "=== Fixing GUI RT kernel with DRM support ==="

# Start from current config
cp ../kernel-gui.config .config

# Enable EXPERT + RT
scripts/config --enable EXPERT
scripts/config --enable PREEMPT_RT
scripts/config --set-val HZ 1000
scripts/config --enable HZ_1000
scripts/config --disable HZ_250
scripts/config --disable HZ_100
scripts/config --enable HIGH_RES_TIMERS

# Enable DRM + framebuffer
scripts/config --enable DRM
scripts/config --enable DRM_FBDEV_EMULATION
scripts/config --enable DRM_BOCHS
scripts/config --enable DRM_VIRTIO_GPU
scripts/config --enable DRM_SIMPLEDRM
scripts/config --enable FB
scripts/config --enable FB_VESA
scripts/config --enable FRAMEBUFFER_CONSOLE
scripts/config --enable VT
scripts/config --enable VT_CONSOLE
scripts/config --enable INPUT_EVDEV

# For QEMU virtio
scripts/config --enable VIRTIO
scripts/config --enable VIRTIO_PCI
scripts/config --enable VIRTIO_MMIO

make olddefconfig 2>&1 | tail -3

echo "=== DRM Config Check ==="
grep -E "CONFIG_DRM=|CONFIG_DRM_BOCHS=|CONFIG_DRM_VIRTIO=|CONFIG_FB=|CONFIG_FRAMEBUFFER_CONSOLE=|CONFIG_PREEMPT_RT=" .config

echo "=== Building GUI RT kernel ==="
make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-gui-fixed
ls -lh ~/wayangos-build/vmlinuz-rt-gui-fixed
strings ~/wayangos-build/vmlinuz-rt-gui-fixed | grep "6\.19\.3" | head -1

echo "=== DONE ==="
