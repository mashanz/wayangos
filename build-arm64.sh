#!/bin/bash
set -e
echo "=== Building WayangOS ARM64 ==="

cd /home/desktop_pc/wayangos-build/linux-6.12.6
make mrproper

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- allnoconfig

cat >> .config << 'EOF'
CONFIG_64BIT=y
CONFIG_SMP=y
CONFIG_PRINTK=y
CONFIG_TTY=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_EXT4_FS=y
CONFIG_BLOCK=y
CONFIG_BLK_DEV=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_NET=y
CONFIG_INET=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_TMPFS=y
CONFIG_FUTEX=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_UNIX=y
CONFIG_PACKET=y
CONFIG_CC_OPTIMIZE_FOR_SIZE=y
CONFIG_OF=y
CONFIG_ARM_AMBA=y
EOF

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
echo "Compiling kernel..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) 2>&1 | tail -5

cd /home/desktop_pc/wayangos-build
mkdir -p wayangos-0.1-arm64
cp linux-6.12.6/arch/arm64/boot/Image wayangos-0.1-arm64/Image

# Build ARM64 BusyBox
cd /home/desktop_pc/wayangos-build/busybox-1.37.0
make distclean
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# Disable tc to avoid build errors
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) 2>&1 | tail -3
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install 2>&1 | tail -3

# Create ARM64 rootfs
cd /home/desktop_pc/wayangos-build
rm -rf rootfs-arm64
mkdir -p rootfs-arm64/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/bin,usr/sbin}
cp -a busybox-1.37.0/_install/* rootfs-arm64/

cat > rootfs-arm64/init << 'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp
echo "============================================"
echo "   WayangOS v0.1 (arm64)"
echo "   The Shadow that Powers the Machine"
echo "============================================"
hostname wayangos
exec /bin/sh
INITEOF
chmod +x rootfs-arm64/init
echo "root:x:0:0:root:/root:/bin/sh" > rootfs-arm64/etc/passwd
echo "root:x:0:" > rootfs-arm64/etc/group

cd rootfs-arm64
find . | cpio -o -H newc 2>/dev/null | gzip > ../wayangos-initramfs-arm64.img
cd ..

cp wayangos-initramfs-arm64.img wayangos-0.1-arm64/initramfs.img
cat > wayangos-0.1-arm64/run-qemu.sh << 'QEOF'
#!/bin/bash
qemu-system-aarch64 -machine virt -cpu cortex-a57 -kernel Image -initrd initramfs.img -append "console=ttyAMA0" -nographic -m 128M
QEOF
chmod +x wayangos-0.1-arm64/run-qemu.sh

tar czf wayangos-0.1-arm64.tar.gz wayangos-0.1-arm64/
ls -lh wayangos-0.1-arm64.tar.gz wayangos-0.1-arm64/Image wayangos-initramfs-arm64.img
cp wayangos-0.1-arm64.tar.gz "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/"
echo "=== ARM64 build complete ==="
