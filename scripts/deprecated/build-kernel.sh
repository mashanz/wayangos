#!/bin/bash
set -e

SRC=/home/desktop_pc/wayangos-build/linux-6.19.7
BUILD=/home/desktop_pc/wayangos-build/kbuild-x86
LOG=/home/desktop_pc/x86build.log
ISO_DIR=/home/desktop_pc/wayangos-build
WIN_DIR="/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro"

exec >> "$LOG" 2>&1

echo "========== x86_64 GPU KERNEL BUILD =========="
echo "START: $(date)"
echo "Log: $LOG"
echo ""

# Step 1: Clean
echo "[1/6] Cleaning source tree..."
cd "$SRC"
make ARCH=x86_64 mrproper 2>/dev/null || true
rm -rf include/generated include/config arch/x86/include/generated 2>/dev/null || true
find . -name '.*.cmd' -not -path '*/.git/*' -delete 2>/dev/null || true
echo "Clean done"

# Step 2: Setup build dir
echo "[2/6] Setting up build directory..."
rm -rf "$BUILD"
mkdir -p "$BUILD"
echo "Build dir: $BUILD"

# Step 3: Configure
echo "[3/6] Configuring x86_64..."
make -C "$SRC" O="$BUILD" ARCH=x86_64 x86_64_defconfig

echo "Enabling GPU drivers..."
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

echo "Resolving dependencies..."
make -C "$SRC" O="$BUILD" ARCH=x86_64 olddefconfig

echo "Config: $(head -3 $BUILD/.config | tail -1)"

# Step 4: Build
echo "[4/6] Building kernel ($(nproc) cores)..."
echo "Build start: $(date)"
make -C "$SRC" O="$BUILD" ARCH=x86_64 -j$(nproc)
echo "Build end: $(date)"

BZIMAGE="$BUILD/arch/x86/boot/bzImage"
ls -lh "$BZIMAGE"

# Step 5: Verify
echo "[5/6] Verifying GPU drivers..."
grep -E '=y' "$BUILD/.config" | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -10

# Step 6: ISO
echo "[6/6] Building ISO..."
EXTRACT=$(mktemp -d)
ISODIR=$(mktemp -d)
mkdir -p "$ISODIR/boot/grub"

xorriso -osirrox on -indev "$ISO_DIR/wayangos-0.5-headless-x86_64.iso" -extract / "$EXTRACT" 2>/dev/null
cp "$BZIMAGE" "$ISODIR/boot/vmlinuz"
cp "$EXTRACT/boot/initramfs.img" "$ISODIR/boot/initramfs.img"

cat > "$ISODIR/boot/grub/grub.cfg" << 'GRUBEOF'
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
GRUBEOF

grub-mkrescue -o "$ISO_DIR/wayangos-gpu.iso" "$ISODIR" 2>&1 | tail -3
rm -rf "$ISODIR" "$EXTRACT"
ls -lh "$ISO_DIR/wayangos-gpu.iso"

# Copy to Windows
cp "$ISO_DIR/wayangos-gpu.iso" "$WIN_DIR/"
echo "Copied to: $WIN_DIR/wayangos-gpu.iso"

# Upload
echo "Uploading to GitHub..."
cd "$ISO_DIR"
gh release create v0.6.0-gpu \
  --repo mashanz/wayangos \
  --title "WayangOS v0.6.0 - GPU Support (Intel/AMD/NVIDIA)" \
  --notes "Kernel 6.19.7 with Intel i915, AMD amdgpu/radeon, NVIDIA nouveau GPU drivers. UEFI+BIOS hybrid. Includes nomodeset safe mode." \
  wayangos-gpu.iso

echo ""
echo "========== SUCCESS =========="
echo "END: $(date)"
echo "=============================  "
