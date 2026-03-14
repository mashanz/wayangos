#!/bin/bash
set -e
cd ~/wayangos-build/SDL2-2.30.10

echo "=== Building SDL2 ==="
make -j$(nproc) 2>&1 | tail -3
make install 2>&1 | tail -3

echo ""
echo "=== Building viewer ==="
cd ~/wayangos-build/wayangos-viewer

# Build with all needed libs
gcc -static -O2 \
    -I ~/wayangos-build/sdl2-install/include/SDL2 \
    -o viewer viewer.c \
    -L ~/wayangos-build/sdl2-install/lib \
    -Wl,--start-group \
    -lSDL2 -ldrm -lgbm -lEGL -lGLESv2 -lm -lpthread -ldl \
    -Wl,--end-group \
    2>&1 || {
    echo "Static link failed, trying dynamic..."
    gcc -O2 \
        -I ~/wayangos-build/sdl2-install/include/SDL2 \
        -o viewer viewer.c \
        -L ~/wayangos-build/sdl2-install/lib \
        $(~/wayangos-build/sdl2-install/bin/sdl2-config --static-libs) \
        -ldrm -lgbm -lm 2>&1
}

ls -lh viewer
file viewer
ldd viewer 2>/dev/null | head -10 || echo "(static binary)"

echo ""
echo "=== Update initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

# Copy viewer
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer

# If dynamic, copy needed shared libs
if ldd ~/wayangos-build/wayangos-viewer/viewer 2>/dev/null | grep -q "libdrm"; then
    echo "Copying shared libraries..."
    mkdir -p lib/x86_64-linux-gnu lib64
    for lib in libdrm.so.2 libgbm.so.1 libEGL.so.1 libGLESv2.so.2 libGLdispatch.so.0 libwayland-server.so.0 libexpat.so.1; do
        src=$(find /usr/lib/x86_64-linux-gnu -name "$lib*" -type f 2>/dev/null | head -1)
        if [ -n "$src" ]; then
            cp "$src" lib/x86_64-linux-gnu/
            ln -sf "$(basename $src)" "lib/x86_64-linux-gnu/$lib" 2>/dev/null || true
        fi
    done
    # Also copy ld-linux
    cp /lib64/ld-linux-x86-64.so.2 lib64/ 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libc.so.6 lib/x86_64-linux-gnu/ 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libdl.so.2 lib/x86_64-linux-gnu/ 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libpthread.so.0 lib/x86_64-linux-gnu/ 2>/dev/null || true
    cp /lib/x86_64-linux-gnu/libm.so.6 lib/x86_64-linux-gnu/ 2>/dev/null || true
    echo "Shared libs copied:"
    ls -lh lib/x86_64-linux-gnu/
fi

# Rebuild initramfs
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-final.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-final.img | awk '{print $5}')"

echo ""
echo "=== Building ISO ==="
cd ~/wayangos-build
killall -9 qemu-system-x86_64 2>/dev/null || true
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-final.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-viewer-kmsdrm-final.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-kmsdrm-final.iso | awk '{print $5}')"

echo ""
echo "=== Booting QEMU ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-kmsdrm-final.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-kmsdrm2-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/kmsdrm2.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-kmsdrm2-mon
sleep 2
if [ -f /tmp/kmsdrm2.ppm ]; then
    convert /tmp/kmsdrm2.ppm /tmp/kmsdrm2.jpg
    cp /tmp/kmsdrm2.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/kmsdrm2.jpg"
    echo "Screenshot: $(ls -lh /tmp/kmsdrm2.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
