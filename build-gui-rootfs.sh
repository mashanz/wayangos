#!/bin/bash
set -e

BUILD=~/wayangos-build
ROOTFS_SRC=$BUILD/rootfs-v2
ROOTFS=$BUILD/rootfs-gui
SDL2_VER=2.30.10

echo "=== Building WayangOS GUI Rootfs ==="

# Start from headless rootfs
rm -rf $ROOTFS
cp -a $ROOTFS_SRC $ROOTFS

# ============================================
# 1. Build SDL2 (static, framebuffer backend)
# ============================================
echo "[1/3] Building SDL2 (static, fbdev)..."

cd $BUILD
if [ ! -f "SDL2-$SDL2_VER.tar.gz" ]; then
    wget -q "https://github.com/libsdl-org/SDL/releases/download/release-$SDL2_VER/SDL2-$SDL2_VER.tar.gz"
fi

rm -rf SDL2-$SDL2_VER
tar xzf SDL2-$SDL2_VER.tar.gz
cd SDL2-$SDL2_VER

mkdir -p build && cd build

# Configure: static only, framebuffer + KMSDRM, no X11/Wayland/Pulseaudio
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-Os" \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_X11=OFF \
    -DSDL_WAYLAND=OFF \
    -DSDL_KMSDRM=ON \
    -DSDL_OPENGL=OFF \
    -DSDL_OPENGLES=OFF \
    -DSDL_VULKAN=OFF \
    -DSDL_PULSEAUDIO=OFF \
    -DSDL_ALSA=OFF \
    -DSDL_JACK=OFF \
    -DSDL_PIPEWIRE=OFF \
    -DSDL_DBUS=OFF \
    -DSDL_IBUS=OFF \
    -DSDL_FCITX=OFF \
    -DSDL_HIDAPI=OFF \
    -DCMAKE_INSTALL_PREFIX=$BUILD/sdl2-install \
    2>&1 | tail -5

make -j$(nproc) 2>&1 | tail -5
make install 2>&1 | tail -3

echo "  SDL2 static lib: $(du -h $BUILD/sdl2-install/lib/libSDL2.a | cut -f1)"

# ============================================
# 2. Build demo kiosk app (static, SDL2)
# ============================================
echo "[2/3] Building demo kiosk app..."

cat > $BUILD/kiosk-demo.c << 'DEMO'
#include <SDL2/SDL.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/sysinfo.h>

// WayangOS Kiosk Demo — system monitor dashboard

