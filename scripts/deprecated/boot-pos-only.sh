#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-demo.img | cpio -id 2>/dev/null

# Only run POS kiosk, no switching, no debug text
cat > etc/init.d/viewer-demo <<'SCRIPT'
#!/bin/sh
sleep 2
if [ ! -e /dev/fb0 ]; then exit 1; fi
chmod 666 /dev/fb0
# Disable console text on framebuffer
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
# Clear screen
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
# Run POS only
/usr/bin/kiosk-demo &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-pos-only.img

cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-pos-only.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz console=tty0 loglevel=1 vt.global_cursor_default=0 quiet
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-pos-only.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"

setsid qemu-system-x86_64 \
    -cdrom wayangos-pos-only.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-pos-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 3
pgrep -a qemu && echo "RUNNING"

sleep 17
printf 'screendump /tmp/pos-only.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-pos-mon
sleep 2
if [ -f /tmp/pos-only.ppm ]; then
    convert /tmp/pos-only.ppm /tmp/pos-only.jpg
    cp /tmp/pos-only.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/pos-only.jpg"
    echo "Screenshot: $(ls -lh /tmp/pos-only.jpg | awk '{print $5}')"
fi
echo "DONE"
