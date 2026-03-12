#!/bin/bash
set -e
cd ~/wayangos-build

# Install cross-compilers
sudo apt-get install -y gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu 2>/dev/null

### ARM64 ###
echo "=== Building ARM64 kernel ==="
cd ~/wayangos-build/linux-6.12.6
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
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image

echo "ARM64 kernel built!"
ls -lh arch/arm64/boot/Image

# Build ARM64 BusyBox
echo "=== Building ARM64 BusyBox ==="
cd ~/wayangos-build
if [ ! -d "busybox-arm64" ]; then
  cp -r busybox-1.37.0 busybox-arm64
fi
cd busybox-arm64
make distclean
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install

# Create ARM64 rootfs
cd ~/wayangos-build
rm -rf rootfs-arm64
mkdir -p rootfs-arm64/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/bin,usr/sbin}
cp -a busybox-arm64/_install/* rootfs-arm64/

cat > rootfs-arm64/init << 'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp
echo "============================================"
echo "   WayangOS v0.1 (ARM64)"
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

# Package ARM64
mkdir -p wayangos-0.1-arm64
cp linux-6.12.6/arch/arm64/boot/Image wayangos-0.1-arm64/
cp wayangos-initramfs-arm64.img wayangos-0.1-arm64/initramfs.img
cat > wayangos-0.1-arm64/run-qemu.sh << 'QEOF'
#!/bin/bash
qemu-system-aarch64 -machine virt -cpu cortex-a57 -kernel Image -initrd initramfs.img -append "console=ttyAMA0" -nographic -m 128M
QEOF
chmod +x wayangos-0.1-arm64/run-qemu.sh
tar czf wayangos-0.1-arm64.tar.gz wayangos-0.1-arm64/
echo "ARM64 package:"
ls -lh wayangos-0.1-arm64.tar.gz

### RISC-V ###
echo "=== Building RISC-V kernel ==="
cd ~/wayangos-build/linux-6.12.6
make mrproper
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- allnoconfig

cat >> .config << 'EOF'
CONFIG_64BIT=y
CONFIG_SMP=y
CONFIG_PRINTK=y
CONFIG_TTY=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_EARLYCON=y
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
CONFIG_SOC_VIRT=y
EOF
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- olddefconfig
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc) Image

echo "RISC-V kernel built!"
ls -lh arch/riscv/boot/Image

# Build RISC-V BusyBox
echo "=== Building RISC-V BusyBox ==="
cd ~/wayangos-build
if [ ! -d "busybox-riscv" ]; then
  cp -r busybox-1.37.0 busybox-riscv
fi
cd busybox-riscv
make distclean
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc)
make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- install

cd ~/wayangos-build
rm -rf rootfs-riscv
mkdir -p rootfs-riscv/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/bin,usr/sbin}
cp -a busybox-riscv/_install/* rootfs-riscv/

cat > rootfs-riscv/init << 'INITEOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t tmpfs tmp /tmp
echo "============================================"
echo "   WayangOS v0.1 (RISC-V)"
echo "   The Shadow that Powers the Machine"
echo "============================================"
hostname wayangos
exec /bin/sh
INITEOF
chmod +x rootfs-riscv/init
echo "root:x:0:0:root:/root:/bin/sh" > rootfs-riscv/etc/passwd
echo "root:x:0:" > rootfs-riscv/etc/group

cd rootfs-riscv
find . | cpio -o -H newc 2>/dev/null | gzip > ../wayangos-initramfs-riscv64.img
cd ..

mkdir -p wayangos-0.1-riscv64
cp linux-6.12.6/arch/riscv/boot/Image wayangos-0.1-riscv64/
cp wayangos-initramfs-riscv64.img wayangos-0.1-riscv64/initramfs.img
cat > wayangos-0.1-riscv64/run-qemu.sh << 'QEOF'
#!/bin/bash
qemu-system-riscv64 -machine virt -kernel Image -initrd initramfs.img -append "console=ttyS0" -nographic -m 128M
QEOF
chmod +x wayangos-0.1-riscv64/run-qemu.sh
tar czf wayangos-0.1-riscv64.tar.gz wayangos-0.1-riscv64/
echo "RISC-V package:"
ls -lh wayangos-0.1-riscv64.tar.gz

# Copy all to Windows
cp wayangos-0.1-arm64.tar.gz "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/"
cp wayangos-0.1-riscv64.tar.gz "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/"

echo "=== ALL BUILDS COMPLETE ==="
