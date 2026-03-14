#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

# Enable PCI (required for DRM_BOCHS)
./scripts/config --enable PCI
./scripts/config --enable PCI_QUIRKS
./scripts/config --enable MMU
./scripts/config --enable SHMEM

# Enable DRM drivers
./scripts/config --enable DRM
./scripts/config --enable DRM_BOCHS
./scripts/config --enable DRM_VIRTIO_GPU
./scripts/config --enable DRM_FBDEV_EMULATION
./scripts/config --enable DRM_SIMPLEDRM
./scripts/config --enable DRM_GEM_SHMEM_HELPER

# Framebuffer
./scripts/config --enable FB
./scripts/config --enable FB_VESA
./scripts/config --enable FRAMEBUFFER_CONSOLE

# Virtio
./scripts/config --enable VIRTIO
./scripts/config --enable VIRTIO_PCI
./scripts/config --enable VIRTIO_MMIO

# Input
./scripts/config --enable INPUT_EVDEV

make olddefconfig 2>&1 | tail -3

echo "=== Verify ==="
grep -E "CONFIG_PCI=|CONFIG_DRM=|CONFIG_DRM_BOCHS=|CONFIG_DRM_VIRTIO_GPU=|CONFIG_FB=|CONFIG_FRAMEBUFFER_CONSOLE=" .config

echo "=== Building ==="
make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-gui-v3
ls -lh ~/wayangos-build/vmlinuz-rt-gui-v3

# Build ISO
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp ~/wayangos-build/vmlinuz-rt-gui-v3 "$ISO_DIR/boot/vmlinuz"
cp ~/wayangos-build/initramfs-viewer-v2.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer Demo" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o ~/wayangos-build/wayangos-viewer-v3.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh ~/wayangos-build/wayangos-viewer-v3.iso | awk '{print $5}')"

# Launch
setsid qemu-system-x86_64 \
    -cdrom ~/wayangos-build/wayangos-viewer-v3.iso \
    -m 128M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-v3-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 3
pgrep -a qemu && echo "QEMU RUNNING"

# Wait for boot + viewer init
sleep 18

# Capture
echo "screendump /tmp/viewer-v3.ppm" | socat - UNIX-CONNECT:/tmp/qemu-v3-mon
sleep 2
if [ -f /tmp/viewer-v3.ppm ]; then
    convert /tmp/viewer-v3.ppm /tmp/viewer-v3.jpg
    cp "/tmp/viewer-v3.jpg" "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/viewer-v3.jpg"
    echo "Screenshot captured!"
fi
echo "=== DONE ==="
