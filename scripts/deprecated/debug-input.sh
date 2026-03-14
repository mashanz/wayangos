#!/bin/bash
# Boot a debug shell to check /dev/input devices inside QEMU
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

# Replace init with debug script
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 3
echo "=== /dev/input ==="
ls -la /dev/input/ 2>&1
echo ""
echo "=== /dev/tty* ==="
ls -la /dev/tty* 2>&1 | head -10
echo ""
echo "=== dmesg input ==="
dmesg | grep -i "input\|keyboard\|mouse\|hid\|usb" | head -20
echo ""
echo "=== evtest-style check ==="
for d in /dev/input/event*; do
    echo "Device: $d"
    cat $d | xxd | head -3 &
done
sleep 5
echo "=== DONE ==="
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-debug.img
rm -rf "$WORK"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO/boot/vmlinuz"
cp initramfs-debug.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Debug" {
    linux /boot/vmlinuz loglevel=4 video=1024x600
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-debug.iso "$ISO" 2>/dev/null
rm -rf "$ISO"

setsid qemu-system-x86_64 \
    -cdrom wayangos-debug.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -usb -device usb-tablet \
    -serial file:/tmp/debug-serial.txt \
    -monitor unix:/tmp/qemu-dbg-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

echo "Waiting for boot..."
sleep 25
printf 'screendump /tmp/debug.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-dbg-mon
sleep 1
convert /tmp/debug.ppm /tmp/debug.jpg
cp /tmp/debug.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/debug.jpg"
echo "DONE"
