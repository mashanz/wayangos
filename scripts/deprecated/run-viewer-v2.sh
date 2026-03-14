#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Rebuilding viewer initramfs with debug ==="

WORK=$(mktemp -d)
cd $WORK

# Unpack GUI initramfs
zcat ~/wayangos-build/iso-staging-gui/boot/initramfs.img | cpio -idm 2>/dev/null

# Add viewer
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer

# Add test image
cp ~/wayangos-build/wayangos-viewer/screenshot.bmp root/test.bmp

# Create a viewer init that tries multiple SDL backends
cat > etc/init.d/viewer-demo <<'INITEOF'
#!/bin/sh
echo "[viewer-demo] Starting..."
sleep 3

# Check what display devices exist
echo "[viewer-demo] Framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || echo "  none"
echo "[viewer-demo] DRI devices:"
ls -la /dev/dri/* 2>/dev/null || echo "  none"

# Try KMSDRM first (works with virtio-gpu/bochs DRM)
if [ -e /dev/dri/card0 ]; then
    echo "[viewer-demo] Trying KMSDRM..."
    SDL_VIDEODRIVER=kmsdrm /usr/bin/viewer /root/test.bmp &
elif [ -e /dev/fb0 ]; then
    echo "[viewer-demo] Trying fbdev..."
    SDL_VIDEODRIVER=fbdev SDL_FBDEV=/dev/fb0 /usr/bin/viewer /root/test.bmp &
else
    echo "[viewer-demo] No display device found!"
    echo "[viewer-demo] Available /dev entries:"
    ls /dev/ | grep -E "fb|dri|video|gpu"
fi
INITEOF
chmod +x etc/init.d/viewer-demo

# Make sure viewer-demo runs at boot
if ! grep -q viewer-demo etc/init.d/rcS 2>/dev/null; then
    echo '/etc/init.d/viewer-demo' >> etc/init.d/rcS
fi

# Repack
find . | cpio -o -H newc 2>/dev/null | gzip > ~/wayangos-build/initramfs-viewer-v2.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-v2.img | awk '{print $5}')"

cd ~/wayangos-build
rm -rf $WORK

# Build ISO with GUI kernel
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-rt-gui "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v2.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer Demo" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-v2.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh wayangos-viewer-v2.iso | awk '{print $5}')"

# Launch QEMU with virtio-vga (best DRM support)
echo "=== Launching QEMU ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-v2.iso \
    -m 128M \
    -device virtio-vga \
    -display gtk \
    < /dev/null > /dev/null 2>&1 &

sleep 2
pgrep -a qemu && echo "QEMU RUNNING" || echo "QEMU FAILED"
