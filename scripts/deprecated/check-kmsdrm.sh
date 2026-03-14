#!/bin/bash
echo "=== Searching configure log for kmsdrm ==="
grep -i "kmsdrm" /tmp/sdl2-cfg3.log

echo ""
echo "=== Searching for libdrm ==="
grep -i "libdrm" /tmp/sdl2-cfg3.log

echo ""
echo "=== Searching for gbm ==="
grep -i "gbm" /tmp/sdl2-cfg3.log

echo ""
echo "=== Check if libgbm is available ==="
pkg-config --cflags --libs gbm 2>&1
dpkg -l libgbm-dev 2>/dev/null | tail -2
