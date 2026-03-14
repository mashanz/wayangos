#!/bin/bash
set -e
cd /home/desktop_pc/wayangos-build/linux-6.19.7

# Kill any stale make/gcc processes
echo "=== Killing stale processes ==="
killall -9 make gcc cc1 as ld 2>/dev/null || true
sleep 2

# Check available memory
free -h
echo ""

echo "=== Full distclean ==="
make distclean 2>/dev/null || true

# Verify clean state
echo "Checking for leftover generated files..."
ls include/generated/ 2>/dev/null && echo "WARNING: generated dir still exists" || echo "Clean: no generated dir"
ls scripts/basic/fixdep 2>/dev/null && echo "fixdep exists" || echo "Clean: no fixdep"

echo ""
echo "=== Generating x86_64 config ==="
make x86_64_defconfig

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

make olddefconfig

echo ""
echo "=== Building with 8 cores (reduced to avoid OOM) ==="
date
make -j8 2>&1
echo ""
echo "=== BUILD DONE ==="
date
ls -lh arch/x86/boot/bzImage

echo ""
echo "=== GPU drivers in config ==="
grep -E '=y' .config | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20
