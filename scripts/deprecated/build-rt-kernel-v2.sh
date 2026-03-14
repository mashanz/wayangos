#!/bin/bash
set -e
cd ~/wayangos-build/linux-6.19.3

# === HEADLESS RT KERNEL ===
echo "=== Building Headless RT Kernel ==="
cp ../kernel-headless.config .config

# Enable EXPERT first (PREEMPT_RT depends on it)
scripts/config --enable EXPERT
scripts/config --enable ARCH_SUPPORTS_RT

# Enable RT and related
scripts/config --enable PREEMPT_RT
scripts/config --set-val HZ 1000
scripts/config --enable HZ_1000
scripts/config --disable HZ_250
scripts/config --disable HZ_100
scripts/config --enable HIGH_RES_TIMERS
scripts/config --enable NO_HZ_FULL

# Disable conflicting preempt modes
scripts/config --disable PREEMPT_NONE
scripts/config --disable PREEMPT_VOLUNTARY
scripts/config --disable PREEMPT
scripts/config --disable PREEMPT_DYNAMIC

make olddefconfig 2>&1 | tail -3

echo "--- RT Config Verification ---"
grep -E "PREEMPT_RT=|PREEMPT_NONE=|HZ=|HZ_1000=|HIGH_RES_TIMERS=" .config

make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-headless
echo "Headless RT:"
ls -lh ~/wayangos-build/vmlinuz-rt-headless
strings ~/wayangos-build/vmlinuz-rt-headless | grep "6\.19\.3" | head -1

# === GUI RT KERNEL ===
echo ""
echo "=== Building GUI RT Kernel ==="
cp ../kernel-gui.config .config

scripts/config --enable EXPERT
scripts/config --enable ARCH_SUPPORTS_RT
scripts/config --enable PREEMPT_RT
scripts/config --set-val HZ 1000
scripts/config --enable HZ_1000
scripts/config --disable HZ_250
scripts/config --disable HZ_100
scripts/config --enable HIGH_RES_TIMERS
scripts/config --enable NO_HZ_FULL
scripts/config --disable PREEMPT_NONE
scripts/config --disable PREEMPT_VOLUNTARY
scripts/config --disable PREEMPT
scripts/config --disable PREEMPT_DYNAMIC

make olddefconfig 2>&1 | tail -3

echo "--- RT Config Verification ---"
grep -E "PREEMPT_RT=|PREEMPT_NONE=|HZ=|HZ_1000=|HIGH_RES_TIMERS=" .config

make -j$(nproc) bzImage 2>&1 | tail -5
cp arch/x86/boot/bzImage ~/wayangos-build/vmlinuz-rt-gui
echo "GUI RT:"
ls -lh ~/wayangos-build/vmlinuz-rt-gui

echo ""
echo "=== ALL RT KERNELS DONE ==="
