#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

echo "=== Current PCI config ==="
grep "^CONFIG_PCI" .config | head -20

echo ""
echo "=== Enabling PCI host bridge for QEMU (i440fx/q35) ==="
./scripts/config --enable PCI
./scripts/config --enable PCI_DIRECT
./scripts/config --enable PCI_GOANY
./scripts/config --enable PCI_MMCONFIG
./scripts/config --enable PCI_MSI
./scripts/config --enable PCI_HOST_GENERIC

# AGP for older VGA
./scripts/config --enable AGP
./scripts/config --enable AGP_INTEL

# Ensure DRM chain is complete
./scripts/config --enable DRM
./scripts/config --enable DRM_BOCHS
./scripts/config --enable DRM_SIMPLEDRM
./scripts/config --enable DRM_FBDEV_EMULATION
./scripts/config --enable DRM_GEM_SHMEM_HELPER
./scripts/config --enable FB
./scripts/config --enable FB_VESA
./scripts/config --enable FRAMEBUFFER_CONSOLE

# VGA console
./scripts/config --enable VGA_CONSOLE
./scripts/config --enable DUMMY_CONSOLE

# ACPI (QEMU provides ACPI tables for PCI)
./scripts/config --enable ACPI
./scripts/config --enable ACPI_PCI_SLOT

make olddefconfig 2>&1 | tail -3

echo ""
echo "=== Verify PCI ==="
grep "^CONFIG_PCI" .config

echo ""
echo "=== Verify DRM ==="
grep "^CONFIG_DRM_BOCHS\|^CONFIG_DRM=" .config

echo ""
echo "=== Verify ACPI ==="
grep "^CONFIG_ACPI=" .config

echo ""
echo "=== Building kernel ==="
make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-gui-pci-fixed
ls -lh ~/wayangos-build/vmlinuz-gui-pci-fixed

echo ""
echo "=== Building test ISO ==="
ISO_DIR=$(mktemp -d)
mkdir -p "$ISO_DIR/boot/grub"
cp ~/wayangos-build/vmlinuz-gui-pci-fixed "$ISO_DIR/boot/vmlinuz"
cp ~/wayangos-build/initramfs-viewer-v2.img "$ISO_DIR/boot/initramfs.img"

cat > "$ISO_DIR/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS PCI Fix Test" {
    linux /boot/vmlinuz console=tty0 drm.debug=0x02
    initrd /boot/initramfs.img
}
EOF

grub-mkrescue -o ~/wayangos-build/wayangos-pci-test.iso "$ISO_DIR" 2>/dev/null
rm -rf "$ISO_DIR"
echo "ISO: $(ls -lh ~/wayangos-build/wayangos-pci-test.iso | awk '{print $5}')"

echo ""
echo "=== Booting QEMU ==="
killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

setsid qemu-system-x86_64 \
    -cdrom ~/wayangos-build/wayangos-pci-test.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -monitor unix:/tmp/qemu-pci-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 15

echo "=== Taking screenshot ==="
printf 'screendump /tmp/pci-test.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-pci-mon
sleep 2
if [ -f /tmp/pci-test.ppm ]; then
    convert /tmp/pci-test.ppm /tmp/pci-test.jpg
    cp /tmp/pci-test.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/pci-test.jpg"
    echo "Screenshot saved!"
    ls -lh /tmp/pci-test.jpg
fi

echo "=== DONE ==="
