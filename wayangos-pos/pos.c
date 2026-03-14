// WayangOS POS Kiosk Demo — renders to BMP file
#include <SDL2/SDL.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

// Minimal 5x7 bitmap font
static const unsigned char font5x7[][5] = {
    [' '-' '] = {0x00,0x00,0x00,0x00,0x00},
    ['!'-' '] = {0x00,0x00,0x5F,0x00,0x00},
    ['#'-' '] = {0x14,0x7F,0x14,0x7F,0x14},
    ['$'-' '] = {0x24,0x2A,0x7F,0x2A,0x12},
    ['%'-' '] = {0x23,0x13,0x08,0x64,0x62},
    ['('-' '] = {0x00,0x1C,0x22,0x41,0x00},
    [')'-' '] = {0x00,0x41,0x22,0x1C,0x00},
    ['*'-' '] = {0x14,0x08,0x3E,0x08,0x14},
    ['+'-' '] = {0x08,0x08,0x3E,0x08,0x08},
    [','-' '] = {0x00,0x50,0x30,0x00,0x00},
    ['-'-' '] = {0x08,0x08,0x08,0x08,0x08},
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
    ['@'-' '] = {0x32,0x49,0x79,0x41,0x3E},
    ['A'-' '] = {0x7E,0x11,0x11,0x11,0x7E},
    ['B'-' '] = {0x7F,0x49,0x49,0x49,0x36},
    ['C'-' '] = {0x3E,0x41,0x41,0x41,0x22},
    ['D'-' '] = {0x7F,0x41,0x41,0x22,0x1C},
    ['E'-' '] = {0x7F,0x49,0x49,0x49,0x41},
    ['F'-' '] = {0x7F,0x09,0x09,0x09,0x01},
    ['G'-' '] = {0x3E,0x41,0x49,0x49,0x7A},
    ['H'-' '] = {0x7F,0x08,0x08,0x08,0x7F},
    ['I'-' '] = {0x00,0x41,0x7F,0x41,0x00},
    ['J'-' '] = {0x20,0x40,0x41,0x3F,0x01},
    ['K'-' '] = {0x7F,0x08,0x14,0x22,0x41},
    ['L'-' '] = {0x7F,0x40,0x40,0x40,0x40},
    ['M'-' '] = {0x7F,0x02,0x0C,0x02,0x7F},
    ['N'-' '] = {0x7F,0x04,0x08,0x10,0x7F},
    ['O'-' '] = {0x3E,0x41,0x41,0x41,0x3E},
    ['P'-' '] = {0x7F,0x09,0x09,0x09,0x06},
    ['Q'-' '] = {0x3E,0x41,0x51,0x21,0x5E},
    ['R'-' '] = {0x7F,0x09,0x19,0x29,0x46},
    ['S'-' '] = {0x46,0x49,0x49,0x49,0x31},
    ['T'-' '] = {0x01,0x01,0x7F,0x01,0x01},
    ['U'-' '] = {0x3F,0x40,0x40,0x40,0x3F},
    ['V'-' '] = {0x1F,0x20,0x40,0x20,0x1F},
    ['W'-' '] = {0x3F,0x40,0x38,0x40,0x3F},
    ['X'-' '] = {0x63,0x14,0x08,0x14,0x63},
    ['Y'-' '] = {0x07,0x08,0x70,0x08,0x07},
    ['Z'-' '] = {0x61,0x51,0x49,0x45,0x43},
    ['a'-' '] = {0x20,0x54,0x54,0x54,0x78},
    ['b'-' '] = {0x7F,0x48,0x44,0x44,0x38},
    ['c'-' '] = {0x38,0x44,0x44,0x44,0x20},
    ['d'-' '] = {0x38,0x44,0x44,0x48,0x7F},
    ['e'-' '] = {0x38,0x54,0x54,0x54,0x18},
    ['f'-' '] = {0x08,0x7E,0x09,0x01,0x02},
    ['g'-' '] = {0x0C,0x52,0x52,0x52,0x3E},
    ['h'-' '] = {0x7F,0x08,0x04,0x04,0x78},
    ['i'-' '] = {0x00,0x44,0x7D,0x40,0x00},
    ['j'-' '] = {0x20,0x40,0x44,0x3D,0x00},
    ['k'-' '] = {0x7F,0x10,0x28,0x44,0x00},
    ['l'-' '] = {0x00,0x41,0x7F,0x40,0x00},
    ['m'-' '] = {0x7C,0x04,0x18,0x04,0x78},
    ['n'-' '] = {0x7C,0x08,0x04,0x04,0x78},
    ['o'-' '] = {0x38,0x44,0x44,0x44,0x38},
    ['p'-' '] = {0x7C,0x14,0x14,0x14,0x08},
    ['q'-' '] = {0x08,0x14,0x14,0x18,0x7C},
    ['r'-' '] = {0x7C,0x08,0x04,0x04,0x08},
    ['s'-' '] = {0x48,0x54,0x54,0x54,0x20},
    ['t'-' '] = {0x04,0x3F,0x44,0x40,0x20},
    ['u'-' '] = {0x3C,0x40,0x40,0x20,0x7C},
    ['v'-' '] = {0x1C,0x20,0x40,0x20,0x1C},
    ['w'-' '] = {0x3C,0x40,0x30,0x40,0x3C},
    ['x'-' '] = {0x44,0x28,0x10,0x28,0x44},
    ['y'-' '] = {0x0C,0x50,0x50,0x50,0x3C},
    ['z'-' '] = {0x44,0x64,0x54,0x4C,0x44},
};

