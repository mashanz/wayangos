#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Building init without kiosk auto-start ==="
cat > kiosk-init-clean.sh <<'INIT_EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp
hostname wayang

# Start SSH
sshd -D &

# Start shell
/bin/sh
INIT_EOF

chmod +x kiosk-init-clean.sh

# Build new initramfs
rm -f initramfs-test.img
mkdir -p initramfs-test/{bin,sbin,lib,etc,dev,proc,sys,tmp,root}
cp vmlinuz-rt-gui-v3 initramfs-test/
cp /lib/x86_64-linux-gnu/{libc.so.6,ld-linux-x86-64.so.2,libpam.so.0,libpam_misc.so.0,libresolv.so.2,libnss_files.so.2,libutil.so.1} initramfs-test/lib/ 2>/dev/null || true
cp /usr/sbin/sshd initramfs-test/sbin/ 2>/dev/null || true
cp /bin/{sh,ls,cat,echo,hostname} initramfs-test/bin/ 2>/dev/null || true
cp ./wayangos-viewer/viewer initramfs-test/bin/
cp kiosk-init-clean.sh initramfs-test/init
chmod +x initramfs-test/init

# Create test image
cat > initramfs-test/root/test.bmp <<'BMP_EOF'
BM 6         $            ff      ff            
BMP_EOF

# Create cpio image
cd initramfs-test
find . -print0 | cpio -0 -o -H newc | gzip > ../initramfs-test.img
cd ..
echo "Initramfs: $(ls -lh initramfs-test.img | awk '{print $5}')"

echo "=== Building test ISO ==="
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp vmlinuz-rt-gui-v3 "$ISO_DIR/boot/vmlinuz"
cp initramfs-test.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS FBDev Test" {
    linux /boot/vmlinuz console=tty0
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o wayangos-fbdev-test.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh wayangos-fbdev-test.iso | awk '{print $5}')"

echo "=== Booting in QEMU ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-fbdev-test.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -net user,hostfwd=tcp:127.0.0.1:2222-:22 \
    < /dev/null > /dev/null 2>&1 &

sleep 5
QEMU_PID=$!
echo "QEMU PID: $QEMU_PID"

# Wait for boot
sleep 8

echo "=== Testing viewer via SSH ==="
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@127.0.0.1 'SDL_VIDEODRIVER=fbdev /bin/viewer /root/test.bmp &' 2>/dev/null || echo "SSH command sent"

sleep 5

echo "=== Taking screenshot ==="
import -window root /tmp/qemu-live.png 2>/dev/null || echo "Screenshot capture failed"
if [ -f /tmp/qemu-live.png ]; then
    cp /tmp/qemu-live.png "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/qemu-live.png"
    echo "Live screenshot saved!"
fi

echo "=== Done ==="
