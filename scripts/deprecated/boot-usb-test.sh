#!/bin/bash
set -e
cd ~/wayangos-build
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-inputtest.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
menuentry "WayangOS Input Test" {
    linux /boot/vmlinuz loglevel=4 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-inputtest2.iso "$ISO" 2>/dev/null
rm -rf "$ISO"

setsid qemu-system-x86_64 \
    -cdrom wayangos-inputtest2.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -usb -device usb-kbd -device usb-mouse \
    -monitor unix:/tmp/qemu-it2-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Booting with USB keyboard..."
sleep 18
printf 'screendump /tmp/it2.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-it2-mon
sleep 2
convert /tmp/it2.ppm /tmp/it2.jpg
cp /tmp/it2.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/it2.jpg"
echo DONE
