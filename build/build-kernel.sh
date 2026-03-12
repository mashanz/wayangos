#!/bin/bash
#
# WayangOS Kernel Build Script
# Usage: ./build-kernel.sh [ARCH] [CONFIG_PROFILE]
#
# Examples:
#   ./build-kernel.sh x86_64 minimal
#   ./build-kernel.sh arm64 server
#   ./build-kernel.sh riscv rt
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
KERNEL_DIR="${PROJECT_ROOT}/kernel"
CONFIGS_DIR="${PROJECT_ROOT}/configs"
OUTPUT_DIR="${PROJECT_ROOT}/build/output"

ARCH="${1:-x86_64}"
CONFIG="${2:-minimal}"
JOBS="${3:-$(nproc)}"

# Map architecture names to kernel ARCH values
case "$ARCH" in
    x86_64|amd64)
        KERNEL_ARCH="x86_64"
        CROSS_COMPILE=""
        ;;
    arm64|aarch64)
        KERNEL_ARCH="arm64"
        CROSS_COMPILE="aarch64-linux-gnu-"
        ;;
    riscv|riscv64)
        KERNEL_ARCH="riscv"
        CROSS_COMPILE="riscv64-linux-gnu-"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        echo "Supported: x86_64, arm64, riscv"
        exit 1
        ;;
esac

CONFIG_FILE="${CONFIGS_DIR}/${CONFIG}.config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config not found: $CONFIG_FILE"
    echo "Available configs:"
    ls -1 "${CONFIGS_DIR}"/*.config 2>/dev/null | xargs -I{} basename {} .config
    exit 1
fi

echo "============================================"
echo "  WayangOS Kernel Build"
echo "============================================"
echo "  Architecture : $ARCH ($KERNEL_ARCH)"
echo "  Config       : $CONFIG"
echo "  Jobs         : $JOBS"
echo "  Cross-compile: ${CROSS_COMPILE:-native}"
echo "============================================"
echo ""

cd "$KERNEL_DIR"

# Clean previous build
echo "[1/4] Cleaning kernel tree..."
make ARCH="$KERNEL_ARCH" mrproper

# Apply config
echo "[2/4] Applying config: ${CONFIG}.config..."
cp "$CONFIG_FILE" .config
make ARCH="$KERNEL_ARCH" CROSS_COMPILE="$CROSS_COMPILE" olddefconfig

# Build
echo "[3/4] Building kernel (${JOBS} jobs)..."
make ARCH="$KERNEL_ARCH" CROSS_COMPILE="$CROSS_COMPILE" -j"$JOBS"

# Copy output
echo "[4/4] Copying build artifacts..."
mkdir -p "$OUTPUT_DIR/${ARCH}-${CONFIG}"

case "$KERNEL_ARCH" in
    x86_64)
        cp arch/x86/boot/bzImage "$OUTPUT_DIR/${ARCH}-${CONFIG}/"
        ;;
    arm64)
        cp arch/arm64/boot/Image "$OUTPUT_DIR/${ARCH}-${CONFIG}/"
        ;;
    riscv)
        cp arch/riscv/boot/Image "$OUTPUT_DIR/${ARCH}-${CONFIG}/"
        ;;
esac

cp .config "$OUTPUT_DIR/${ARCH}-${CONFIG}/kernel.config"
cp System.map "$OUTPUT_DIR/${ARCH}-${CONFIG}/" 2>/dev/null || true

echo ""
echo "============================================"
echo "  Build complete!"
echo "  Output: $OUTPUT_DIR/${ARCH}-${CONFIG}/"
echo "============================================"
