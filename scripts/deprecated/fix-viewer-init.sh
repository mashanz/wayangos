#!/bin/bash
set -e
cd ~/wayangos-build

# Kill old QEMU
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

# Extract initramfs
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v2.img | cpio -id 2>/dev/null

echo "=== Old viewer-demo ==="
cat etc/init.d/viewer-demo

# Fix: try fbdev first, then kmsdrm with proper permissions
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
echo "[viewer-demo] Starting..."
sleep 3

# Check what display devices exist
echo "[viewer-demo] Framebuffer devices:"
ls -la /dev/fb* 2>/dev/null || echo "  none"
echo "[viewer-demo] DRI devices:"
ls -la /dev/dri/* 2>/dev/null || echo "  none"

# Ensure permissions
chmod 666 /dev/fb0 2>/dev/null
chmod 666 /dev/dri/card0 2>/dev/null
chmod 666 /dev/dri/renderD128 2>/dev/null

# Try fbdev first (most reliable on minimal systems)
if [ -e /dev/fb0 ]; then
    echo "[viewer-demo] Trying fbdev..."
    SDL_VIDEODRIVER=fbdev SDL_FBDEV=/dev/fb0 /usr/bin/viewer /root/test.bmp &
    VIEWER_PID=$!
    sleep 2
    if kill -0 $VIEWER_PID 2>/dev/null; then
        echo "[viewer-demo] Running on fbdev (PID $VIEWER_PID)"
        exit 0
    fi
    echo "[viewer-demo] fbdev failed, trying kmsdrm..."
fi

# Try kmsdrm
if [ -e /dev/dri/card0 ]; then
    echo "[viewer-demo] Trying KMSDRM..."
    SDL_VIDEODRIVER=kmsdrm /usr/bin/viewer /root/test.bmp &
    VIEWER_PID=$!
    sleep 2
    if kill -0 $VIEWER_PID 2>/dev/null; then
        echo "[viewer-demo] Running on kmsdrm (PID $VIEWER_PID)"
        exit 0
    fi
    echo "[viewer-demo] kmsdrm also failed"
fi

echo "[viewer-demo] No working display backend!"
SCRIPT
chmod +x etc/init.d/viewer-demo

# Also fix the kiosk script to try fbdev first
cat > etc/init.d/kiosk <<'SCRIPT'
#!/bin/sh
case "$1" in
    start)
        echo "  Starting kiosk display..."
        sleep 1
        if [ -e /dev/fb0 ]; then
            export SDL_VIDEODRIVER=fbdev
            export SDL_FBDEV=/dev/fb0
        elif [ -e /dev/dri/card0 ]; then
            export SDL_VIDEODRIVER=kmsdrm
        fi
        /usr/bin/kiosk-demo 2>/dev/null &
        echo "  Kiosk running on display"
        ;;
    stop)
        killall kiosk-demo 2>/dev/null
        ;;
esac
SCRIPT
chmod +x etc/init.d/kiosk

echo ""
echo "=== New viewer-demo ==="
cat etc/init.d/viewer-demo

# Rebuild initramfs
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-v3.img
echo ""
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-v3.img | awk '{print $5}')"

# Build ISO
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v3.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer Test" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-v3-test.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-v3-test.iso | awk '{print $5}')"

# Boot
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-v3-test.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-v3t-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 20

# Screenshot
printf 'screendump /tmp/viewer-v3t.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-v3t-mon
sleep 2
if [ -f /tmp/viewer-v3t.ppm ]; then
    convert /tmp/viewer-v3t.ppm /tmp/viewer-v3t.jpg
    cp /tmp/viewer-v3t.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/viewer-v3t.jpg"
    echo "Screenshot saved! $(ls -lh /tmp/viewer-v3t.jpg | awk '{print $5}')"
fi
echo "=== DONE ==="
