#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true

echo "=== Copy source ==="
cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbviewer.c" .
cp wayangos-viewer/stb_image.h .

echo "=== Build with musl (static, no deps) ==="
musl-gcc -static -O2 -o fbviewer fbviewer.c -lm 2>&1 || {
    echo "musl-gcc failed, trying gcc static..."
    gcc -static -O2 -o fbviewer fbviewer.c -lm 2>&1
}

ls -lh fbviewer
file fbviewer
echo ""

echo "=== Create test image ==="
convert -size 200x150 xc:red /tmp/test-rgb.bmp
ls -lh /tmp/test-rgb.bmp

echo ""
echo "=== Build initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

# Replace viewer with fbviewer
cp ~/wayangos-build/fbviewer usr/bin/viewer
chmod +x usr/bin/viewer

# Copy test image
cp /tmp/test-rgb.bmp root/test.bmp

# Update viewer-demo script for direct fbdev (no SDL)
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
echo "[viewer-demo] Starting framebuffer viewer..."
sleep 3

if [ -e /dev/fb0 ]; then
    echo "[viewer-demo] Found /dev/fb0"
    chmod 666 /dev/fb0
    /usr/bin/viewer /root/test.bmp &
    VIEWER_PID=$!
    sleep 2
    if kill -0 $VIEWER_PID 2>/dev/null; then
        echo "[viewer-demo] Running! (PID $VIEWER_PID)"
    else
        echo "[viewer-demo] Viewer exited"
    fi
else
    echo "[viewer-demo] No /dev/fb0 found"
fi
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-fbviewer.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-fbviewer.img | awk '{print $5}')"

echo ""
echo "=== Build ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-fbviewer.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS FB Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-fbviewer.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-fbviewer.iso | awk '{print $5}')"

echo ""
echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-fbviewer.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-fb-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/fb.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-fb-mon
sleep 2
if [ -f /tmp/fb.ppm ]; then
    convert /tmp/fb.ppm /tmp/fb.jpg
    cp /tmp/fb.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fb.jpg"
    echo "Screenshot: $(ls -lh /tmp/fb.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
