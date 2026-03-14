#!/bin/bash
set -e
cd ~/wayangos-build/SDL2-2.30.10

echo "=== libdrm headers check ==="
ls /usr/include/xf86drm.h /usr/include/libdrm/drm.h
pkg-config --cflags --libs libdrm

echo ""
echo "=== Reconfigure SDL2 with KMSDRM ==="
make distclean 2>/dev/null || true

PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
CFLAGS="-I/usr/include/libdrm" \
./configure \
    --prefix="$HOME/wayangos-build/sdl2-install" \
    --enable-static \
    --disable-shared \
    --disable-audio \
    --disable-joystick \
    --disable-haptic \
    --disable-sensor \
    --disable-power \
    --enable-video \
    --enable-video-kmsdrm \
    --disable-video-x11 \
    --disable-video-wayland \
    --disable-video-opengl \
    --disable-video-opengles \
    --disable-video-opengles2 \
    --disable-video-vulkan \
    --disable-video-rpi \
    --enable-render \
    --enable-events \
    2>&1 | tee /tmp/sdl2-cfg3.log

echo ""
echo "=== Video drivers line ==="
grep "Video drivers" /tmp/sdl2-cfg3.log

echo ""
echo "=== KMSDRM check in config ==="
grep -i "kmsdrm" /tmp/sdl2-cfg3.log | head -10

echo ""
echo "=== Building ==="
make -j$(nproc) 2>&1 | tail -5
make install 2>&1 | tail -3

echo ""
echo "=== Verify KMSDRM in library ==="
strings ~/wayangos-build/sdl2-install/lib/libSDL2.a | grep -c "KMSDRM"
strings ~/wayangos-build/sdl2-install/lib/libSDL2.a | grep "kmsdrm\|KMSDRM" | sort -u | head -5

echo "=== DONE ==="
