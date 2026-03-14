#!/bin/bash
echo "=== Full rcS script ==="
cat /tmp/initramfs-check/etc/init.d/rcS
echo ""
echo "=== Files in etc/init.d ==="
ls -la /tmp/initramfs-check/etc/init.d/
