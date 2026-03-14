#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3
echo "Building kernel with input support..."
make -j$(nproc) bzImage 2>&1 | tail -10
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-gui-with-input
ls -lh ~/wayangos-build/vmlinuz-gui-with-input
echo "BUILD_DONE"
