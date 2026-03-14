#!/bin/bash
set -e
cd ~/wayangos-build

# Kill old QEMU
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

# Build ISO with fixed kernel
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-rt-gui-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v2.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer Demo" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-fixed.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh wayangos-viewer-fixed.iso | awk '{print $5}')"

# Launch QEMU
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-fixed.iso \
    -m 128M \
    -device virtio-vga \
    -display gtk \
    -monitor unix:/tmp/qemu-fixed-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 3
pgrep -a qemu && echo "QEMU RUNNING"

# Wait for boot + viewer
sleep 15

# Capture screen
echo "screendump /tmp/viewer-fixed.ppm" | socat - UNIX-CONNECT:/tmp/qemu-fixed-mon
sleep 2
if [ -f /tmp/viewer-fixed.ppm ]; then
    convert /tmp/viewer-fixed.ppm /tmp/viewer-fixed.jpg
    cp /tmp/viewer-fixed.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/viewer-fixed.jpg"
    echo "Screenshot saved: $(ls -lh /tmp/viewer-fixed.jpg | awk '{print $5}')"
fi
