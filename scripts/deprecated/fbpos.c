/*
 * WayangOS POS Kiosk - Direct Framebuffer Edition
 * Full POS interface with embedded bitmap font
 * Renders to /dev/fb0, zero dependencies
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/fb.h>

/* ===== Framebuffer ===== */
typedef struct {
    unsigned char *mem;
    int w, h, bpp, stride;
    long size;
} FB;

static inline void px(FB *f, int x, int y, int r, int g, int b) {
    if (x<0||x>=f->w||y<0||y>=f->h) return;
    long o = y*f->stride + x*f->bpp;
    f->mem[o]=b; f->mem[o+1]=g; f->mem[o+2]=r; if(f->bpp==4) f->mem[o+3]=0xFF;
}

static void rect(FB *f, int x, int y, int w, int h, int r, int g, int b) {
    for(int j=y;j<y+h&&j<f->h;j++)
        for(int i=x;i<x+w&&i<f->w;i++)
            px(f,i,j,r,g,b);
}

static void rect_round(FB *f, int x, int y, int w, int h, int rad, int r, int g, int b) {
    /* Simple rounded rect - just draw main rect + round corners */
    rect(f, x+rad, y, w-2*rad, h, r, g, b);
    rect(f, x, y+rad, rad, h-2*rad, r, g, b);
    rect(f, x+w-rad, y+rad, rad, h-2*rad, r, g, b);
    /* Corner circles (approximate with filled squares for speed) */
    for(int cy=0;cy<rad;cy++)
        for(int cx=0;cx<rad;cx++) {
            int dx=rad-cx-1, dy=rad-cy-1;
            if(dx*dx+dy*dy <= rad*rad) {
                px(f,x+cx,y+cy,r,g,b);
                px(f,x+w-1-cx,y+cy,r,g,b);
                px(f,x+cx,y+h-1-cy,r,g,b);
                px(f,x+w-1-cx,y+h-1-cy,r,g,b);
            }
        }
}

/* ===== Embedded 8x16 bitmap font (CP437-style) ===== */
/* We embed a minimal ASCII font covering 0x20-0x7E (space to ~) */
/* Each char is 8 pixels wide, 16 pixels tall, stored as 16 bytes */

#include "font8x16.h"  /* Generated font data */

static void draw_char(FB *f, int x, int y, char c, int scale, int r, int g, int b) {
    if (c < 32 || c > 126) c = '?';
    int idx = c - 32;
    for (int row = 0; row < 16; row++) {
        unsigned char bits = font8x16[idx][row];
        for (int col = 0; col < 8; col++) {
            if (bits & (0x80 >> col)) {
                if (scale == 1)
                    px(f, x+col, y+row, r, g, b);
                else
                    rect(f, x+col*scale, y+row*scale, scale, scale, r, g, b);
            }
        }
    }
}

static void text(FB *f, int x, int y, const char *s, int scale, int r, int g, int b) {
    while (*s) {
        draw_char(f, x, y, *s, scale, r, g, b);
        x += 8 * scale + scale; /* char width + spacing */
        s++;
    }
}

static int text_width(const char *s, int scale) {
    int len = strlen(s);
    return len * (8 * scale + scale) - scale;
}

static void text_center(FB *f, int cx, int y, const char *s, int scale, int r, int g, int b) {
    int w = text_width(s, scale);
    text(f, cx - w/2, y, s, scale, r, g, b);
}

/* ===== Color palette ===== */
#define BG_R 25
#define BG_G 27
#define BG_B 32

#define HEADER_R 0
#define HEADER_G 150
#define HEADER_B 136

#define CARD_R 40
#define CARD_G 42
#define CARD_B 48

#define CARD_HOVER_R 55
#define CARD_HOVER_G 57
#define CARD_HOVER_B 63

#define TEXT_R 230
#define TEXT_G 230
#define TEXT_B 235

#define DIM_R 140
#define DIM_G 142
#define DIM_B 148

#define ACCENT_R 0
#define ACCENT_G 200
#define ACCENT_B 150

/* ===== Menu items ===== */
typedef struct {
    const char *name;
    const char *price_str;
    int price;
    int cat; /* 0=drink, 1=food, 2=snack */
    int qty;
} MenuItem;

