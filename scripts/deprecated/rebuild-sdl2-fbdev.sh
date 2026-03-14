#!/bin/bash
set -e
cd ~/wayangos-build

echo "=== Current SDL2 config ==="
if [ -f sdl2-install/lib/libSDL2.a ]; then
    strings sdl2-install/lib/libSDL2.a | grep -i "fbdev\|kmsdrm\|video driver" | head -5
fi

echo ""
echo "=== Rebuilding SDL2 with fbdev + kmsdrm ==="
cd SDL2-2.30.10

# Install libdrm headers for kmsdrm support
sudo apt-get install -y libdrm-dev 2>/dev/null || true

# Clean and reconfigure
make clean 2>/dev/null || true

# Configure with fbdev and kmsdrm enabled
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
    --disable-filesystem \
    --disable-threads \
    --disable-timers \
    --disable-file \
    --disable-loadso \
    --disable-cpuinfo \
    --disable-assembly \
    --enable-video \
    --enable-video-fbdev \
    --enable-video-kmsdrm \
    --disable-video-x11 \
    --disable-video-wayland \
    --disable-video-opengl \
    --disable-video-opengles \
    --disable-video-opengles2 \
    --disable-video-vulkan \
    --disable-render \
    --disable-events \
    --enable-render \
    --enable-events \
    2>&1 | grep -E "fbdev|kmsdrm|Video driver"

echo ""
echo "=== Building ==="
make -j$(nproc) 2>&1 | tail -3
make install 2>&1 | tail -3

echo ""
echo "=== Verify SDL2 has fbdev ==="
strings ~/wayangos-build/sdl2-install/lib/libSDL2.a | grep -i "fbdev\|kmsdrm" | sort -u

echo ""
echo "=== Rebuilding viewer with new SDL2 ==="
cd ~/wayangos-build/wayangos-viewer
make clean 2>/dev/null || true

musl-gcc -static -O2 \
    -I ~/wayangos-build/sdl2-install/include/SDL2 \
    -o viewer viewer.c \
    -L ~/wayangos-build/sdl2-install/lib \
    -lSDL2 -lm -lpthread -ldl 2>&1

ls -lh viewer
file viewer
echo ""
echo "=== Test viewer lists available drivers ==="
SDL_VIDEODRIVER=dummy timeout 1 ./viewer /dev/null 2>&1 || true

echo "=== DONE ==="
