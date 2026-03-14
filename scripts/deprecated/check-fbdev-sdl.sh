#!/bin/bash
cd ~/wayangos-build/SDL2-2.30.10

echo "=== SDL2 video driver directories ==="
ls src/video/

echo ""
echo "=== Any fbdev/fbcon driver? ==="
find src/video -name "*fb*" -o -name "*linux*" 2>/dev/null

echo ""
echo "=== SDL2 version ==="
head -3 configure.ac

echo ""
echo "=== Does SDL2 support linuxfb? ==="
grep -r "SDL_VIDEO_DRIVER_FBDEV\|SDL_fbvideo\|linuxfb\|SDL_VIDEO_DRIVER_DIRECTFB" include/SDL_config.h.in
