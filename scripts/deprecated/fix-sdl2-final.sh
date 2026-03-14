#!/bin/bash
set -e

echo "=== Installing libdrm-dev for SDL2 KMSDRM support ==="
sudo apt-get install -y libdrm-dev 2>&1 | tail -3

echo ""
echo "=== Checking libdrm headers ==="
ls /usr/include/libdrm/ | head -5
ls /usr/include/xf86drm.h 2>/dev/null && echo "xf86drm.h found" || echo "xf86drm.h missing"

echo ""
echo "=== Reconfiguring SDL2 ==="
cd ~/wayangos-build/SDL2-2.30.10
make distclean 2>/dev/null || true

# Set CFLAGS to find libdrm headers
CFLAGS="-I/usr/include/libdrm" \
LDFLAGS="-L/usr/lib/x86_64-linux-gnu" \
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
    2>&1 | tee /tmp/sdl2-cfg2.log | grep -iE "kmsdrm|fbdev|Video driver|Summary" | head -10

echo ""
echo "=== Config Summary ==="
grep -A5 "Video drivers" /tmp/sdl2-cfg2.log

echo ""
echo "=== Building SDL2 ==="
make -j$(nproc) 2>&1 | tail -3
make install 2>&1 | tail -3

echo ""
echo "=== Verify KMSDRM in SDL2 ==="
strings ~/wayangos-build/sdl2-install/lib/libSDL2.a | grep -i "KMSDRM\|kmsdrm" | sort -u | head -5

echo ""
echo "=== Rebuilding viewer ==="
cd ~/wayangos-build/wayangos-viewer
gcc -static -O2 \
    -I ~/wayangos-build/sdl2-install/include/SDL2 \
    -o viewer viewer.c \
    -L ~/wayangos-build/sdl2-install/lib \
    $(~/wayangos-build/sdl2-install/bin/sdl2-config --static-libs) \
    -ldrm -lm 2>&1
ls -lh viewer
file viewer

echo ""
echo "=== Updating initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-v5.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-v5.img | awk '{print $5}')"

echo ""
echo "=== Building ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-v5.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-viewer-kmsdrm.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-kmsdrm.iso | awk '{print $5}')"

echo ""
echo "=== Booting QEMU ==="
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-kmsdrm.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-kmsdrm-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 20
printf 'screendump /tmp/kmsdrm.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-kmsdrm-mon
sleep 2
if [ -f /tmp/kmsdrm.ppm ]; then
    convert /tmp/kmsdrm.ppm /tmp/kmsdrm.jpg
    cp /tmp/kmsdrm.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/kmsdrm.jpg"
    echo "Screenshot: $(ls -lh /tmp/kmsdrm.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
