#!/bin/bash
set -e
cd /home/desktop_pc/wayangos-build/linux-6.19.7

echo "=== Waiting for ARM64 build to finish ==="
while pgrep -f "aarch64-linux-gnu" > /dev/null 2>&1; do
    sleep 30
    echo "Still building ARM64... $(date)"
    tail -1 /tmp/kernel-build.log 2>/dev/null || true
done
echo "ARM64 build finished"
ls -lh arch/arm64/boot/Image 2>/dev/null || echo "No ARM64 Image found"

echo ""
echo "=== Starting x86_64 GPU kernel build ==="
make mrproper
make x86_64_defconfig

# Enable GPU drivers and other needed features
scripts/config --enable DRM
scripts/config --enable DRM_FBDEV_EMULATION
scripts/config --enable DRM_I915
scripts/config --enable DRM_AMDGPU
scripts/config --enable DRM_RADEON
scripts/config --enable DRM_NOUVEAU
scripts/config --enable DRM_SIMPLEDRM
scripts/config --enable FB_EFI
scripts/config --enable FB_VESA
scripts/config --enable FRAMEBUFFER_CONSOLE
scripts/config --enable VGA_CONSOLE
scripts/config --enable EFI
scripts/config --enable EFI_STUB
scripts/config --enable EFI_MIXED
scripts/config --enable NET
scripts/config --enable INET
scripts/config --enable WIRELESS
scripts/config --enable CFG80211
scripts/config --enable USB
scripts/config --enable USB_XHCI_HCD
scripts/config --enable USB_EHCI_HCD
scripts/config --enable USB_STORAGE
scripts/config --enable USB_HID
scripts/config --enable INPUT_EVDEV
scripts/config --enable INPUT_KEYBOARD
scripts/config --enable KEYBOARD_ATKBD
scripts/config --enable INPUT_MOUSE
scripts/config --enable MOUSE_PS2
scripts/config --enable VT
scripts/config --enable VT_CONSOLE
scripts/config --enable UNIX98_PTYS
scripts/config --enable EXT4_FS
scripts/config --enable VFAT_FS
scripts/config --enable TMPFS
scripts/config --enable PROC_FS
scripts/config --enable SYSFS
scripts/config --enable DEVTMPFS
scripts/config --enable DEVTMPFS_MOUNT
scripts/config --enable ISO9660_FS

make olddefconfig
echo "Config ready, building with $(nproc) cores..."
make -j$(nproc) 2>&1 | tail -30
echo ""
echo "=== Build complete ==="
ls -lh arch/x86/boot/bzImage

echo ""
echo "=== Verifying GPU drivers ==="
grep -E '=y' .config | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20
