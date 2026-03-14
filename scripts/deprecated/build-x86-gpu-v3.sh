#!/bin/bash
set -e
ARCH_FLAG="ARCH=x86_64"
cd /home/desktop_pc/wayangos-build/linux-6.19.7

# Kill any stale processes
killall -9 make gcc cc1 as ld 2>/dev/null || true
sleep 1

echo "=== distclean ==="
make $ARCH_FLAG distclean

echo "=== x86_64_defconfig ==="
make $ARCH_FLAG x86_64_defconfig

# Enable GPU drivers
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
scripts/config --enable KEYBOARD_ATKBD
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

make $ARCH_FLAG olddefconfig

# Verify config
echo "=== Config verification ==="
head -3 .config
grep CONFIG_X86_64 .config | head -1

echo "=== Building with $(nproc) cores ==="
date
make $ARCH_FLAG -j$(nproc) 2>&1

echo ""
echo "=== BUILD SUCCESSFUL ==="
date
ls -lh arch/x86/boot/bzImage

echo ""
echo "=== GPU drivers confirmed ==="
grep -E '=y' .config | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20
