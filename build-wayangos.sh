#!/bin/bash
set -e

echo "=== WayangOS Build Script ==="
echo "Started at: $(date)"

# Step 1: Install dependencies
echo ""
echo ">>> Step 1: Installing build dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq build-essential flex bison bc libelf-dev libssl-dev wget xz-utils cpio gzip bzip2 2>&1 | tail -5
echo "Dependencies installed."

# Step 2: Setup build directory
echo ""
echo ">>> Step 2: Setting up build directory..."
mkdir -p ~/wayangos-build
cd ~/wayangos-build

# Step 3: Download and extract kernel
echo ""
echo ">>> Step 3: Downloading kernel..."
if [ -d "linux-6.12.6" ]; then
    echo "Kernel source already exists, skipping download."
elif [ -f "linux-6.12.6.tar.xz" ]; then
    echo "Tarball exists, extracting..."
    tar xf linux-6.12.6.tar.xz
else
    # Use 6.12.6 (stable LTS) instead of 6.19.6 which doesn't exist yet
    echo "Downloading linux-6.12.6..."
    wget -q --show-progress https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.6.tar.xz
    echo "Extracting..."
    tar xf linux-6.12.6.tar.xz
fi

# Step 4: Configure kernel
echo ""
echo ">>> Step 4: Configuring kernel..."
cd ~/wayangos-build/linux-6.12.6
make allnoconfig 2>&1 | tail -3

cat >> .config << 'EOF'
CONFIG_64BIT=y
CONFIG_SMP=y
CONFIG_PRINTK=y
CONFIG_TTY=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
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
CONFIG_INOTIFY_USER=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EVENTFD=y
CONFIG_EPOLL=y
CONFIG_ATA=y
CONFIG_ATA_PIIX=y
CONFIG_BLK_DEV_SD=y
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_SCSI=y
CONFIG_BLK_DEV_LOOP=y
CONFIG_INPUT=y
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_UNIX=y
CONFIG_PACKET=y
CONFIG_CC_OPTIMIZE_FOR_SIZE=y
EOF

make olddefconfig 2>&1 | tail -5
echo "Kernel configured."

# Step 5: Build kernel
echo ""
echo ">>> Step 5: Building kernel (this takes a while)..."
NPROC=$(nproc)
echo "Using $NPROC cores..."
make -j$NPROC 2>&1 | tail -20
echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "Kernel built successfully!"
    ls -lh arch/x86/boot/bzImage
else
    echo "ERROR: Kernel build failed - bzImage not found"
    exit 1
fi

# Step 6: Download and build BusyBox
echo ""
echo ">>> Step 6: Building BusyBox..."
cd ~/wayangos-build
if [ ! -d "busybox-1.37.0" ]; then
    if [ ! -f "busybox-1.37.0.tar.bz2" ]; then
        echo "Downloading BusyBox..."
        wget -q --show-progress https://busybox.net/downloads/busybox-1.37.0.tar.bz2
    fi
    echo "Extracting BusyBox..."
    tar xf busybox-1.37.0.tar.bz2
fi

cd busybox-1.37.0
make defconfig 2>&1 | tail -3
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
echo "Building BusyBox statically..."
make -j$NPROC 2>&1 | tail -10
make install 2>&1 | tail -5
echo "BusyBox built."

# Step 7: Create initramfs
echo ""
echo ">>> Step 7: Creating initramfs/rootfs..."
cd ~/wayangos-build
rm -rf rootfs
mkdir -p rootfs/{bin,sbin,etc,proc,sys,dev,tmp,var,root,usr/bin,usr/sbin}
cp -a busybox-1.37.0/_install/* rootfs/

# Create init script
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

# Create /etc files
echo "root:x:0:0:root:/root:/bin/sh" > rootfs/etc/passwd
echo "root:x:0:" > rootfs/etc/group
echo "wayangos" > rootfs/etc/hostname

# Pack initramfs
cd rootfs
find . | cpio -o -H newc 2>/dev/null | gzip > ../wayangos-initramfs-x86_64.img
cd ..
echo "Initramfs created."
ls -lh wayangos-initramfs-x86_64.img

# Step 8: Package everything
echo ""
echo ">>> Step 8: Packaging..."
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

cat > wayangos-0.1-x86_64/README.md << 'EOF'
# WayangOS v0.1 (x86_64)

Minimal Linux distribution built with:
- Linux kernel 6.12.6
- BusyBox 1.37.0 (static)

## Boot with QEMU
```bash
./run-qemu.sh
```

## Manual boot
```bash
qemu-system-x86_64 -kernel vmlinuz -initrd initramfs.img -append "console=ttyS0" -nographic -m 128M
```
EOF

tar czf wayangos-0.1-x86_64.tar.gz wayangos-0.1-x86_64/
echo ""
echo "Package created:"
ls -lh wayangos-0.1-x86_64.tar.gz

# Step 9: Copy to Windows
echo ""
echo ">>> Step 9: Copying to Windows..."
WINDIR="/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro"
mkdir -p "$WINDIR"
cp wayangos-0.1-x86_64.tar.gz "$WINDIR/"
cp wayangos-0.1-x86_64/vmlinuz "$WINDIR/"
cp wayangos-initramfs-x86_64.img "$WINDIR/"
cp wayangos-0.1-x86_64/run-qemu.sh "$WINDIR/"
cp wayangos-0.1-x86_64/README.md "$WINDIR/"

echo ""
echo "=== Build Complete ==="
echo "Files copied to Windows:"
ls -lh "$WINDIR/vmlinuz" "$WINDIR/wayangos-initramfs-x86_64.img" "$WINDIR/wayangos-0.1-x86_64.tar.gz"
echo ""
echo "Finished at: $(date)"
