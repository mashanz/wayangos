#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/input-test.c" .
gcc -static -O2 -o input-test input-test.c
echo "Built: $(ls -lh input-test)"

WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/input-test usr/bin/input-test
chmod +x usr/bin/input-test

# Simple init: just run the test on console (NO fbcon unbind, NO POS)
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/input
mdev -s 2>/dev/null || true
chmod 666 /dev/input/* 2>/dev/null
echo ""
echo "Running input test..."
/usr/bin/input-test
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-inputtest.img
cd ~/wayangos-build
rm -rf "$WORK"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-inputtest.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Input Test" {
    linux /boot/vmlinuz loglevel=4 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-inputtest.iso "$ISO" 2>/dev/null
rm -rf "$ISO"

echo "=== Booting ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-inputtest.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-it-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 15
# Take screenshot to see the test output
printf 'screendump /tmp/inputtest.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-it-mon
sleep 2
convert /tmp/inputtest.ppm /tmp/inputtest.jpg
cp /tmp/inputtest.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/inputtest.jpg"
echo "DONE - check QEMU window and try pressing keys"
