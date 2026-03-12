#!/bin/bash
set -e

cd ~/wayangos-build/busybox-1.37.0

echo ">>> Fixing BusyBox config (disabling tc)..."
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config

echo ">>> Rebuilding BusyBox..."
make -j$(nproc) 2>&1 | tail -10
make install 2>&1 | tail -5
echo "BusyBox built successfully."
ls -lh busybox

# Create initramfs
echo ""
echo ">>> Creating initramfs..."
cd ~/wayangos-build
rm -rf rootfs
mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,tmp,var,root,usr/bin,usr/sbin}
cp -a busybox-1.37.0/_install/* rootfs/

cat > rootfs/init << 'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp

echo ""
echo "============================================"
echo "   WayangOS v0.1 (x86_64)"
echo "   The Shadow that Powers the Machine"
echo "============================================"
echo ""
hostname wayangos
echo "wayangos" > /proc/sys/kernel/hostname

echo "Type 'poweroff -f' to shut down."
echo ""
exec /bin/sh
INITEOF
chmod +x rootfs/init

echo "root:x:0:0:root:/root:/bin/sh" > rootfs/etc/passwd
echo "root:x:0:" > rootfs/etc/group
echo "wayangos" > rootfs/etc/hostname

cd rootfs
find . | cpio -o -H newc 2>/dev/null | gzip > ../wayangos-initramfs-x86_64.img
cd ..
echo "Initramfs created:"
ls -lh wayangos-initramfs-x86_64.img

# Package
echo ""
echo ">>> Packaging..."
rm -rf wayangos-0.1-x86_64
mkdir -p wayangos-0.1-x86_64
cp linux-6.12.6/arch/x86/boot/bzImage wayangos-0.1-x86_64/vmlinuz
cp wayangos-initramfs-x86_64.img wayangos-0.1-x86_64/initramfs.img

cat > wayangos-0.1-x86_64/run-qemu.sh << 'EOF'
#!/bin/bash
qemu-system-x86_64 \
  -kernel vmlinuz \
  -initrd initramfs.img \
  -append "console=ttyS0" \
  -nographic \
  -m 128M
EOF
chmod +x wayangos-0.1-x86_64/run-qemu.sh

cat > wayangos-0.1-x86_64/README.md << 'READMEEOF'
# WayangOS v0.1 (x86_64)

Minimal Linux distribution.

## Components
- Linux kernel 6.12.6 (minimal config)
- BusyBox 1.37.0 (static)
- initramfs rootfs

## Boot with QEMU
```bash
./run-qemu.sh
```

## Manual boot
```bash
qemu-system-x86_64 -kernel vmlinuz -initrd initramfs.img -append "console=ttyS0" -nographic -m 128M
```

## Boot on real hardware
Use a bootloader (GRUB/syslinux) pointing to vmlinuz with initramfs.img as initrd.
READMEEOF

tar czf wayangos-0.1-x86_64.tar.gz wayangos-0.1-x86_64/

echo ""
echo "=== Package contents ==="
ls -lh wayangos-0.1-x86_64/
echo ""
echo "=== Archive ==="
ls -lh wayangos-0.1-x86_64.tar.gz

# Copy to Windows
echo ""
echo ">>> Copying to Windows..."
WINDIR="/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro"
mkdir -p "$WINDIR"
cp wayangos-0.1-x86_64.tar.gz "$WINDIR/"
cp wayangos-0.1-x86_64/vmlinuz "$WINDIR/"
cp wayangos-initramfs-x86_64.img "$WINDIR/"
cp wayangos-0.1-x86_64/run-qemu.sh "$WINDIR/"
cp wayangos-0.1-x86_64/README.md "$WINDIR/"

echo ""
echo "=== FILES ON WINDOWS ==="
ls -lh "$WINDIR/vmlinuz" "$WINDIR/wayangos-initramfs-x86_64.img" "$WINDIR/wayangos-0.1-x86_64.tar.gz"
echo ""
echo "=== BUILD COMPLETE ==="
