#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbpos-v3.c" .

echo "=== Build ==="
gcc -static -O2 -o fbpos-v3 fbpos-v3.c -lm 2>&1
ls -lh fbpos-v3
file fbpos-v3

echo "=== Initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v3 usr/bin/kiosk-demo
chmod +x usr/bin/kiosk-demo

# Init: set up fb + input, then run POS
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
[ -e /dev/fb0 ] || exit 1
chmod 666 /dev/fb0
# Make input devices accessible
for d in /dev/input/event* /dev/input/mice; do
    [ -e "$d" ] && chmod 666 "$d"
done
# Make tty accessible
chmod 666 /dev/tty0 /dev/tty1 /dev/console 2>/dev/null
# Disable fbcon
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
# Clear
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
# Run POS
/usr/bin/kiosk-demo &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-pos-v3.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-pos-v3.img | awk '{print $5}')"

cd ~/wayangos-build
ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO/boot/vmlinuz"
cp initramfs-pos-v3.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz quiet loglevel=1 vt.global_cursor_default=0 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-pos-v3.iso "$ISO" 2>/dev/null
rm -rf "$ISO" "$WORK"
echo "ISO: $(ls -lh wayangos-pos-v3.iso | awk '{print $5}')"

echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-pos-v3.iso \
    -m 256M \
    -vga std \
    -display gtk,window-close=off \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -usb -device usb-tablet \
    -monitor unix:/tmp/qemu-v3-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/v3.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-v3-mon
sleep 2
if [ -f /tmp/v3.ppm ]; then
    convert /tmp/v3.ppm /tmp/v3.jpg
    cp /tmp/v3.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/posv3.jpg"
    echo "Screenshot saved"
fi
echo "=== DONE ==="
