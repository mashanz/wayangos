#!/bin/bash
cd ~/wayangos-build/linux-6.19.3
echo "=== CONFIG_DRM status ==="
grep "^CONFIG_DRM" .config

echo ""
echo "=== DRM drivers ==="
grep "CONFIG_DRM_BOCHS\|CONFIG_DRM_VIRTIO\|CONFIG_DRM_SIMPLE" .config

echo ""
echo "=== Framebuffer ==="
grep "^CONFIG_FB\|^CONFIG_FRAMEBUFFER_CONSOLE" .config

echo ""
echo "=== Are they modules or built-in? ==="
grep "^CONFIG_DRM=\|^CONFIG_PCI=\|^CONFIG_MMU=" .config
