#!/bin/bash
set -e
cd ~/wayangos-build

ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-rt-headless "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-demo.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0 vga=791
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-test.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
ls -lh wayangos-viewer-test.iso
echo DONE
