#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

echo "=== Building POS kiosk ==="
cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbkiosk.c" .
gcc -static -O2 -o fbkiosk fbkiosk.c -lm 2>&1
ls -lh fbkiosk
file fbkiosk

echo ""
echo "=== Building initramfs with both demos ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

# Copy both binaries
cp ~/wayangos-build/fbviewer usr/bin/viewer
cp ~/wayangos-build/fbkiosk usr/bin/kiosk-demo
chmod +x usr/bin/viewer usr/bin/kiosk-demo

# Copy test image
cp /tmp/test-rgb.bmp root/test.bmp

# Update init script: run POS kiosk first, then viewer after 10s
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
echo "[kiosk] Starting POS kiosk demo..."
sleep 2

if [ -e /dev/fb0 ]; then
    chmod 666 /dev/fb0

    # Show POS kiosk for 10 seconds
    echo "[kiosk] Launching POS interface..."
    /usr/bin/kiosk-demo &
    KIOSK_PID=$!
    sleep 10

    # Then switch to image viewer
    kill $KIOSK_PID 2>/dev/null
    echo "[viewer] Switching to image viewer..."
    /usr/bin/viewer /root/test.bmp &
else
    echo "[kiosk] No /dev/fb0!"
fi
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-demo.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-demo.img | awk '{print $5}')"

echo ""
echo "=== Build ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-demo.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Demo" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-demo.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-demo.iso | awk '{print $5}')"

echo ""
echo "=== Booting - check QEMU window on your desktop! ==="
qemu-system-x86_64 \
    -cdrom wayangos-demo.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-demo-mon,server,nowait &
echo "QEMU started. Watch the window!"
