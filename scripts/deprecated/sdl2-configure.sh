#!/bin/bash
set -e
cd ~/wayangos-build/SDL2-2.30.10

make clean 2>/dev/null || true
make distclean 2>/dev/null || true

CC=musl-gcc ./configure \
    --prefix="$HOME/wayangos-build/sdl2-install" \
    --host=x86_64-linux-gnu \
    --enable-static \
    --disable-shared \
    --disable-audio \
    --disable-joystick \
    --disable-haptic \
    --disable-sensor \
    --disable-power \
    --enable-video \
    --enable-video-fbdev \
    --enable-video-kmsdrm \
    --disable-video-x11 \
    --disable-video-wayland \
    --disable-video-opengl \
    --disable-video-opengles \
    --disable-video-opengles2 \
    --disable-video-vulkan \
    --enable-render \
    --enable-events \
    2>&1 | tee /tmp/sdl2-configure.log | grep -iE "fbdev|kmsdrm|video|error|warning|checking" | tail -30

echo ""
echo "=== Config Summary ==="
grep -A50 "SDL2 Configure Summary" /tmp/sdl2-configure.log | head -55
