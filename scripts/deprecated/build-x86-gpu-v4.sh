#!/bin/bash
set -e
M="make ARCH=x86_64"
cd /home/desktop_pc/wayangos-build/linux-6.19.7

echo "=== x86_64_defconfig ==="
$M x86_64_defconfig

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

$M olddefconfig

echo "=== Verify config ==="
head -3 .config

echo "=== Build prepare (sequential to avoid race) ==="
$M -j1 scripts
$M -j1 prepare

echo "=== Verify fixdep exists ==="
ls -la scripts/basic/fixdep
ls -la tools/objtool/objtool 2>/dev/null || echo "objtool not built yet (will build during main make)"

echo "=== Full build with 24 cores ==="
date
$M -j24
date

echo ""
echo "=== BUILD SUCCESSFUL ==="
ls -lh arch/x86/boot/bzImage

echo ""
echo "=== GPU drivers confirmed ==="
grep -E '=y' .config | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20
