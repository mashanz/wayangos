#!/bin/bash
set -e

BUILD=~/wayangos-build
ISO_DIR=$BUILD/iso-staging
KERNEL=$BUILD/wayangos-0.1-x86_64/vmlinuz
INITRD=$BUILD/wayangos-0.1-x86_64/initramfs.img
OUTPUT=$BUILD/wayangos-0.1-x86_64.iso

echo "=== Building WayangOS Bootable ISO ==="

rm -rf $ISO_DIR
mkdir -p $ISO_DIR/boot/grub

cp $KERNEL $ISO_DIR/boot/vmlinuz
cp $INITRD $ISO_DIR/boot/initramfs.img

cat > $ISO_DIR/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

set menu_color_normal=light-gray/black
set menu_color_highlight=yellow/black

menuentry "WayangOS v0.1 (x86_64)" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.1 (Serial Console)" {
    linux /boot/vmlinuz console=ttyS0,115200
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.1 (Quiet Boot)" {
    linux /boot/vmlinuz console=tty0 quiet
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o $OUTPUT $ISO_DIR -- -volid WAYANGOS 2>&1

ls -lh $OUTPUT
echo "=== ISO Ready ==="
