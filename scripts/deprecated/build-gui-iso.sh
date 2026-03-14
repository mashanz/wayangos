#!/bin/bash
set -e

BUILD=~/wayangos-build
ISO_DIR=$BUILD/iso-staging-gui
KERNEL=$BUILD/vmlinuz-gui
INITRD=$BUILD/wayangos-0.2-gui-x86_64-initramfs.img
OUTPUT=$BUILD/wayangos-0.2-gui-x86_64.iso

echo "=== Building WayangOS v0.2 GUI ISO ==="

rm -rf $ISO_DIR
mkdir -p $ISO_DIR/boot/grub

cp $KERNEL $ISO_DIR/boot/vmlinuz
cp $INITRD $ISO_DIR/boot/initramfs.img

cat > $ISO_DIR/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

set menu_color_normal=light-gray/black
set menu_color_highlight=yellow/black

menuentry "WayangOS v0.2 GUI (Kiosk + SSH)" {
    linux /boot/vmlinuz console=tty0 fbcon=font:VGA8x16
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.2 GUI (Headless/Serial)" {
    linux /boot/vmlinuz console=ttyS0,115200
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.2 GUI (Quiet)" {
    linux /boot/vmlinuz console=tty0 quiet
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o $OUTPUT $ISO_DIR -- -volid WAYANGOS_GUI 2>&1

echo ""
echo "=== GUI ISO ==="
ls -lh $OUTPUT
echo "=== Done ==="
