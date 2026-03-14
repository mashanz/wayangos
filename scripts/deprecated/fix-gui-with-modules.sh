#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

echo "=== Configuring kernel to build DRM as modules ==="
# Keep most of DRM built-in, but make specific drivers modular for flexibility
./scripts/config --enable PCI
./scripts/config --enable PCI_QUIRKS
./scripts/config --enable MMU
./scripts/config --enable SHMEM

# Core DRM (built-in)
./scripts/config --enable DRM
./scripts/config --enable DRM_KMS_HELPER
./scripts/config --enable DRM_FBDEV_EMULATION
./scripts/config --enable DRM_SIMPLEDRM
./scripts/config --enable DRM_GEM_SHMEM_HELPER

# Drivers as modules so they can be loaded/unloaded
./scripts/config --module DRM_BOCHS
./scripts/config --module DRM_VIRTIO_GPU

# Framebuffer
./scripts/config --enable FB
./scripts/config --enable FB_VESA
./scripts/config --enable FRAMEBUFFER_CONSOLE
./scripts/config --enable FRAMEBUFFER_CONSOLE_DETECT_PRIMARY

# Virtio
./scripts/config --enable VIRTIO
./scripts/config --enable VIRTIO_PCI
./scripts/config --enable VIRTIO_MMIO

# Input
./scripts/config --enable INPUT_EVDEV

make olddefconfig 2>&1 | tail -3

echo "=== Verify DRM config ===" 
grep "CONFIG_DRM\|CONFIG_BOCHS\|CONFIG_VIRTIO_GPU\|CONFIG_FRAMEBUFFER" .config | grep -v "^#"

echo "=== Building kernel ==="
make -j$(nproc) bzImage 2>&1 | tail -5

echo "=== Building modules ==="
make -j$(nproc) modules 2>&1 | tail -3

# Install modules to a staging dir
MODULE_INSTALL_PATH=~/wayangos-build/modules-staging
mkdir -p "$MODULE_INSTALL_PATH"
INSTALL_MOD_PATH=$MODULE_INSTALL_PATH make modules_install 2>&1 | tail -3

echo "=== Check compiled modules ===" 
find $MODULE_INSTALL_PATH/lib/modules -name "*.ko" | head -10

cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-gui-with-modules
ls -lh ~/wayangos-build/vmlinuz-rt-gui-with-modules

echo "=== DONE ==="
