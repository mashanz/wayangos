#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Preparing viewer demo ==="

# Create a working copy of the GUI rootfs
WORK=$(mktemp -d)
cd $WORK

# Unpack existing GUI initramfs
zcat ~/wayangos-build/iso-staging-gui/boot/initramfs.img | cpio -idm 2>/dev/null
echo "Unpacked rootfs"

# Add the viewer binary
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer
echo "Added viewer binary"

# Create a test image (PPM format - stb_image doesn't support it, need BMP/PNG)
# Let's generate a BMP test image using the screenshot we already have
cp ~/wayangos-build/wayangos-viewer/screenshot.png root/test.png 2>/dev/null || true

# Also create a simple BMP test pattern with dd (raw pixel data)
# Actually let's use the POS demo screenshot
if [ -f ~/wayangos-build/wayangos-viewer/screenshot.bmp ]; then
    cp ~/wayangos-build/wayangos-viewer/screenshot.bmp root/test.bmp
    echo "Added test.bmp"
fi

# Create a startup script that runs viewer after boot
cat > etc/init.d/viewer-demo <<'EOF'
#!/bin/sh
# Wait for framebuffer
sleep 2
if [ -f /root/test.bmp ]; then
    SDL_VIDEODRIVER=fbdev SDL_FBDEV=/dev/fb0 /usr/bin/viewer /root/test.bmp &
elif [ -f /root/test.png ]; then
    SDL_VIDEODRIVER=fbdev SDL_FBDEV=/dev/fb0 /usr/bin/viewer /root/test.png &
fi
EOF
chmod +x etc/init.d/viewer-demo

# Add viewer-demo to rcS if not already there
if ! grep -q viewer-demo etc/init.d/rcS 2>/dev/null; then
    echo '/etc/init.d/viewer-demo' >> etc/init.d/rcS
fi

# Repack initramfs
find . | cpio -o -H newc 2>/dev/null | gzip > ~/wayangos-build/initramfs-viewer-demo.img
echo "Repacked initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-demo.img | awk '{print $5}')"

# Cleanup
cd ~/wayangos-build
rm -rf $WORK

echo "=== Ready to boot ==="
echo "Run: qemu-system-x86_64 -kernel vmlinuz-rt-gui -initrd initramfs-viewer-demo.img -m 128M -vga std -vnc :1"
