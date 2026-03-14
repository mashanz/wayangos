/*
 * WayangOS POS Kiosk Demo
 * Direct framebuffer rendering — zero dependencies
 * Draws a simple POS interface to /dev/fb0
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/fb.h>

typedef struct {
    unsigned char *mem;
    int w, h, bpp, line_len;
    long size;
} Framebuffer;

static void fb_pixel(Framebuffer *fb, int x, int y, unsigned char r, unsigned char g, unsigned char b) {
    if (x < 0 || x >= fb->w || y < 0 || y >= fb->h) return;
    long off = y * fb->line_len + x * fb->bpp;
    if (fb->bpp == 4) {
        fb->mem[off+0] = b; fb->mem[off+1] = g; fb->mem[off+2] = r; fb->mem[off+3] = 0xFF;
    } else if (fb->bpp == 3) {
        fb->mem[off+0] = b; fb->mem[off+1] = g; fb->mem[off+2] = r;
    }
}

static void fb_rect(Framebuffer *fb, int x, int y, int w, int h, unsigned char r, unsigned char g, unsigned char b) {
    for (int j = y; j < y + h; j++)
        for (int i = x; i < x + w; i++)
            fb_pixel(fb, i, j, r, g, b);
}

static void fb_hline(Framebuffer *fb, int x, int y, int w, unsigned char r, unsigned char g, unsigned char b) {
    fb_rect(fb, x, y, w, 2, r, g, b);
}

/* Simple 5x7 bitmap font */
static const unsigned char font_5x7[][7] = {
    /* space */ {0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    /* ! */     {0x04,0x04,0x04,0x04,0x00,0x04,0x00},
    /* " */     {0x0A,0x0A,0x00,0x00,0x00,0x00,0x00},
    /* # */     {0x0A,0x1F,0x0A,0x1F,0x0A,0x00,0x00},
    /* $ */     {0x04,0x0F,0x14,0x0E,0x05,0x1E,0x04},
    /* % */     {0x18,0x19,0x02,0x04,0x08,0x13,0x03},
    /* & */     {0x08,0x14,0x08,0x15,0x12,0x0D,0x00},
    /* ' */     {0x04,0x04,0x00,0x00,0x00,0x00,0x00},
    /* ( */     {0x02,0x04,0x04,0x04,0x04,0x02,0x00},
    /* ) */     {0x08,0x04,0x04,0x04,0x04,0x08,0x00},
    /* * */     {0x00,0x04,0x15,0x0E,0x15,0x04,0x00},
    /* + */     {0x00,0x04,0x04,0x1F,0x04,0x04,0x00},
    /* , */     {0x00,0x00,0x00,0x00,0x04,0x04,0x08},
    /* - */     {0x00,0x00,0x00,0x1F,0x00,0x00,0x00},
    /* . */     {0x00,0x00,0x00,0x00,0x00,0x04,0x00},
    /* / */     {0x01,0x02,0x04,0x08,0x10,0x00,0x00},
    /* 0 */     {0x0E,0x11,0x13,0x15,0x19,0x0E,0x00},
    /* 1 */     {0x04,0x0C,0x04,0x04,0x04,0x0E,0x00},
    /* 2 */     {0x0E,0x11,0x01,0x06,0x08,0x1F,0x00},
    /* 3 */     {0x0E,0x11,0x02,0x01,0x11,0x0E,0x00},
    /* 4 */     {0x02,0x06,0x0A,0x12,0x1F,0x02,0x00},
    /* 5 */     {0x1F,0x10,0x1E,0x01,0x11,0x0E,0x00},
    /* 6 */     {0x06,0x08,0x1E,0x11,0x11,0x0E,0x00},
    /* 7 */     {0x1F,0x01,0x02,0x04,0x08,0x08,0x00},
    /* 8 */     {0x0E,0x11,0x0E,0x11,0x11,0x0E,0x00},
    /* 9 */     {0x0E,0x11,0x11,0x0F,0x02,0x0C,0x00},
    /* : */     {0x00,0x04,0x00,0x00,0x04,0x00,0x00},
};

static int char_index(char c) {
    if (c == ' ') return 0;
    if (c >= '!' && c <= ':') return c - '!' + 1;
    if (c >= 'A' && c <= 'Z') return c - 'A' + 33;  /* won't work, just show space */
    if (c >= 'a' && c <= 'z') return c - 'a' + 33;
    return 0;
}

static void fb_char(Framebuffer *fb, int x, int y, char c, int scale, unsigned char r, unsigned char g, unsigned char b) {
    int idx = 0;
    if (c >= '0' && c <= '9') idx = c - '0' + 16;
    else if (c == '.') idx = 14;
    else if (c == ':') idx = 26;
    else if (c == '-') idx = 13;
    else if (c == '$') idx = 4;
    else if (c == ' ') idx = 0;
    else if (c == '!') idx = 1;
    else if (c >= 'A' && c <= 'Z') idx = 0; /* simplified */
    else if (c >= 'a' && c <= 'z') idx = 0;
    else idx = 0;

    for (int row = 0; row < 7; row++) {
        unsigned char bits = (idx < 27) ? font_5x7[idx][row] : 0;
        for (int col = 0; col < 5; col++) {
            if (bits & (0x10 >> col)) {
                fb_rect(fb, x + col * scale, y + row * scale, scale, scale, r, g, b);
            }
        }
    }
}

static void fb_text(Framebuffer *fb, int x, int y, const char *text, int scale, unsigned char r, unsigned char g, unsigned char b) {
    while (*text) {
        fb_char(fb, x, y, *text, scale, r, g, b);
        x += 6 * scale;
        text++;
    }
}

/* Draw POS kiosk interface */
static void draw_pos(Framebuffer *fb) {
    int w = fb->w, h = fb->h;

    /* Background - dark gray */
    fb_rect(fb, 0, 0, w, h, 30, 30, 35);

    /* Header bar - teal */
    fb_rect(fb, 0, 0, w, h/10, 0, 150, 136);

    /* Title */
    fb_text(fb, w/20, h/40, "--- 908 ---", 4, 255, 255, 255);

    /* Left panel - menu items */
    int panel_w = w * 6 / 10;
    int panel_h = h - h/10 - 20;
    int panel_y = h/10 + 10;
    fb_rect(fb, 10, panel_y, panel_w, panel_h, 45, 45, 50);

    /* Menu items */
    int item_h = panel_h / 6;
    const char *items[] = {"1. 15000", "2. 25000", "3. 12000", "4. 35000", "5.  8000"};
    unsigned char colors[][3] = {{70,180,70}, {70,130,220}, {220,160,40}, {220,70,70}, {180,70,220}};

    for (int i = 0; i < 5; i++) {
        int iy = panel_y + 10 + i * item_h;
        /* Item color bar */
        fb_rect(fb, 20, iy, 8, item_h - 10, colors[i][0], colors[i][1], colors[i][2]);
        /* Item bg */
        fb_rect(fb, 35, iy, panel_w - 45, item_h - 10, 55, 55, 60);
        /* Price */
        fb_text(fb, 50, iy + item_h/4, items[i], 3, 230, 230, 230);
    }

    /* Right panel - order summary */
    int rpx = panel_w + 20;
    int rpw = w - rpx - 10;
    fb_rect(fb, rpx, panel_y, rpw, panel_h, 45, 45, 50);

    /* Order title */
    fb_text(fb, rpx + 10, panel_y + 15, "--- 0 ---", 3, 200, 200, 200);

    /* Divider */
    fb_hline(fb, rpx + 10, panel_y + 60, rpw - 20, 80, 80, 85);

    /* Order items */
    fb_text(fb, rpx + 15, panel_y + 80, "2 : 30000", 2, 180, 180, 180);
    fb_text(fb, rpx + 15, panel_y + 110, "1 : 12000", 2, 180, 180, 180);

    /* Total divider */
    fb_hline(fb, rpx + 10, panel_y + panel_h - 120, rpw - 20, 80, 80, 85);

    /* Total */
    fb_text(fb, rpx + 15, panel_y + panel_h - 100, "--- 42000", 3, 0, 200, 150);

    /* Pay button */
    int btn_y = panel_y + panel_h - 55;
    fb_rect(fb, rpx + 10, btn_y, rpw - 20, 45, 0, 180, 130);
    fb_text(fb, rpx + rpw/4, btn_y + 12, "--- 0 ---", 3, 255, 255, 255);

    /* Footer */
    fb_text(fb, 10, h - 20, "--- 908 0.2 ---", 2, 100, 100, 100);
}

int main(int argc, char *argv[]) {
    const char *fbdev = getenv("FBDEV");
    if (!fbdev) fbdev = "/dev/fb0";

    int fd = open(fbdev, O_RDWR);
    if (fd < 0) { perror("open fb"); return 1; }

    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    ioctl(fd, FBIOGET_VSCREENINFO, &vinfo);
    ioctl(fd, FBIOGET_FSCREENINFO, &finfo);

    Framebuffer fb = {
        .w = vinfo.xres, .h = vinfo.yres,
        .bpp = vinfo.bits_per_pixel / 8,
        .line_len = finfo.line_length,
        .size = finfo.line_length * vinfo.yres
    };

    fb.mem = mmap(0, fb.size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb.mem == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    printf("POS Kiosk: %dx%d %dbpp\n", fb.w, fb.h, fb.bpp*8);

    draw_pos(&fb);
    printf("POS interface rendered. Press Ctrl+C to exit.\n");

    while(1) sleep(60);

    munmap(fb.mem, fb.size);
    close(fd);
    return 0;
}