static void draw_text_block(SDL_Renderer *r, int x, int y, const char *text, 
                            int scale, Uint8 cr, Uint8 cg, Uint8 cb) {
    // Simple 5x7 pixel font renderer (subset)
    static const unsigned char font[][5] = {
        [' '-' '] = {0x00,0x00,0x00,0x00,0x00},
        ['!'-' '] = {0x00,0x00,0x5F,0x00,0x00},
        ['.'-' '] = {0x00,0x60,0x60,0x00,0x00},
        ['/'-' '] = {0x20,0x10,0x08,0x04,0x02},
        ['0'-' '] = {0x3E,0x51,0x49,0x45,0x3E},
        ['1'-' '] = {0x00,0x42,0x7F,0x40,0x00},
        ['2'-' '] = {0x42,0x61,0x51,0x49,0x46},
        ['3'-' '] = {0x21,0x41,0x45,0x4B,0x31},
        ['4'-' '] = {0x18,0x14,0x12,0x7F,0x10},
        ['5'-' '] = {0x27,0x45,0x45,0x45,0x39},
        ['6'-' '] = {0x3C,0x4A,0x49,0x49,0x30},
        ['7'-' '] = {0x01,0x71,0x09,0x05,0x03},
        ['8'-' '] = {0x36,0x49,0x49,0x49,0x36},
        ['9'-' '] = {0x06,0x49,0x49,0x29,0x1E},
        [':'-' '] = {0x00,0x36,0x36,0x00,0x00},
        ['A'-' '] = {0x7E,0x11,0x11,0x11,0x7E},
        ['B'-' '] = {0x7F,0x49,0x49,0x49,0x36},
        ['C'-' '] = {0x3E,0x41,0x41,0x41,0x22},
        ['D'-' '] = {0x7F,0x41,0x41,0x22,0x1C},
        ['E'-' '] = {0x7F,0x49,0x49,0x49,0x41},
        ['F'-' '] = {0x7F,0x09,0x09,0x09,0x01},
        ['G'-' '] = {0x3E,0x41,0x49,0x49,0x7A},
        ['H'-' '] = {0x7F,0x08,0x08,0x08,0x7F},
        ['I'-' '] = {0x00,0x41,0x7F,0x41,0x00},
        ['K'-' '] = {0x7F,0x08,0x14,0x22,0x41},
        ['L'-' '] = {0x7F,0x40,0x40,0x40,0x40},
        ['M'-' '] = {0x7F,0x02,0x0C,0x02,0x7F},
        ['N'-' '] = {0x7F,0x04,0x08,0x10,0x7F},
        ['O'-' '] = {0x3E,0x41,0x41,0x41,0x3E},
        ['P'-' '] = {0x7F,0x09,0x09,0x09,0x06},
        ['R'-' '] = {0x7F,0x09,0x19,0x29,0x46},
        ['S'-' '] = {0x46,0x49,0x49,0x49,0x31},
        ['T'-' '] = {0x01,0x01,0x7F,0x01,0x01},
        ['U'-' '] = {0x3F,0x40,0x40,0x40,0x3F},
        ['V'-' '] = {0x1F,0x20,0x40,0x20,0x1F},
        ['W'-' '] = {0x3F,0x40,0x38,0x40,0x3F},
        ['Y'-' '] = {0x07,0x08,0x70,0x08,0x07},
        ['a'-' '] = {0x20,0x54,0x54,0x54,0x78},
        ['b'-' '] = {0x7F,0x48,0x44,0x44,0x38},
        ['c'-' '] = {0x38,0x44,0x44,0x44,0x20},
        ['d'-' '] = {0x38,0x44,0x44,0x48,0x7F},
        ['e'-' '] = {0x38,0x54,0x54,0x54,0x18},
        ['f'-' '] = {0x08,0x7E,0x09,0x01,0x02},
        ['g'-' '] = {0x0C,0x52,0x52,0x52,0x3E},
        ['h'-' '] = {0x7F,0x08,0x04,0x04,0x78},
        ['i'-' '] = {0x00,0x44,0x7D,0x40,0x00},
        ['k'-' '] = {0x7F,0x10,0x28,0x44,0x00},
        ['l'-' '] = {0x00,0x41,0x7F,0x40,0x00},
        ['m'-' '] = {0x7C,0x04,0x18,0x04,0x78},
        ['n'-' '] = {0x7C,0x08,0x04,0x04,0x78},
        ['o'-' '] = {0x38,0x44,0x44,0x44,0x38},
        ['p'-' '] = {0x7C,0x14,0x14,0x14,0x08},
        ['r'-' '] = {0x7C,0x08,0x04,0x04,0x08},
        ['s'-' '] = {0x48,0x54,0x54,0x54,0x20},
        ['t'-' '] = {0x04,0x3F,0x44,0x40,0x20},
        ['u'-' '] = {0x3C,0x40,0x40,0x20,0x7C},
        ['v'-' '] = {0x1C,0x20,0x40,0x20,0x1C},
        ['w'-' '] = {0x3C,0x40,0x30,0x40,0x3C},
        ['y'-' '] = {0x0C,0x50,0x50,0x50,0x3C},
        ['%'-' '] = {0x23,0x13,0x08,0x64,0x62},
    };
    SDL_SetRenderDrawColor(r, cr, cg, cb, 255);
    for (int i = 0; text[i]; i++) {
        int ch = text[i] - ' ';
        if (ch < 0 || ch > 95) continue;
        for (int col = 0; col < 5; col++) {
            unsigned char bits = (ch < (int)(sizeof(font)/5)) ? font[ch][col] : 0;
            for (int row = 0; row < 7; row++) {
                if (bits & (1 << row)) {
                    SDL_Rect px = {x + (i*6+col)*scale, y + row*scale, scale, scale};
                    SDL_RenderFillRect(r, &px);
                }
            }
        }
    }
}

