#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

# Copy POS source
cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbpos.c" .

echo "=== Build POS ==="
gcc -static -O2 -o fbpos fbpos.c -lm 2>&1
ls -lh fbpos
file fbpos

echo ""
echo "=== Build initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

cp ~/wayangos-build/fbpos usr/bin/kiosk-demo
cp ~/wayangos-build/fbviewer usr/bin/viewer
chmod +x usr/bin/kiosk-demo usr/bin/viewer
cp /tmp/test-rgb.bmp root/test.bmp

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
if [ ! -e /dev/fb0 ]; then exit 1; fi
chmod 666 /dev/fb0
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
/usr/bin/kiosk-demo &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-real-pos.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-real-pos.img | awk '{print $5}')"

cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-real-pos.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz quiet loglevel=1 vt.global_cursor_default=0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-real-pos.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-real-pos.iso | awk '{print $5}')"

echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-real-pos.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-rpos-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/rpos.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-rpos-mon
sleep 2
if [ -f /tmp/rpos.ppm ]; then
    convert /tmp/rpos.ppm /tmp/rpos.jpg
    cp /tmp/rpos.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/rpos.jpg"
    echo "Screenshot: $(ls -lh /tmp/rpos.jpg | awk '{print $5}')"
fi
echo "=== DONE ==="
