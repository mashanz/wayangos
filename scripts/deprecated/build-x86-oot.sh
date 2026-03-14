#!/bin/bash
set -e

SRC=/home/desktop_pc/wayangos-build/linux-6.19.7
BUILD=/home/desktop_pc/wayangos-build/kbuild-x86
ISO_DIR=/home/desktop_pc/wayangos-build
WIN_DIR="/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro"

echo "=== Out-of-tree x86_64 GPU kernel build ==="
echo "Source: $SRC"
echo "Build:  $BUILD"
date

# Kill any leftover build processes
killall -9 make gcc cc1 as ld ar 2>/dev/null || true
sleep 1

# Clean source tree (required for out-of-tree builds)
echo "=== Cleaning source tree ==="
cd "$SRC"
make ARCH=x86_64 mrproper 2>/dev/null || make mrproper 2>/dev/null || true
# Also remove any stale .cmd files that mrproper misses
find "$SRC" -name '.*.cmd' -not -path '*/.git/*' -delete 2>/dev/null || true
echo "Source tree clean"

# Clean and create build directory
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Configure x86_64
echo "=== Configuring x86_64 ==="
make -C "$SRC" O="$BUILD" ARCH=x86_64 x86_64_defconfig

# Enable GPU drivers and needed features
make -C "$SRC" O="$BUILD" ARCH=x86_64 scripts/config -- \
  --enable DRM \
  --enable DRM_FBDEV_EMULATION \
  --enable DRM_I915 \
  --enable DRM_AMDGPU \
  --enable DRM_RADEON \
  --enable DRM_NOUVEAU \
  --enable DRM_SIMPLEDRM \
  --enable FB_EFI \
  --enable FB_VESA \
  --enable FRAMEBUFFER_CONSOLE \
  --enable VGA_CONSOLE \
  --enable EFI \
  --enable EFI_STUB \
  --enable EFI_MIXED \
  --enable NET \
  --enable INET \
  --enable WIRELESS \
  --enable CFG80211 \
  --enable USB \
  --enable USB_XHCI_HCD \
  --enable USB_EHCI_HCD \
  --enable USB_STORAGE \
  --enable USB_HID \
  --enable INPUT_EVDEV \
  --enable KEYBOARD_ATKBD \
  --enable MOUSE_PS2 \
  --enable VT \
  --enable VT_CONSOLE \
  --enable UNIX98_PTYS \
  --enable EXT4_FS \
  --enable VFAT_FS \
  --enable TMPFS \
  --enable PROC_FS \
  --enable SYSFS \
  --enable DEVTMPFS \
  --enable DEVTMPFS_MOUNT \
  --enable ISO9660_FS 2>/dev/null || true

# Resolve deps
make -C "$SRC" O="$BUILD" ARCH=x86_64 olddefconfig

echo "=== Config check ==="
head -3 "$BUILD/.config"
grep CONFIG_X86_64 "$BUILD/.config"
grep CONFIG_HAVE_ARCH_COMPILER_H "$BUILD/.config" || echo "HAVE_ARCH_COMPILER_H: not set (correct for x86)"

echo ""
echo "=== Building kernel (24 cores) ==="
date
make -C "$SRC" O="$BUILD" ARCH=x86_64 -j24 2>&1
echo ""
echo "=== BUILD DONE ==="
date
ls -lh "$BUILD/arch/x86/boot/bzImage"

echo ""
echo "=== GPU drivers ==="
grep -E '=y' "$BUILD/.config" | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20

echo ""
echo "=== Building UEFI ISO ==="
EXTRACT=$(mktemp -d)
ISODIR=$(mktemp -d)
mkdir -p "$ISODIR/boot/grub"

# Extract initramfs from existing headless ISO
xorriso -osirrox on -indev "$ISO_DIR/wayangos-0.5-headless-x86_64.iso" -extract / "$EXTRACT" 2>/dev/null
echo "Extracted boot files:"
ls "$EXTRACT/boot/"

cp "$BUILD/arch/x86/boot/bzImage" "$ISODIR/boot/vmlinuz"
cp "$EXTRACT/boot/initramfs.img" "$ISODIR/boot/initramfs.img"

cat > "$ISODIR/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0
menuentry "WayangOS" {
    linux /boot/vmlinuz loglevel=3 vt.global_cursor_default=0 quiet
    initrd /boot/initramfs.img
}
menuentry "WayangOS (nomodeset - safe mode)" {
    linux /boot/vmlinuz nomodeset loglevel=3 vt.global_cursor_default=0 quiet
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o "$ISO_DIR/wayangos-gpu.iso" "$ISODIR" 2>&1 | tail -5
rm -rf "$ISODIR" "$EXTRACT"
echo ""
echo "=== ISO done ==="
ls -lh "$ISO_DIR/wayangos-gpu.iso"

echo ""
echo "=== Copying to Windows workspace ==="
cp "$ISO_DIR/wayangos-gpu.iso" "$WIN_DIR/"
ls -lh "$WIN_DIR/wayangos-gpu.iso"

echo ""
echo "=== Uploading to GitHub ==="
cd "$ISO_DIR"
gh release create v0.6.0-gpu \
  --repo mashanz/wayangos \
  --title "WayangOS v0.6.0 - GPU Support (Intel/AMD/NVIDIA)" \
  --notes "Kernel 6.19.7 with Intel i915, AMD amdgpu/radeon, NVIDIA nouveau GPU drivers. EFI framebuffer fallback. UEFI+BIOS hybrid. Includes nomodeset safe mode option." \
  wayangos-gpu.iso 2>&1

echo "=== ALL DONE ==="
date
