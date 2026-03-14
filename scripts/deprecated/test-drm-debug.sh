#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Building debug ISO with verbose DRM logging ==="
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-rt-gui-v3 "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v2.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Debug" {
    linux /boot/vmlinuz console=tty0 drm.debug=0x0f
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-debug.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh wayangos-debug.iso | awk '{print $5}')"

echo "=== Booting and logging for 20s ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-debug.iso \
    -m 256M \
    -vga std \
    -serial file:/tmp/qemu-debug.log \
    -display none \
    < /dev/null > /dev/null 2>&1 &

QEMU_PID=$!
sleep 20
kill -9 $QEMU_PID 2>/dev/null || true

echo "=== Boot log (last 50 lines) ==="
tail -50 /tmp/qemu-debug.log

echo ""
echo "=== Searching for DRM/FB messages ===" 
grep -i "drm\|framebuffer\|bochs\|simpledrm" /tmp/qemu-debug.log | head -20 || echo "No matches found"

cp /tmp/qemu-debug.log "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/boot-log.txt"
echo "Full log saved to Windows"
