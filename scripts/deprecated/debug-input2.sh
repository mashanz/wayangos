#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v3 usr/bin/kiosk-demo
chmod +x usr/bin/kiosk-demo

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
echo "=== INPUT DEVICES ===" > /dev/ttyS0 2>/dev/null
ls -la /dev/input/ > /dev/ttyS0 2>&1
echo "" > /dev/ttyS0
echo "=== TTY DEVICES ===" > /dev/ttyS0
ls /dev/tty* 2>&1 | head -5 > /dev/ttyS0
echo "" > /dev/ttyS0
echo "=== DMESG INPUT ===" > /dev/ttyS0
dmesg 2>/dev/null | grep -i "input\|keyboard\|mouse\|evdev\|i8042\|serio" | head -15 > /dev/ttyS0

if [ ! -e /dev/fb0 ]; then
    echo "NO FB0!" > /dev/ttyS0
    exit 1
fi
chmod 666 /dev/fb0
for d in /dev/input/event* /dev/input/mice; do
    [ -e "$d" ] && chmod 666 "$d"
done
chmod 666 /dev/tty0 /dev/tty1 /dev/console 2>/dev/null
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
echo "Starting POS..." > /dev/ttyS0
/usr/bin/kiosk-demo 2>/dev/ttyS0 &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-debug2.img
cd ~/wayangos-build
rm -rf "$WORK"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-debug2.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS Debug" {
    linux /boot/vmlinuz quiet loglevel=4 vt.global_cursor_default=0 video=1024x600 console=tty0 console=ttyS0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-debug2.iso "$ISO" 2>/dev/null
rm -rf "$ISO"

setsid qemu-system-x86_64 \
    -cdrom wayangos-debug2.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -serial file:/tmp/serial-debug.log \
    -monitor unix:/tmp/qemu-dbg2-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Waiting 20s for boot..."
sleep 20
echo "=== SERIAL OUTPUT ==="
cat /tmp/serial-debug.log 2>/dev/null | head -50
echo ""
echo "=== END ==="
