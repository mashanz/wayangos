#!/bin/bash
set -e
cd ~/wayangos-build/SDL2-2.30.10

echo "=== Step 1: Rebuild SDL2 with kmsdrm + fbdev ==="
make distclean 2>/dev/null || true

# Use regular gcc, link statically later
./configure \
    --prefix="$HOME/wayangos-build/sdl2-install" \
    --enable-static \
    --disable-shared \
    --disable-audio \
    --disable-joystick \
    --disable-haptic \
    --disable-sensor \
    --disable-power \
    --enable-video \
    --enable-video-kmsdrm \
    --disable-video-x11 \
    --disable-video-wayland \
    --disable-video-opengl \
    --disable-video-opengles \
    --disable-video-opengles2 \
    --disable-video-vulkan \
    --disable-video-rpi \
    --enable-render \
    --enable-events \
    2>&1 | tee /tmp/sdl2-cfg.log | grep -iE "kmsdrm|fbdev|video driver|Summary" | head -10

echo ""
echo "=== SDL2 Configure Summary ==="
grep -A30 "SDL2 Configure Summary" /tmp/sdl2-cfg.log | head -35

make -j$(nproc) 2>&1 | tail -3
make install 2>&1 | tail -3

echo ""
echo "=== Verify SDL2 backends ==="
strings ~/wayangos-build/sdl2-install/lib/libSDL2.a | grep -i "KMSDRM\|FBCON\|fbdev\|video driver" | sort -u | head -10

echo ""
echo "=== Step 2: Rebuild viewer ==="
cd ~/wayangos-build/wayangos-viewer

# Static link with all deps
gcc -static -O2 \
    -I ~/wayangos-build/sdl2-install/include/SDL2 \
    -o viewer viewer.c \
    -L ~/wayangos-build/sdl2-install/lib \
    $(~/wayangos-build/sdl2-install/bin/sdl2-config --static-libs) \
    -lm 2>&1

ls -lh viewer
file viewer

echo ""
echo "=== Step 3: Update initramfs ==="
cd ~/wayangos-build
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

# Replace viewer binary
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer

# Rebuild
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-v4.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-v4.img | awk '{print $5}')"

echo ""
echo "=== Step 4: Build ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v4.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-viewer-final.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-final.iso | awk '{print $5}')"

echo ""
echo "=== Step 5: Boot & test ==="
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-final.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-final-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 20

printf 'screendump /tmp/final.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-final-mon
sleep 2
if [ -f /tmp/final.ppm ]; then
    convert /tmp/final.ppm /tmp/final.jpg
    cp /tmp/final.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/final.jpg"
    echo "Screenshot: $(ls -lh /tmp/final.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
