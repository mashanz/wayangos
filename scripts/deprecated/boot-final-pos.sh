#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

echo "=== Build ISO with input-enabled kernel ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v3 usr/bin/kiosk-demo 2>/dev/null || cp ~/wayangos-build/fbpos-v3 usr/bin/kiosk-demo
chmod +x usr/bin/kiosk-demo

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
[ -e /dev/fb0 ] || exit 1
chmod 666 /dev/fb0
for d in /dev/input/event* /dev/input/mice; do
    [ -e "$d" ] && chmod 666 "$d"
done
chmod 666 /dev/tty0 /dev/tty1 /dev/console 2>/dev/null
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
exec /usr/bin/kiosk-demo
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-final-pos.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-final-pos.img | awk '{print $5}')"

cd ~/wayangos-build
ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-final-pos.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz quiet loglevel=1 vt.global_cursor_default=0 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-final-pos.iso "$ISO" 2>/dev/null
rm -rf "$ISO" "$WORK"
echo "ISO: $(ls -lh wayangos-final-pos.iso | awk '{print $5}')"

echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-final-pos.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-final-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Booting... sending test keys in 20s"
sleep 20

# Send keys 1, 2, 3 to add items
printf 'sendkey 1\n' | socat - UNIX-CONNECT:/tmp/qemu-final-mon
sleep 1
printf 'sendkey 2\n' | socat - UNIX-CONNECT:/tmp/qemu-final-mon
sleep 1
printf 'sendkey 3\n' | socat - UNIX-CONNECT:/tmp/qemu-final-mon
sleep 2

printf 'screendump /tmp/final-pos.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-final-mon
sleep 2
convert /tmp/final-pos.ppm /tmp/final-pos.jpg
cp /tmp/final-pos.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/final-pos.jpg"
echo "=== DONE ==="
