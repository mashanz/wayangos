#!/bin/bash
# Build a WayangOS kernel from a named config
# Usage: ./scripts/build-kernel.sh <config-name> [output-name]
# Example: ./scripts/build-kernel.sh defconfig-qemu bzImage-qemu
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BUILD_DIR:-$HOME/wayangos-build}"
KDIR="$BUILD/linux-6.19.7"

CONFIG_NAME="${1:?Usage: $0 <config-name> [output-name]}"
OUTPUT_NAME="${2:-bzImage-$CONFIG_NAME}"
CONFIG_FILE="$REPO_DIR/configs/$CONFIG_NAME"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config not found: $CONFIG_FILE"
    echo "Available configs:"
    ls "$REPO_DIR/configs/"
    exit 1
fi

if [ ! -d "$KDIR" ]; then
    echo "ERROR: Kernel source not found at $KDIR"
    echo "Download and extract Linux 6.19.7 to $KDIR first."
    exit 1
fi

echo "=== Building WayangOS Kernel ==="
echo "  Config: $CONFIG_NAME"
echo "  Output: $OUTPUT_NAME"
echo "  Source: $KDIR"

cd "$KDIR"

# Backup current .config if it exists
if [ -f .config ]; then
    cp .config .config.bak
    echo "  Backed up existing .config → .config.bak"
fi

# Install the config
cp "$CONFIG_FILE" .config
make olddefconfig 2>&1 | tail -3

echo "Building kernel ($(nproc) jobs)..."
make -j$(nproc) bzImage 2>&1 | tail -10

# Copy output
cp arch/x86/boot/bzImage "$BUILD/$OUTPUT_NAME"
echo ""
echo "=== Kernel Built ==="
echo "  Output: $BUILD/$OUTPUT_NAME"
echo "  Size: $(du -h "$BUILD/$OUTPUT_NAME" | cut -f1)"
