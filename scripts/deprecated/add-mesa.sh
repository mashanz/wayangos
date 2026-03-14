#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true

echo "=== Find Mesa DRI drivers ==="
find /usr/lib/x86_64-linux-gnu -name "dri_gbm.so" -o -name "swrast_dri.so" -o -name "*_dri.so" 2>/dev/null | head -10
ls /usr/lib/x86_64-linux-gnu/dri/ 2>/dev/null | head -10
ls /usr/lib/x86_64-linux-gnu/gbm/ 2>/dev/null | head -5

echo ""
echo "=== Find Mesa EGL platform ==="
find /usr/lib/x86_64-linux-gnu -name "*egl*" -o -name "*mesa*" 2>/dev/null | grep -v include | head -10

echo ""
echo "=== Extract initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-final2.img | cpio -id 2>/dev/null

echo "=== Copy Mesa DRI drivers ==="
mkdir -p usr/lib/x86_64-linux-gnu/dri usr/lib/x86_64-linux-gnu/gbm

# GBM backend
if [ -f /usr/lib/x86_64-linux-gnu/gbm/dri_gbm.so ]; then
    cp /usr/lib/x86_64-linux-gnu/gbm/dri_gbm.so usr/lib/x86_64-linux-gnu/gbm/
fi

# Software rasterizer (for QEMU without GPU)
if [ -f /usr/lib/x86_64-linux-gnu/dri/swrast_dri.so ]; then
    cp /usr/lib/x86_64-linux-gnu/dri/swrast_dri.so usr/lib/x86_64-linux-gnu/dri/
fi

# Bochs/virtio DRI drivers (for QEMU VGA)
for drv in bochs_dri.so virtio_gpu_dri.so kms_swrast_dri.so; do
    if [ -f "/usr/lib/x86_64-linux-gnu/dri/$drv" ]; then
        cp "/usr/lib/x86_64-linux-gnu/dri/$drv" usr/lib/x86_64-linux-gnu/dri/
    fi
done

# Mesa EGL platform
for lib in libEGL_mesa.so.0 libglapi.so.0 libLLVM*.so*; do
    src=$(find /usr/lib/x86_64-linux-gnu -maxdepth 1 -name "$lib" -type f 2>/dev/null | head -1)
    if [ -n "$src" ]; then
        cp "$src" lib/x86_64-linux-gnu/
    fi
done

# Additional deps Mesa might need
for lib in libstdc++.so.6 libgcc_s.so.1 libz.so.1 libzstd.so.1 libelf.so.1; do
    src=$(find /usr/lib/x86_64-linux-gnu /lib/x86_64-linux-gnu -maxdepth 1 -name "$lib" -type f 2>/dev/null | head -1)
    if [ -n "$src" ] && [ ! -f "lib/x86_64-linux-gnu/$lib" ]; then
        cp "$src" lib/x86_64-linux-gnu/
    fi
done

echo "DRI drivers:"
ls -lh usr/lib/x86_64-linux-gnu/dri/ 2>/dev/null
ls -lh usr/lib/x86_64-linux-gnu/gbm/ 2>/dev/null
echo "Libs:"
ls -lh lib/x86_64-linux-gnu/ | wc -l
echo "files in lib/"

# Update ld.so.conf
cat > etc/ld.so.conf <<'EOF'
/lib/x86_64-linux-gnu
/usr/lib/x86_64-linux-gnu
/usr/lib/x86_64-linux-gnu/dri
EOF
ldconfig -r . 2>/dev/null || true

echo ""
echo "=== Rebuild initramfs ==="
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-mesa.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-mesa.img | awk '{print $5}')"

echo ""
echo "=== Build ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-mesa.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-viewer-mesa.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-mesa.iso | awk '{print $5}')"

echo ""
echo "=== Boot ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-mesa.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-mesa-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 25
printf 'screendump /tmp/mesa.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-mesa-mon
sleep 2
if [ -f /tmp/mesa.ppm ]; then
    convert /tmp/mesa.ppm /tmp/mesa.jpg
    cp /tmp/mesa.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/mesa.jpg"
    echo "Screenshot: $(ls -lh /tmp/mesa.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