static void draw_bar(SDL_Renderer *r, int x, int y, int w, int h, float pct,
                     Uint8 cr, Uint8 cg, Uint8 cb) {
    SDL_SetRenderDrawColor(r, 30, 30, 40, 255);
    SDL_Rect bg = {x, y, w, h};
    SDL_RenderFillRect(r, &bg);
    int filled = (int)(w * (pct > 1.0f ? 1.0f : pct));
    SDL_SetRenderDrawColor(r, cr, cg, cb, 255);
    SDL_Rect fg = {x, y, filled, h};
    SDL_RenderFillRect(r, &fg);
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window *win = SDL_CreateWindow("WayangOS Monitor",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        640, 480, SDL_WINDOW_FULLSCREEN_DESKTOP);
    if (!win) {
        printf("Window failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
    SDL_ShowCursor(SDL_DISABLE);

    int running = 1;
    while (running) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT || 
                (ev.type == SDL_KEYDOWN && ev.key.keysym.sym == SDLK_ESCAPE))
                running = 0;
        }

        // Clear
        SDL_SetRenderDrawColor(ren, 10, 8, 6, 255);
        SDL_RenderClear(ren);

        // Header
        draw_text_block(ren, 20, 15, "WAYANGOS SYSTEM MONITOR", 3, 200, 148, 26);
        draw_text_block(ren, 20, 50, "The Shadow that Powers the Machine", 2, 120, 100, 60);

        // Divider
        SDL_SetRenderDrawColor(ren, 200, 148, 26, 80);
        SDL_Rect div = {20, 72, 600, 1};
        SDL_RenderFillRect(ren, &div);

        // System info
        struct sysinfo si;
        sysinfo(&si);
        
        char buf[128];
        
        // Uptime
        long hrs = si.uptime / 3600;
        long mins = (si.uptime % 3600) / 60;
        long secs = si.uptime % 60;
        snprintf(buf, sizeof(buf), "UPTIME: %02ld:%02ld:%02ld", hrs, mins, secs);
        draw_text_block(ren, 20, 90, buf, 2, 200, 200, 220);

        // Time
        time_t now = time(NULL);
        struct tm *t = localtime(&now);
        snprintf(buf, sizeof(buf), "TIME: %02d:%02d:%02d", t->tm_hour, t->tm_min, t->tm_sec);
        draw_text_block(ren, 350, 90, buf, 2, 200, 200, 220);

        // Memory
        unsigned long total_mb = si.totalram / 1024 / 1024;
        unsigned long used_mb = (si.totalram - si.freeram) / 1024 / 1024;
        float mem_pct = (float)used_mb / (float)total_mb;
        
        draw_text_block(ren, 20, 130, "MEMORY", 2, 200, 148, 26);
        snprintf(buf, sizeof(buf), "%lu / %lu MB", used_mb, total_mb);
        draw_text_block(ren, 20, 150, buf, 2, 160, 160, 180);
        draw_bar(ren, 20, 170, 600, 20, mem_pct, 100, 200, 100);

        // Load
        float load1 = si.loads[0] / 65536.0f;
        float load5 = si.loads[1] / 65536.0f;
        float load15 = si.loads[2] / 65536.0f;

        draw_text_block(ren, 20, 210, "LOAD AVERAGE", 2, 200, 148, 26);
        snprintf(buf, sizeof(buf), "1m: %.2f  5m: %.2f  15m: %.2f", load1, load5, load15);
        draw_text_block(ren, 20, 230, buf, 2, 160, 160, 180);
        draw_bar(ren, 20, 250, 600, 20, load1 / 4.0f, 200, 148, 26);

        // Processes
        draw_text_block(ren, 20, 290, "PROCESSES", 2, 200, 148, 26);
        snprintf(buf, sizeof(buf), "%d running", si.procs);
        draw_text_block(ren, 20, 310, buf, 2, 160, 160, 180);

        // Network placeholder
        draw_text_block(ren, 20, 350, "NETWORK", 2, 200, 148, 26);
        
        // Read IP
        FILE *fp = popen("ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print $2}'", "r");
        if (fp) {
            char ip[64] = "No network";
            if (fgets(ip, sizeof(ip), fp)) {
                ip[strcspn(ip, "\n")] = 0;
            }
            pclose(fp);
            snprintf(buf, sizeof(buf), "IP: %s  SSH: port 22", ip);
            draw_text_block(ren, 20, 370, buf, 2, 160, 160, 180);
        }

        // Footer
        draw_text_block(ren, 20, 440, "Press ESC to exit to shell", 2, 80, 70, 50);

        SDL_RenderPresent(ren);
        SDL_Delay(1000);
    }

    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
