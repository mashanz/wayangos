#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Building WayangOS v0.4 RT ISOs ==="

# --- Headless ISO ---
echo "[1/2] Building Headless RT ISO..."
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"

cp vmlinuz-rt-headless "$ISO_DIR/boot/vmlinuz"
cp iso-staging-v2/boot/initramfs.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "WayangOS v0.4-rt1 Headless" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.4-rt1 Headless - Serial Only" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-0.4-rt-x86_64.iso "$ISO_DIR" 2>&1 | tail -3
rm -rf "$ISO_DIR"
echo "Headless RT ISO:"
ls -lh wayangos-0.4-rt-x86_64.iso

# --- GUI ISO ---
echo "[2/2] Building GUI RT ISO..."
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"

cp vmlinuz-rt-gui "$ISO_DIR/boot/vmlinuz"
cp iso-staging-gui/boot/initramfs.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "WayangOS v0.4-rt1 GUI Kiosk" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.4-rt1 GUI - Serial Only" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-0.4-rt-gui-x86_64.iso "$ISO_DIR" 2>&1 | tail -3
rm -rf "$ISO_DIR"
echo "GUI RT ISO:"
ls -lh wayangos-0.4-rt-gui-x86_64.iso

echo "=== DONE ==="
