#!/bin/bash
cd ~/wayangos-build/SDL2-2.30.10

echo "=== CheckKMSDRM function in configure ==="
grep -A40 "CheckKMSDRM()" configure | head -50

echo ""
echo "=== pkg-config check for gbm ==="
pkg-config --cflags gbm 2>&1
pkg-config --libs gbm 2>&1
pkg-config --modversion gbm 2>&1

echo ""
echo "=== pkg-config check for libdrm ==="
pkg-config --cflags libdrm 2>&1
pkg-config --libs libdrm 2>&1
