#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbpos-v2.c" .

echo "=== Build POS v2 ==="
gcc -static -O2 -o fbpos-v2 fbpos-v2.c -lm 2>&1
ls -lh fbpos-v2

echo "=== Build initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v2 usr/bin/kiosk-demo
chmod +x usr/bin/kiosk-demo

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
[ -e /dev/fb0 ] || exit 1
chmod 666 /dev/fb0
chmod 666 /dev/input/event* 2>/dev/null
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
/usr/bin/kiosk-demo &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-pos-v2.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-pos-v2.img | awk '{print $5}')"

cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-pos-v2.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz quiet loglevel=1 vt.global_cursor_default=0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-pos-v2.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-pos-v2.iso | awk '{print $5}')"

echo "=== Boot with keyboard + mouse ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-pos-v2.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -monitor unix:/tmp/qemu-posv2-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/posv2.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-posv2-mon
sleep 2
if [ -f /tmp/posv2.ppm ]; then
    convert /tmp/posv2.ppm /tmp/posv2.jpg
    cp /tmp/posv2.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/posv2.jpg"
    echo "Screenshot: $(ls -lh /tmp/posv2.jpg | awk '{print $5}')"
fi
echo "=== DONE ==="
