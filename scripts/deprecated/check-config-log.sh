#!/bin/bash
cd ~/wayangos-build/SDL2-2.30.10

echo "=== Searching config.log for kmsdrm ==="
grep -i "kmsdrm" config.log | head -20

echo ""
echo "=== Searching config.log for gbm ==="
grep -i "gbm" config.log | head -20

echo ""
echo "=== Check SDL_config.h for KMSDRM ==="
grep -i "KMSDRM\|VIDEO_FBDEV\|VIDEO_DUMMY" include/SDL_config.h | head -10

echo ""
echo "=== Check configure.ac for KMSDRM trigger ==="
grep -B2 -A5 "kmsdrm" configure | head -30
