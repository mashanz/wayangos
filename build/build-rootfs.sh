#!/bin/bash
#
# [DistroName]OS Root Filesystem Build Script
# Builds a minimal rootfs with musl + BusyBox
#
# Usage: ./build-rootfs.sh [ARCH]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
USERSPACE_DIR="${PROJECT_ROOT}/userspace"
OUTPUT_DIR="${PROJECT_ROOT}/build/output/rootfs"

ARCH="${1:-x86_64}"
ROOTFS="${OUTPUT_DIR}/${ARCH}"

BUSYBOX_VERSION="1.36.1"
MUSL_VERSION="1.2.5"

echo "============================================"
echo "  [DistroName]OS Rootfs Build"
echo "============================================"
echo "  Architecture : $ARCH"
echo "  BusyBox      : $BUSYBOX_VERSION"
echo "  musl libc    : $MUSL_VERSION"
echo "============================================"
echo ""

# Create rootfs structure
echo "[1/5] Creating rootfs structure..."
mkdir -p "$ROOTFS"/{bin,sbin,etc,proc,sys,dev,tmp,var,usr/{bin,sbin,lib},run,mnt,root}
mkdir -p "$ROOTFS"/etc/{init.d,network}

# Download & build musl (placeholder)
echo "[2/5] Building musl libc..."
echo "TODO: Download musl-${MUSL_VERSION} and cross-compile for ${ARCH}"

# Download & build BusyBox (placeholder)
echo "[3/5] Building BusyBox..."
echo "TODO: Download busybox-${BUSYBOX_VERSION}, apply ${USERSPACE_DIR}/busybox.config, and cross-compile"

# Install init scripts
echo "[4/5] Installing init scripts..."
cp "${USERSPACE_DIR}/init" "$ROOTFS/sbin/init" 2>/dev/null || true
cp "${USERSPACE_DIR}/inittab" "$ROOTFS/etc/inittab" 2>/dev/null || true
cp "${USERSPACE_DIR}/rcS" "$ROOTFS/etc/init.d/rcS" 2>/dev/null || true
chmod +x "$ROOTFS/sbin/init" 2>/dev/null || true
chmod +x "$ROOTFS/etc/init.d/rcS" 2>/dev/null || true

# Create initramfs
echo "[5/5] Creating initramfs..."
cd "$ROOTFS"
find . | cpio -o -H newc | gzip > "${OUTPUT_DIR}/${ARCH}-initramfs.cpio.gz"

echo ""
echo "============================================"
echo "  Rootfs build complete!"
echo "  Output: ${OUTPUT_DIR}/${ARCH}-initramfs.cpio.gz"
echo "============================================"
