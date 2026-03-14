#!/bin/bash
set -e

BUILD=~/wayangos-build
ISO_DIR=$BUILD/iso-staging-v2
KERNEL=$BUILD/wayangos-0.1-x86_64/vmlinuz
INITRD=$BUILD/wayangos-0.2-x86_64-initramfs.img
OUTPUT=$BUILD/wayangos-0.2-x86_64.iso
TARBALL=$BUILD/wayangos-0.2-x86_64.tar.gz

echo "=== Building WayangOS v0.2 ISO ==="

rm -rf $ISO_DIR
mkdir -p $ISO_DIR/boot/grub

cp $KERNEL $ISO_DIR/boot/vmlinuz
cp $INITRD $ISO_DIR/boot/initramfs.img

cat > $ISO_DIR/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

set menu_color_normal=light-gray/black
set menu_color_highlight=yellow/black

menuentry "WayangOS v0.2" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.2 (Serial Console)" {
    linux /boot/vmlinuz console=ttyS0,115200
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.2 (Quiet)" {
    linux /boot/vmlinuz console=tty0 quiet
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o $OUTPUT $ISO_DIR -- -volid WAYANGOS 2>&1

# Also build tar.gz
PKGDIR=$BUILD/wayangos-0.2-x86_64
rm -rf $PKGDIR
mkdir -p $PKGDIR
cp $KERNEL $PKGDIR/vmlinuz
cp $INITRD $PKGDIR/initramfs.img
cat > $PKGDIR/run-qemu.sh << 'QEMU'
#!/bin/sh
qemu-system-x86_64 -kernel vmlinuz -initrd initramfs.img -append "console=ttyS0" -nographic -m 128M -nic user
QEMU
chmod +x $PKGDIR/run-qemu.sh

cat > $PKGDIR/README.md << 'README'
# WayangOS v0.2 (x86_64)

Minimal deployment Linux. Static binaries, no package manager.

## What's included
- Linux kernel 6.12.6
- BusyBox (shell, networking, utils)
- Dropbear SSH server + client
- curl with TLS
- Auto DHCP + SSH on boot

## Boot with QEMU
./run-qemu.sh

## Default access
- Root login, no password (set one with `passwd`)
- SSH on port 22 (add your key to /root/.ssh/authorized_keys)
- DHCP auto-configures networking
README

cd $BUILD
tar czf $TARBALL -C $BUILD wayangos-0.2-x86_64/

echo ""
echo "=== Results ==="
ls -lh $OUTPUT
ls -lh $TARBALL
echo "=== Done ==="