DEMO

# Compile static against SDL2
gcc -Os -static -o $BUILD/kiosk-demo $BUILD/kiosk-demo.c \
    -I$BUILD/sdl2-install/include \
    -L$BUILD/sdl2-install/lib \
    $(pkg-config --cflags --libs $BUILD/sdl2-install/lib/pkgconfig/sdl2.pc --static 2>/dev/null || echo "-lSDL2 -lm -lpthread -ldl -lrt") \
    2>&1

strip $BUILD/kiosk-demo
echo "  kiosk-demo: $(du -h $BUILD/kiosk-demo | cut -f1)"

# ============================================
# 3. Build GUI rootfs + initramfs
# ============================================
echo "[3/3] Building GUI rootfs..."

# Add kiosk demo
cp $BUILD/kiosk-demo $ROOTFS/usr/bin/kiosk-demo
chmod 755 $ROOTFS/usr/bin/kiosk-demo

# Update init to offer kiosk mode
cat > $ROOTFS/etc/init.d/kiosk << 'KIOSK'
#!/bin/sh
case "$1" in
    start)
        echo "  Starting kiosk display..."
        # Wait for framebuffer
        sleep 1
        if [ -e /dev/fb0 ] || [ -e /dev/dri/card0 ]; then
            export SDL_VIDEODRIVER=kmsdrm
            /usr/bin/kiosk-demo &
            echo "  Kiosk running on display"
        else
            export SDL_VIDEODRIVER=fbcon
            /usr/bin/kiosk-demo &
            echo "  Kiosk running (fbcon)"
        fi
        ;;
    stop)
        killall kiosk-demo 2>/dev/null
        ;;
esac
KIOSK
chmod +x $ROOTFS/etc/init.d/kiosk

# Update rcS to auto-start kiosk
sed -i '/WayangOS v0.2 ready/a\\n# Start kiosk display\n/etc/init.d/kiosk start' $ROOTFS/etc/init.d/rcS

# Create /dev entries for DRM
mkdir -p $ROOTFS/dev/dri

# Build initramfs
cd $ROOTFS
find . -print0 | cpio --null -o -H newc 2>/dev/null | gzip -9 > $BUILD/wayangos-0.2-gui-x86_64-initramfs.img

echo ""
echo "=== GUI Rootfs ==="
echo "  kiosk-demo: $(du -h usr/bin/kiosk-demo | cut -f1)"
echo "  Initramfs: $(du -h $BUILD/wayangos-0.2-gui-x86_64-initramfs.img | cut -f1)"
echo "=== Done ==="
