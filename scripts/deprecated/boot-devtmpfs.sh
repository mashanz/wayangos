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

# Fix rcS to mount devtmpfs FIRST
cat > etc/init.d/rcS <<'RCSCRIPT'
#!/bin/sh
# Mount essential filesystems
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mkdir -p /dev/input /dev/pts /dev/shm
mount -t devpts devpts /dev/pts 2>/dev/null

# Run mdev to create any missing device nodes
mdev -s 2>/dev/null

# Set hostname
hostname wayang

# Run startup scripts
for script in /etc/init.d/S*; do
    [ -x "$script" ] && "$script" start
done
for script in /etc/init.d/viewer-demo; do
    [ -x "$script" ] && "$script"
done

# Drop to shell
exec /bin/sh
RCSCRIPT
chmod +x etc/init.d/rcS

cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 1

# Log what input devices exist
echo "=== /dev/input ===" 
ls -la /dev/input/ 2>&1

if [ ! -e /dev/fb0 ]; then
    echo "NO FB0!"
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

echo "Starting POS..."
/usr/bin/kiosk-demo &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-devtmpfs.img
cd ~/wayangos-build
rm -rf "$WORK"
echo "Initramfs: $(ls -lh initramfs-devtmpfs.img | awk '{print $5}')"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-devtmpfs.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz loglevel=4 vt.global_cursor_default=0 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-devtmpfs.iso "$ISO" 2>/dev/null
rm -rf "$ISO"
echo "ISO: $(ls -lh wayangos-devtmpfs.iso | awk '{print $5}')"

setsid qemu-system-x86_64 \
    -cdrom wayangos-devtmpfs.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-dev-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Booting... wait 25s"
sleep 25

# Send keys to test input
printf 'sendkey 1\n' | socat - UNIX-CONNECT:/tmp/qemu-dev-mon
sleep 1
printf 'sendkey 2\n' | socat - UNIX-CONNECT:/tmp/qemu-dev-mon
sleep 1
printf 'sendkey 3\n' | socat - UNIX-CONNECT:/tmp/qemu-dev-mon
sleep 2

printf 'screendump /tmp/devtmpfs.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-dev-mon
sleep 2
convert /tmp/devtmpfs.ppm /tmp/devtmpfs.jpg
cp /tmp/devtmpfs.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/devtmpfs.jpg"
echo "=== DONE ==="