static void draw_text(SDL_Renderer *r, int x, int y, const char *text,
                      int scale, Uint8 cr, Uint8 cg, Uint8 cb) {
    SDL_SetRenderDrawColor(r, cr, cg, cb, 255);
    for (int i = 0; text[i]; i++) {
        int ch = text[i] - ' ';
        if (ch < 0 || ch >= (int)(sizeof(font5x7)/5)) continue;
        for (int col = 0; col < 5; col++) {
            unsigned char bits = font5x7[ch][col];
            for (int row = 0; row < 7; row++) {
                if (bits & (1 << row)) {
                    SDL_Rect px = {x + (i*6+col)*scale, y + row*scale, scale, scale};
                    SDL_RenderFillRect(r, &px);
                }
            }
        }
    }
}

static void draw_rect(SDL_Renderer *r, int x, int y, int w, int h,
                      Uint8 cr, Uint8 cg, Uint8 cb) {
    SDL_SetRenderDrawColor(r, cr, cg, cb, 255);
    SDL_Rect rect = {x, y, w, h};
    SDL_RenderFillRect(r, &rect);
}

static void draw_rect_outline(SDL_Renderer *r, int x, int y, int w, int h,
                              Uint8 cr, Uint8 cg, Uint8 cb) {
    SDL_SetRenderDrawColor(r, cr, cg, cb, 255);
    SDL_Rect rect = {x, y, w, h};
    SDL_RenderDrawRect(r, &rect);
}