static MenuItem menu[] = {
    {"Kopi Tubruk",    "Rp  8.000",  8000, 0, 0},
    {"Es Kopi Susu",   "Rp 12.000", 12000, 0, 0},
    {"Teh Tarik",      "Rp  7.000",  7000, 0, 0},
    {"Nasi Goreng",    "Rp 15.000", 15000, 1, 0},
    {"Mie Ayam",       "Rp 12.000", 12000, 1, 0},
    {"Sate Ayam",      "Rp 18.000", 18000, 1, 0},
    {"Pisang Goreng",  "Rp  5.000",  5000, 2, 0},
    {"Roti Bakar",     "Rp  8.000",  8000, 2, 0},
    {"Kerupuk",        "Rp  3.000",  3000, 2, 0},
};
#define MENU_COUNT 9

static const char *cat_names[] = {"ALL", "DRINKS", "FOOD", "SNACKS"};

/* ===== Draw POS ===== */
static void draw_pos(FB *f) {
    int W = f->w, H = f->h;
    int header_h = H / 12;
    int footer_h = H / 20;
    int cat_h = header_h * 2 / 3;
    int body_y = header_h + cat_h + 5;
    int body_h = H - body_y - footer_h;
    int panel_w = W * 62 / 100;  /* 62% left panel */
    int right_x = panel_w + 10;
    int right_w = W - right_x - 5;

    /* Background */
    rect(f, 0, 0, W, H, BG_R, BG_G, BG_B);

    /* Header */
    rect(f, 0, 0, W, header_h, HEADER_R, HEADER_G, HEADER_B);
    text(f, 15, header_h/2 - 8, "WayangOS POS", 2, 255, 255, 255);
    text(f, W - 200, header_h/2 - 6, "v0.2", 1, 200, 255, 230);

    /* Category tabs */
    int tab_w = panel_w / 4;
    for (int i = 0; i < 4; i++) {
        int tx = i * tab_w;
        int sel = (i == 0); /* ALL selected */
        rect(f, tx, header_h, tab_w - 2, cat_h,
             sel ? HEADER_R : CARD_R,
             sel ? HEADER_G : CARD_G,
             sel ? HEADER_B : CARD_B);
        text_center(f, tx + tab_w/2, header_h + cat_h/2 - 6, cat_names[i], 1,
                    sel ? 255 : DIM_R, sel ? 255 : DIM_G, sel ? 255 : DIM_B);
    }

    /* Menu grid - 3 columns */
    int cols = 3;
    int rows = (MENU_COUNT + cols - 1) / cols;
    int card_w = (panel_w - 20) / cols - 8;
    int card_h = (body_h - 10) / rows - 8;
    int card_pad = 8;

    for (int i = 0; i < MENU_COUNT; i++) {
        int col = i % cols;
        int row = i / cols;
        int cx = 10 + col * (card_w + card_pad);
        int cy = body_y + 5 + row * (card_h + card_pad);

        /* Card background */
        rect_round(f, cx, cy, card_w, card_h, 6, CARD_R, CARD_G, CARD_B);

        /* Item number circle */
        int circle_y = cy + 10;
        int circle_x = cx + 15;
        for (int dy=-10; dy<=10; dy++)
            for (int dx=-10; dx<=10; dx++)
                if (dx*dx+dy*dy <= 100)
                    px(f, circle_x+dx, circle_y+dy, HEADER_R, HEADER_G, HEADER_B);
        char num[4];
        snprintf(num, sizeof(num), "%d", i+1);
        draw_char(f, circle_x-4, circle_y-7, num[0], 1, 255, 255, 255);

        /* Item name */
        text(f, cx + 35, cy + 5, menu[i].name, 1, TEXT_R, TEXT_G, TEXT_B);

        /* Price */
        text(f, cx + 35, cy + 22, menu[i].price_str, 1, ACCENT_R, ACCENT_G, ACCENT_B);

        /* Quantity badge if ordered */
        if (menu[i].qty > 0) {
            int bx = cx + card_w - 25;
            int by = cy + 5;
            rect_round(f, bx, by, 20, 18, 4, 220, 60, 60);
            char qstr[4];
            snprintf(qstr, sizeof(qstr), "%d", menu[i].qty);
            draw_char(f, bx+6, by+1, qstr[0], 1, 255, 255, 255);
        }
    }

    /* Right panel - Order summary */
    rect_round(f, right_x, body_y, right_w, body_h, 8, CARD_R, CARD_G, CARD_B);

    /* Order header */
    text(f, right_x + 15, body_y + 10, "Order #001", 2, TEXT_R, TEXT_G, TEXT_B);

    /* Divider */
    rect(f, right_x + 10, body_y + 45, right_w - 20, 1, 60, 62, 68);

    /* Order items */
    int oy = body_y + 55;

    /* Simulated order */
    menu[1].qty = 2; /* 2x Es Kopi Susu */
    menu[3].qty = 1; /* 1x Nasi Goreng */
    menu[6].qty = 3; /* 3x Pisang Goreng */

    int total = 0;
    int item_count = 0;
    for (int i = 0; i < MENU_COUNT; i++) {
        if (menu[i].qty > 0) {
            char line[64];
            int subtotal = menu[i].qty * menu[i].price;
            total += subtotal;
            item_count += menu[i].qty;

            snprintf(line, sizeof(line), "%dx %s", menu[i].qty, menu[i].name);
            text(f, right_x + 15, oy, line, 1, TEXT_R, TEXT_G, TEXT_B);

            snprintf(line, sizeof(line), "Rp %d", subtotal);
            text(f, right_x + right_w - 15 - text_width(line, 1), oy, line, 1, DIM_R, DIM_G, DIM_B);
            oy += 22;
        }
    }

    /* Tax */
    int tax = total * 10 / 100;
    int grand = total + tax;

    oy += 10;
    rect(f, right_x + 10, oy, right_w - 20, 1, 60, 62, 68);
    oy += 10;

    char buf[64];
    snprintf(buf, sizeof(buf), "Subtotal: Rp %d", total);
    text(f, right_x + 15, oy, buf, 1, DIM_R, DIM_G, DIM_B);
    oy += 20;
    snprintf(buf, sizeof(buf), "Tax 10%%: Rp %d", tax);
    text(f, right_x + 15, oy, buf, 1, DIM_R, DIM_G, DIM_B);
    oy += 25;

    /* Total */
    rect(f, right_x + 10, oy, right_w - 20, 1, 60, 62, 68);
    oy += 10;
    snprintf(buf, sizeof(buf), "TOTAL: Rp %d", grand);
    text(f, right_x + 15, oy, buf, 2, ACCENT_R, ACCENT_G, ACCENT_B);

    /* Payment buttons */
    int btn_w = (right_w - 30) / 2;
    int btn_y = body_y + body_h - 55;

    /* CASH button */
    rect_round(f, right_x + 10, btn_y, btn_w, 40, 6, HEADER_R, HEADER_G, HEADER_B);
    text_center(f, right_x + 10 + btn_w/2, btn_y + 12, "CASH", 2, 255, 255, 255);

    /* QRIS button */
    rect_round(f, right_x + 15 + btn_w, btn_y, btn_w, 40, 6, 100, 50, 200);
    text_center(f, right_x + 15 + btn_w + btn_w/2, btn_y + 12, "QRIS", 2, 255, 255, 255);

    /* Item count badge */
    snprintf(buf, sizeof(buf), "%d items", item_count);
    text(f, right_x + 15, btn_y - 22, buf, 1, DIM_R, DIM_G, DIM_B);

    /* Footer / status bar */
    rect(f, 0, H - footer_h, W, footer_h, 20, 22, 26);
    text(f, 10, H - footer_h + 5, "WayangOS v0.2 | POS Kiosk Demo", 1, 80, 82, 88);

    char status[128];
    snprintf(status, sizeof(status), "Screen: %dx%d | SSH: 22", W, H);
    text(f, W - text_width(status, 1) - 10, H - footer_h + 5, status, 1, 80, 82, 88);
}

int main(void) {
    const char *dev = getenv("FBDEV");
    if (!dev) dev = "/dev/fb0";

    int fd = open(dev, O_RDWR);
    if (fd < 0) { perror("open fb"); return 1; }

    struct fb_var_screeninfo vi;
    struct fb_fix_screeninfo fi;
    ioctl(fd, FBIOGET_VSCREENINFO, &vi);
    ioctl(fd, FBIOGET_FSCREENINFO, &fi);

    FB fb = { .w=vi.xres, .h=vi.yres, .bpp=vi.bits_per_pixel/8,
              .stride=fi.line_length, .size=fi.line_length*vi.yres };
    fb.mem = mmap(0, fb.size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb.mem == MAP_FAILED) { perror("mmap"); return 1; }

    draw_pos(&fb);

    while(1) sleep(60);
    munmap(fb.mem, fb.size);
    close(fd);
    return 0;
}
