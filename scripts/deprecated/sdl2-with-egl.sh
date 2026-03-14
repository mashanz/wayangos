#!/bin/bash
set -e

echo "=== Check EGL availability ==="
pkg-config --cflags --libs egl 2>&1 || echo "egl not found via pkg-config"
ls /usr/include/EGL/egl.h 2>/dev/null || echo "EGL headers missing"
ls /usr/lib/x86_64-linux-gnu/libEGL* 2>/dev/null | head -3 || echo "No libEGL"

echo ""
echo "=== Install EGL dev if missing ==="
# Try to install - use -u root to avoid sudo hang
wsl.exe -d Ubuntu -u root -- apt-get install -y libegl-dev libgles2-mesa-dev 2>/dev/null || true

echo ""
echo "=== Reconfigure SDL2 ==="
cd ~/wayangos-build/SDL2-2.30.10
make distclean 2>/dev/null || true

PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig \
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
    --enable-video-opengles \
    --enable-video-opengles2 \
    --disable-video-x11 \
    --disable-video-wayland \
    --disable-video-opengl \
    --disable-video-vulkan \
    --disable-video-rpi \
    --enable-render \
    --enable-events \
    2>&1 | tee /tmp/sdl2-egl.log | grep -iE "Video driver|kmsdrm|egl|opengles|Summary" | head -15

echo ""
echo "=== Video drivers ==="
grep "Video drivers" /tmp/sdl2-egl.log

echo ""
echo "=== SDL_config.h KMSDRM ==="
grep "KMSDRM" ~/wayangos-build/SDL2-2.30.10/include/SDL_config.h

echo "=== DONE ==="
