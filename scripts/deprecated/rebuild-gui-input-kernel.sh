#!/bin/bash
set -e
BUILD=~/wayangos-build

# Find the RT kernel source
KDIR=""
for d in $BUILD/linux-6.19.3-rt1 $BUILD/linux-6.19.3 $BUILD/linux-6.12.6; do
    if [ -d "$d" ]; then KDIR="$d"; break; fi
done

if [ -z "$KDIR" ]; then
    echo "ERROR: No kernel source found"
    ls $BUILD/linux-* 2>/dev/null | head
    exit 1
fi

echo "=== Rebuilding kernel with input support ==="
echo "Source: $KDIR"
cd $KDIR

# Backup config
cp .config .config.bak.$(date +%s) 2>/dev/null || true

# Apply the saved GUI config base
cp $BUILD/kernel-gui.config .config

# Resolve all config options (fills in missing ones with defaults)
make olddefconfig 2>&1 | grep -v "^#" | tail -20

echo ""
echo "=== Config check ==="
grep "CONFIG_INPUT_EVDEV" .config
grep "CONFIG_KEYBOARD_ATKBD" .config
grep "CONFIG_VIRTIO_INPUT" .config
grep "CONFIG_USB_HID" .config

echo ""
echo "=== Building kernel (this takes ~10min) ==="
make -j$(nproc) bzImage 2>&1 | tail -20

cp arch/x86/boot/bzImage $BUILD/vmlinuz-gui-with-input
echo ""
echo "=== Done ==="
ls -lh $BUILD/vmlinuz-gui-with-input