int main(int argc, char *argv[]) {
    (void)argc; (void)argv;
    
    SDL_Init(SDL_INIT_VIDEO);
    
    int W = 1024, H = 600;
    SDL_Window *win = SDL_CreateWindow("POS", 0, 0, W, H, SDL_WINDOW_HIDDEN);
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
    
    // ========== COLORS ==========
    // Background
    SDL_SetRenderDrawColor(ren, 14, 12, 10, 255);
    SDL_RenderClear(ren);
    
    // ========== HEADER BAR ==========
    draw_rect(ren, 0, 0, W, 45, 200, 148, 26);
    draw_text(ren, 16, 10, "WAYANG POS", 3, 0, 0, 0);
    draw_text(ren, 320, 16, "Warung Kopi Nusantara", 2, 40, 30, 10);
    draw_text(ren, 780, 10, "14:32", 3, 0, 0, 0);
    draw_text(ren, 900, 16, "Mar 12", 2, 40, 30, 10);
    
    // ========== LEFT PANEL: MENU GRID ==========
    int menuX = 16, menuY = 60;
    draw_text(ren, menuX, menuY, "MENU", 2, 200, 148, 26);
    
    // Menu items grid (3 columns)
    typedef struct { const char *name; const char *price; int active; } MenuItem;
    MenuItem items[] = {
        {"Kopi Tubruk",    "Rp 8.000",  1},
        {"Es Kopi Susu",   "Rp 15.000", 1},
        {"Teh Tarik",      "Rp 10.000", 0},
        {"Nasi Goreng",    "Rp 18.000", 1},
        {"Mie Goreng",     "Rp 15.000", 0},
        {"Roti Bakar",     "Rp 12.000", 1},
        {"Pisang Goreng",  "Rp 8.000",  0},
        {"Es Jeruk",       "Rp 8.000",  0},
        {"Indomie",        "Rp 10.000", 0},
    };
    
    int cols = 3, cardW = 190, cardH = 75, gap = 10;
    for (int i = 0; i < 9; i++) {
        int cx = menuX + (i % cols) * (cardW + gap);
        int cy = menuY + 20 + (i / cols) * (cardH + gap);
        
        if (items[i].active) {
            draw_rect(ren, cx, cy, cardW, cardH, 40, 32, 18);
            draw_rect_outline(ren, cx, cy, cardW, cardH, 200, 148, 26);
        } else {
            draw_rect(ren, cx, cy, cardW, cardH, 26, 22, 16);
            draw_rect_outline(ren, cx, cy, cardW, cardH, 50, 42, 28);
        }
        
        draw_text(ren, cx + 10, cy + 12, items[i].name, 2, 220, 215, 200);
        draw_text(ren, cx + 10, cy + 38, items[i].price, 2, 
                  items[i].active ? 200 : 120, 
                  items[i].active ? 148 : 100, 
                  items[i].active ? 26 : 60);
        
        if (items[i].active) {
            draw_rect(ren, cx + cardW - 25, cy + 5, 18, 14, 200, 148, 26);
            draw_text(ren, cx + cardW - 22, cy + 7, "1", 1, 0, 0, 0);
        }
    }
    
    // ========== CATEGORY TABS ==========
    int tabY = menuY + 20 + 3 * (cardH + gap) + 15;
    const char *tabs[] = {"ALL", "DRINKS", "FOOD", "SNACKS"};
    int tabActive = 0;
    for (int i = 0; i < 4; i++) {
        int tx = menuX + i * 155;
        if (i == tabActive) {
            draw_rect(ren, tx, tabY, 145, 28, 200, 148, 26);
            draw_text(ren, tx + 10, tabY + 6, tabs[i], 2, 0, 0, 0);
        } else {
            draw_rect_outline(ren, tx, tabY, 145, 28, 60, 50, 35);
            draw_text(ren, tx + 10, tabY + 6, tabs[i], 2, 120, 100, 70);
        }
    }
    
    // ========== RIGHT PANEL: ORDER ==========
    int orderX = 640, orderW = W - orderX - 16;
    
    // Order header
    draw_rect(ren, orderX, 60, orderW, 30, 26, 22, 16);
    draw_text(ren, orderX + 12, 66, "CURRENT ORDER", 2, 200, 148, 26);
    draw_text(ren, orderX + orderW - 70, 66, "#0247", 2, 120, 100, 70);
    
    // Order divider
    draw_rect(ren, orderX, 90, orderW, 1, 50, 42, 28);
    
    // Order items
    typedef struct { const char *name; int qty; int price; } OrderItem;
    OrderItem order[] = {
        {"Kopi Tubruk",    2, 16000},
        {"Es Kopi Susu",   1, 15000},
        {"Nasi Goreng",    1, 18000},
        {"Roti Bakar",     1, 12000},
    };
    
    int total = 0;
    for (int i = 0; i < 4; i++) {
        int oy = 100 + i * 50;
        char buf[64];
        
        // Item name
        draw_text(ren, orderX + 12, oy + 4, order[i].name, 2, 200, 195, 180);
        
        // Qty badge
        snprintf(buf, sizeof(buf), "x%d", order[i].qty);
        draw_text(ren, orderX + 12, oy + 22, buf, 2, 120, 100, 70);
        
        // Price
        snprintf(buf, sizeof(buf), "Rp %d", order[i].price);
        draw_text(ren, orderX + orderW - 100, oy + 12, buf, 2, 200, 148, 26);
        
        // Divider
        draw_rect(ren, orderX + 12, oy + 42, orderW - 24, 1, 35, 30, 22);
        
        total += order[i].price;
    }
    
    // ========== TOTAL ==========
    int totalY = 310;
    draw_rect(ren, orderX, totalY, orderW, 2, 200, 148, 26);
    
    draw_text(ren, orderX + 12, totalY + 14, "SUBTOTAL", 2, 120, 100, 70);
    char buf[64];
    snprintf(buf, sizeof(buf), "Rp %d", total);
    draw_text(ren, orderX + orderW - 110, totalY + 14, buf, 2, 180, 170, 160);
    
    draw_text(ren, orderX + 12, totalY + 38, "TAX 11%", 2, 120, 100, 70);
    int tax = total * 11 / 100;
    snprintf(buf, sizeof(buf), "Rp %d", tax);
    draw_text(ren, orderX + orderW - 100, totalY + 38, buf, 2, 180, 170, 160);
    
    draw_rect(ren, orderX, totalY + 60, orderW, 1, 50, 42, 28);
    
    draw_text(ren, orderX + 12, totalY + 72, "TOTAL", 3, 200, 148, 26);
    snprintf(buf, sizeof(buf), "Rp %d", total + tax);
    draw_text(ren, orderX + orderW - 140, totalY + 72, buf, 3, 255, 220, 150);
    
    // ========== ACTION BUTTONS ==========
    int btnY = 460;
    
    // Payment method buttons
    draw_text(ren, orderX + 12, btnY - 20, "PAYMENT", 2, 120, 100, 70);
    
    // Cash button
    draw_rect(ren, orderX, btnY, (orderW-10)/2, 40, 40, 80, 40);
    draw_text(ren, orderX + 20, btnY + 10, "CASH", 2, 180, 255, 180);
    
    // QRIS button  
    draw_rect(ren, orderX + (orderW-10)/2 + 10, btnY, (orderW-10)/2, 40, 30, 40, 80);
    draw_text(ren, orderX + (orderW-10)/2 + 30, btnY + 10, "QRIS", 2, 150, 180, 255);
    
    // PAY button (big gold)
    draw_rect(ren, orderX, btnY + 52, orderW, 50, 200, 148, 26);
    draw_text(ren, orderX + orderW/2 - 80, btnY + 62, "PAY Rp 67.710", 3, 0, 0, 0);
    
    // ========== BOTTOM STATUS BAR ==========
    draw_rect(ren, 0, H - 28, W, 28, 20, 18, 14);
    draw_text(ren, 16, H - 22, "wayang:pos", 2, 200, 148, 26);
    draw_text(ren, 200, H - 22, "SSH: 192.168.1.42:22", 2, 80, 70, 50);
    draw_text(ren, 500, H - 22, "Uptime: 4d 12h", 2, 80, 70, 50);
    draw_text(ren, 750, H - 22, "RAM: 23/128 MB", 2, 80, 70, 50);
    
    // ========== SAVE ==========
    SDL_Surface *surface = SDL_CreateRGBSurface(0, W, H, 32, 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000);
    SDL_RenderReadPixels(ren, NULL, SDL_PIXELFORMAT_ARGB8888, surface->pixels, surface->pitch);
    SDL_SaveBMP(surface, "/tmp/wayangos-pos.bmp");
    SDL_FreeSurface(surface);
    
    printf("POS screenshot saved to /tmp/wayangos-pos.bmp (%dx%d)\n", W, H);
    
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
