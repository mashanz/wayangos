#!/bin/bash
set -e
BUILD=$HOME/wayangos-build
ROOTFS=$BUILD/rootfs-gui

rm -rf $ROOTFS
cp -a $BUILD/rootfs-v2 $ROOTFS

# Add kiosk binary
cp $BUILD/kiosk-demo $ROOTFS/usr/bin/kiosk-demo
chmod 755 $ROOTFS/usr/bin/kiosk-demo

# Add kiosk init script
cp $BUILD/kiosk-init.sh $ROOTFS/etc/init.d/kiosk
chmod +x $ROOTFS/etc/init.d/kiosk

# DRM device dir
mkdir -p $ROOTFS/dev/dri

# Add kiosk start to boot
sed -i '/WayangOS v0.2 ready/a # Start kiosk\n\/etc\/init.d\/kiosk start' $ROOTFS/etc/init.d/rcS

echo "rcS kiosk lines:"
grep -A2 "kiosk" $ROOTFS/etc/init.d/rcS

# Build initramfs
cd $ROOTFS
find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > $BUILD/wayangos-0.2-gui-x86_64-initramfs.img

echo "GUI initramfs: $(du -h $BUILD/wayangos-0.2-gui-x86_64-initramfs.img | cut -f1)"

# Build ISO
cp $BUILD/build-gui-iso.sh $BUILD/build-gui-iso-run.sh 2>/dev/null || true
ISO_DIR=$BUILD/iso-staging-gui
KERNEL=$BUILD/vmlinuz-gui
INITRD=$BUILD/wayangos-0.2-gui-x86_64-initramfs.img
OUTPUT=$BUILD/wayangos-0.2-gui-x86_64.iso

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

menuentry "WayangOS v0.2 GUI (Serial Console)" {
    linux /boot/vmlinuz console=ttyS0,115200
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o $OUTPUT $ISO_DIR -- -volid WAYANGOS_GUI 2>&1

echo ""
echo "=== Results ==="
ls -lh $OUTPUT
echo "=== Done ==="
