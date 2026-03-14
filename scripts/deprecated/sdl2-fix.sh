#!/bin/bash
set -e
cd ~/wayangos-build/SDL2-2.30.10

# Check available video-related configure options
./configure --help 2>/dev/null | grep -i "fbdev\|kmsdrm\|directfb\|video" | head -20

echo ""
echo "=== Test musl-gcc ==="
echo 'int main(){return 0;}' > /tmp/test.c
musl-gcc -static /tmp/test.c -o /tmp/test 2>&1 && echo "musl-gcc works" || echo "musl-gcc broken"

echo ""
echo "=== Test regular gcc ==="
gcc /tmp/test.c -o /tmp/test2 2>&1 && echo "gcc works" || echo "gcc broken"
