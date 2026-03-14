#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Building Viewer Demo ISO ==="
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"

cp vmlinuz-rt-gui "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-demo.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=3
set default=0

menuentry "WayangOS Viewer Demo" {
    linux /boot/vmlinuz console=ttyS0 console=tty0 vga=791
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-demo.iso "$ISO_DIR" 2>&1 | tail -1
rm -rf "$ISO_DIR"
echo "ISO:"
ls -lh wayangos-viewer-demo.iso
echo "=== DONE ==="
