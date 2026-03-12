#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Building WayangOS v0.3 ISOs ==="

# --- Headless ISO ---
echo "[1/2] Building Headless ISO..."
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"

cp vmlinuz-6.19.7 "$ISO_DIR/boot/vmlinuz"
cp iso-staging-v2/boot/initramfs.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "WayangOS v0.3 - Headless" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.3 - Headless (Serial Only)" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-0.3-x86_64.iso "$ISO_DIR" 2>&1 | tail -3
rm -rf "$ISO_DIR"
echo "Headless ISO:"
ls -lh wayangos-0.3-x86_64.iso

# --- GUI ISO ---
echo "[2/2] Building GUI ISO..."
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"

cp vmlinuz-gui-6.19.7 "$ISO_DIR/boot/vmlinuz"
cp iso-staging-gui/boot/initramfs.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=5
set default=0

menuentry "WayangOS v0.3 - GUI Kiosk" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.img
}

menuentry "WayangOS v0.3 - GUI (Serial Only)" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-0.3-gui-x86_64.iso "$ISO_DIR" 2>&1 | tail -3
rm -rf "$ISO_DIR"
echo "GUI ISO:"
ls -lh wayangos-0.3-gui-x86_64.iso

echo "=== DONE ==="
