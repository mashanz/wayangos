#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true

echo "=== Extracting initramfs ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

echo "=== Copying viewer binary ==="
cp ~/wayangos-build/wayangos-viewer/viewer usr/bin/viewer
chmod +x usr/bin/viewer
file usr/bin/viewer

echo "=== Copying required shared libs ==="
mkdir -p lib/x86_64-linux-gnu lib64

# Copy glibc runtime
cp /lib64/ld-linux-x86-64.so.2 lib64/
cp /lib/x86_64-linux-gnu/libc.so.6 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/libm.so.6 lib/x86_64-linux-gnu/
cp /lib/x86_64-linux-gnu/libdl.so.2 lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /lib/x86_64-linux-gnu/libpthread.so.0 lib/x86_64-linux-gnu/ 2>/dev/null || true

# SDL2 dynamically loads these via dlopen
cp /usr/lib/x86_64-linux-gnu/libdrm.so.2* lib/x86_64-linux-gnu/
cp /usr/lib/x86_64-linux-gnu/libgbm.so.1* lib/x86_64-linux-gnu/
cp /usr/lib/x86_64-linux-gnu/libEGL.so.1* lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libGLESv2.so.2* lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libGLdispatch.so.0* lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libwayland-server.so.0* lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libexpat.so.1* lib/x86_64-linux-gnu/ 2>/dev/null || true
cp /usr/lib/x86_64-linux-gnu/libffi.so.8* lib/x86_64-linux-gnu/ 2>/dev/null || true

echo "Shared libs:"
ls -lh lib/x86_64-linux-gnu/ lib64/

# Create ld.so.conf for dynamic linker
echo "/lib/x86_64-linux-gnu" > etc/ld.so.conf
ldconfig -r . 2>/dev/null || true

# Symlinks for compat
ln -sf lib/x86_64-linux-gnu/libm.so.6 lib/libm.so.6 2>/dev/null || true

echo ""
echo "=== Test viewer can find its libs ==="
LD_LIBRARY_PATH="$WORK/lib/x86_64-linux-gnu:$WORK/lib64" ldd usr/bin/viewer 2>&1 | head -10

echo ""
echo "=== Rebuild initramfs ==="
find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-viewer-final2.img
echo "Initramfs: $(ls -lh ~/wayangos-build/initramfs-viewer-final2.img | awk '{print $5}')"

echo ""
echo "=== Build ISO ==="
cd ~/wayangos-build
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp initramfs-viewer-final2.img "$ISO_DIR/boot/initramfs.img"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS Viewer" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-viewer-real.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR" "$WORK"
echo "ISO: $(ls -lh wayangos-viewer-real.iso | awk '{print $5}')"

echo ""
echo "=== Boot QEMU ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-viewer-real.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-real-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &
sleep 25
printf 'screendump /tmp/real.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-real-mon
sleep 2
if [ -f /tmp/real.ppm ]; then
    convert /tmp/real.ppm /tmp/real.jpg
    cp /tmp/real.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/real.jpg"
    echo "Screenshot: $(ls -lh /tmp/real.jpg | awk '{print $5}')"
fi
echo "=== ALL DONE ==="
