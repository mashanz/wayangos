#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

# Start from headless config
cp ../kernel-headless.config .config

# Enable PREEMPT_RT and related options
scripts/config --enable PREEMPT_RT
scripts/config --set-val HZ 1000
scripts/config --enable HZ_1000
scripts/config --disable HZ_250
scripts/config --enable HIGH_RES_TIMERS
scripts/config --enable NO_HZ_FULL

# Run olddefconfig to resolve dependencies
make olddefconfig 2>&1 | tail -3

# Verify RT is enabled
echo "=== RT Config Check ==="
grep -E "PREEMPT_RT|HZ=|HZ_1000|HIGH_RES_TIMERS" .config | head -10

# Build headless kernel
echo "=== Building Headless RT Kernel ==="
make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-headless
ls -lh ~/wayangos-build/vmlinuz-rt-headless

# Now build GUI kernel
echo "=== Building GUI RT Kernel ==="
cp ../kernel-gui.config .config
scripts/config --enable PREEMPT_RT
scripts/config --set-val HZ 1000
scripts/config --enable HZ_1000
scripts/config --disable HZ_250
scripts/config --enable HIGH_RES_TIMERS
scripts/config --enable NO_HZ_FULL
make olddefconfig 2>&1 | tail -3
make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-gui
ls -lh ~/wayangos-build/vmlinuz-rt-gui

echo "=== KERNELS DONE ==="
