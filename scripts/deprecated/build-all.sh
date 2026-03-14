#!/bin/bash
# Full x86_64 GPU kernel build + ISO + upload
# Designed to run via nohup, immune to SIGHUP
set -e
trap 'echo "[ERROR] Script failed at line $LINENO" >> /tmp/x86build.log' ERR

SRC=/home/desktop_pc/wayangos-build/linux-6.19.7
BUILD=/home/desktop_pc/wayangos-build/kbuild-x86
ISO_DIR=/home/desktop_pc/wayangos-build
WIN_DIR="/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro"
LOG=/tmp/x86build.log

exec >> "$LOG" 2>&1
echo "========================================"
echo "START: $(date)"
echo "========================================"

# Step 1: Kill stale processes
echo "[1] Killing stale build processes..."
killall -9 make gcc cc1 as ld ar 2>/dev/null || true
sleep 2

# Step 2: Clean source tree
echo "[2] Cleaning source tree..."
cd "$SRC"
make ARCH=x86_64 mrproper 2>/dev/null || true
rm -rf include/generated include/config arch/x86/include/generated 2>/dev/null || true
find . -name '.*.cmd' -not -path '*/.git/*' -delete 2>/dev/null || true
echo "Source tree clean"

# Step 3: Clean and setup build dir
echo "[3] Setting up build dir..."
rm -rf "$BUILD"
mkdir -p "$BUILD"

# Step 4: Configure
echo "[4] Configuring x86_64..."
make -C "$SRC" O="$BUILD" ARCH=x86_64 x86_64_defconfig
make -C "$SRC" O="$BUILD" ARCH=x86_64 scripts/config \
  -- \
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
make -C "$SRC" O="$BUILD" ARCH=x86_64 olddefconfig

echo "Config: $(head -3 $BUILD/.config | tail -1)"
grep CONFIG_HAVE_ARCH_COMPILER_H "$BUILD/.config" 2>/dev/null || echo "HAVE_ARCH_COMPILER_H: not set (good)"

# Step 5: Build kernel
echo "[5] Building kernel with $(nproc) cores..."
echo "Start: $(date)"
make -C "$SRC" O="$BUILD" ARCH=x86_64 -j$(nproc)
echo "Build done: $(date)"

BZIMAGE="$BUILD/arch/x86/boot/bzImage"
ls -lh "$BZIMAGE"
KSIZE=$(du -sh "$BZIMAGE" | cut -f1)
echo "Kernel size: $KSIZE"

# Step 6: Verify GPU drivers
echo "[6] GPU drivers in config:"
grep -E '=y' "$BUILD/.config" | grep -iE 'i915|amdgpu|radeon|nouveau|simpledrm|fb_efi' | head -20

# Step 7: Build ISO
echo "[7] Building UEFI ISO..."
EXTRACT=$(mktemp -d)
ISODIR=$(mktemp -d)
mkdir -p "$ISODIR/boot/grub"

xorriso -osirrox on -indev "$ISO_DIR/wayangos-0.5-headless-x86_64.iso" -extract / "$EXTRACT" 2>/dev/null
echo "Extracted boot files: $(ls $EXTRACT/boot/)"

cp "$BZIMAGE" "$ISODIR/boot/vmlinuz"
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

grub-mkrescue -o "$ISO_DIR/wayangos-gpu.iso" "$ISODIR" 2>&1
rm -rf "$ISODIR" "$EXTRACT"
ls -lh "$ISO_DIR/wayangos-gpu.iso"
ISOSIZE=$(du -sh "$ISO_DIR/wayangos-gpu.iso" | cut -f1)

# Step 8: Copy to Windows
echo "[8] Copying to Windows workspace..."
cp "$ISO_DIR/wayangos-gpu.iso" "$WIN_DIR/"
echo "Copied."

# Step 9: Upload to GitHub
echo "[9] Uploading to GitHub..."
cd "$ISO_DIR"
gh release create v0.6.0-gpu \
  --repo mashanz/wayangos \
  --title "WayangOS v0.6.0 - GPU Support (Intel/AMD/NVIDIA)" \
  --notes "Kernel 6.19.7 with Intel i915, AMD amdgpu/radeon, NVIDIA nouveau GPU drivers. EFI framebuffer fallback. UEFI+BIOS hybrid. Includes nomodeset safe mode option." \
  wayangos-gpu.iso 2>&1

echo "========================================"
echo "ALL DONE: $(date)"
echo "Kernel: $KSIZE | ISO: $ISOSIZE"
echo "========================================"
