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

# Write a simple test binary that logs input info
cat > usr/bin/input-test.sh <<'TEST'
#!/bin/sh
LOG=/tmp/input-debug.txt
echo "=== INPUT DEVICES ===" > $LOG
ls -la /dev/input/ >> $LOG 2>&1
echo "" >> $LOG
echo "=== /dev/tty ===" >> $LOG
ls -la /dev/tty* 2>&1 | head -10 >> $LOG
echo "" >> $LOG
echo "=== dmesg input ===" >> $LOG
dmesg 2>/dev/null | grep -i "input\|keyboard\|mouse\|evdev\|i8042\|serio\|atkbd" | head -20 >> $LOG
echo "" >> $LOG
echo "=== /proc/bus/input/devices ===" >> $LOG
cat /proc/bus/input/devices >> $LOG 2>&1
echo "" >> $LOG
echo "DONE" >> $LOG
TEST
chmod +x usr/bin/input-test.sh

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 3
/usr/bin/input-test.sh
if [ -e /dev/fb0 ]; then
    chmod 666 /dev/fb0
    for d in /dev/input/event* /dev/input/mice; do
        [ -e "$d" ] && chmod 666 "$d"
    done
    chmod 666 /dev/tty0 /dev/tty1 /dev/console 2>/dev/null
    echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
    echo 0 > /proc/sys/kernel/printk 2>/dev/null
    dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
    /usr/bin/kiosk-demo >> /tmp/pos-debug.txt 2>&1 &
fi
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-debug3.img
cd ~/wayangos-build
rm -rf "$WORK"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-debug3.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS Debug" {
    linux /boot/vmlinuz loglevel=4 vt.global_cursor_default=0 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-debug3.iso "$ISO" 2>/dev/null
rm -rf "$ISO"

setsid qemu-system-x86_64 \
    -cdrom wayangos-debug3.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-dbg3-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Waiting 20s for boot..."
sleep 20

# Dump /tmp/input-debug.txt from inside VM via screendump won't work
# Instead let's take a screenshot - the debug output should be on screen since no fbcon unbind yet
printf 'screendump /tmp/dbg3.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 2
convert /tmp/dbg3.ppm /tmp/dbg3.jpg
cp /tmp/dbg3.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/dbg3.jpg"
echo "Screenshot taken"

# Also try to get the log via guestfish or similar... 
# Actually, we can read it by sending commands to the VM shell
printf 'sendkey c\nsendkey a\nsendkey t\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 1
printf 'sendkey spc\nsendkey slash\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 0.5
printf 'sendkey t\nsendkey m\nsendkey p\nsendkey slash\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 0.5
printf 'sendkey i\nsendkey n\nsendkey p\nsendkey u\nsendkey t\nsendkey minus\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 0.5
printf 'sendkey d\nsendkey e\nsendkey b\nsendkey u\nsendkey g\nsendkey dot\nsendkey t\nsendkey x\nsendkey t\nsendkey ret\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 3

printf 'screendump /tmp/dbg3b.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg3-mon
sleep 2
convert /tmp/dbg3b.ppm /tmp/dbg3b.jpg
cp /tmp/dbg3b.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/dbg3b.jpg"
echo "=== DONE ==="
