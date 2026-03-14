#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

echo "=== Update viewer-demo to disable text console ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-demo.img | cpio -id 2>/dev/null

# Fix: disable framebuffer console text before drawing
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2

if [ ! -e /dev/fb0 ]; then
    echo "[demo] No /dev/fb0!"
    exit 1
fi

chmod 666 /dev/fb0

# Disable fbcon cursor and text
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null

# Clear the screen first (write zeros to fb)
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null

# Run POS kiosk
/usr/bin/kiosk-demo &
KIOSK_PID=$!
sleep 10

# Switch to viewer
kill $KIOSK_PID 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
/usr/bin/viewer /root/test.bmp &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-clean-demo.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-clean-demo.img | awk '{print $5}')"

cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-clean-demo.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Demo" {
    linux /boot/vmlinuz console=tty0 loglevel=1 vt.global_cursor_default=0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-clean-demo.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-clean-demo.iso | awk '{print $5}')"

echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-clean-demo.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-clean-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 3
pgrep -a qemu && echo "RUNNING - check your desktop!"

# Take POS screenshot at ~15s
sleep 12
printf 'screendump /tmp/pos-clean.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-clean-mon
sleep 2
if [ -f /tmp/pos-clean.ppm ]; then
    convert /tmp/pos-clean.ppm /tmp/pos-clean.jpg
    cp /tmp/pos-clean.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/pos-clean.jpg"
    echo "POS screenshot: $(ls -lh /tmp/pos-clean.jpg | awk '{print $5}')"
fi

# Take viewer screenshot at ~25s
sleep 10
printf 'screendump /tmp/viewer-clean.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-clean-mon
sleep 2
if [ -f /tmp/viewer-clean.ppm ]; then
    convert /tmp/viewer-clean.ppm /tmp/viewer-clean.jpg
    cp /tmp/viewer-clean.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/viewer-clean.jpg"
    echo "Viewer screenshot: $(ls -lh /tmp/viewer-clean.jpg | awk '{print $5}')"
fi

echo "=== DONE ==="
