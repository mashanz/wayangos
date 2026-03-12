#!/bin/bash
set -e
cd ~/wayangos-build

VER="0.5"

build_iso() {
    local NAME="$1"
    local KERNEL="$2"
    local INITRAMFS="$3"
    local LABEL="$4"

    echo "[*] Building $NAME..."
    ISO_DIR=$(mktemp -d)
    mkdir -p "$ISO_DIR/boot/grub"
    cp "$KERNEL" "$ISO_DIR/boot/vmlinuz"
    cp "$INITRAMFS" "$ISO_DIR/boot/initramfs.img"

    cat > "$ISO_DIR/boot/grub/grub.cfg" <<GRUBEOF
set timeout=5
set default=0

menuentry "$LABEL" {
    linux /boot/vmlinuz console=ttyS0 console=tty0
    initrd /boot/initramfs.img
}

menuentry "$LABEL - Serial Only" {
    linux /boot/vmlinuz console=ttyS0
    initrd /boot/initramfs.img
}
GRUBEOF

    grub-mkrescue -o "$NAME" "$ISO_DIR" 2>&1 | tail -1
    rm -rf "$ISO_DIR"
    ls -lh "$NAME"
}

echo "=== Building WayangOS v${VER} — All Editions ==="

# 1. Headless (no RT) — 6.19.7
build_iso "wayangos-${VER}-headless-x86_64.iso" \
    vmlinuz-6.19.7 \
    iso-staging-v2/boot/initramfs.img \
    "WayangOS v${VER} Headless"

# 2. Headless RT — 6.19.3-rt1
build_iso "wayangos-${VER}-headless-rt-x86_64.iso" \
    vmlinuz-rt-headless \
    iso-staging-v2/boot/initramfs.img \
    "WayangOS v${VER} Headless RT"

# 3. GUI (no RT) — 6.19.7
build_iso "wayangos-${VER}-gui-x86_64.iso" \
    vmlinuz-gui-6.19.7 \
    iso-staging-gui/boot/initramfs.img \
    "WayangOS v${VER} GUI"

# 4. GUI RT — 6.19.3-rt1
build_iso "wayangos-${VER}-gui-rt-x86_64.iso" \
    vmlinuz-rt-gui \
    iso-staging-gui/boot/initramfs.img \
    "WayangOS v${VER} GUI RT"

echo ""
echo "=== All 4 editions built ==="
ls -lh wayangos-${VER}-*.iso
