/*
 * WayangOS POS Kiosk v2 - Direct Framebuffer + Input
 * Amber/gold theme matching WayangOS brand
 * Keyboard, mouse & touchscreen support via /dev/input
 * Zero dependencies, static binary
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <linux/fb.h>
#include <linux/input.h>

#include "font8x16.h"

/* ===== Framebuffer ===== */
typedef struct { unsigned char *mem; int w,h,bpp,stride; long size; } FB;

static inline void px(FB *f, int x, int y, int r, int g, int b) {
    if(x<0||x>=f->w||y<0||y>=f->h) return;
    long o=y*f->stride+x*f->bpp;
    f->mem[o]=b;f->mem[o+1]=g;f->mem[o+2]=r;if(f->bpp==4)f->mem[o+3]=0xFF;
}

static void rect(FB *f,int x,int y,int w,int h,int r,int g,int b) {
    for(int j=y;j<y+h&&j<f->h;j++) for(int i=x;i<x+w&&i<f->w;i++) px(f,i,j,r,g,b);
}

static void rect_border(FB *f,int x,int y,int w,int h,int thick,int r,int g,int b) {
    rect(f,x,y,w,thick,r,g,b);         /* top */
    rect(f,x,y+h-thick,w,thick,r,g,b); /* bottom */
    rect(f,x,y,thick,h,r,g,b);         /* left */
    rect(f,x+w-thick,y,thick,h,r,g,b); /* right */
}

static void draw_char(FB *f,int x,int y,char c,int sc,int r,int g,int b) {
    if(c<32||c>126)c='?';
    int idx=c-32;
    for(int row=0;row<16;row++){
        unsigned char bits=font8x16[idx][row];
        for(int col=0;col<8;col++)
            if(bits&(0x80>>col)){
                if(sc==1) px(f,x+col,y+row,r,g,b);
                else rect(f,x+col*sc,y+row*sc,sc,sc,r,g,b);
            }
    }
}

static void text(FB *f,int x,int y,const char *s,int sc,int r,int g,int b) {
    while(*s){draw_char(f,x,y,*s,sc,r,g,b);x+=8*sc+sc;s++;}
}

static int tw(const char *s,int sc){return strlen(s)*(8*sc+sc)-sc;}

static void text_right(FB *f,int rx,int y,const char *s,int sc,int r,int g,int b) {
    text(f,rx-tw(s,sc),y,s,sc,r,g,b);
}

/* ===== Amber/Gold Color Palette (matching WayangOS web) ===== */
#define BG_R 20
#define BG_G 18
#define BG_B 12

#define PANEL_R 30
#define PANEL_G 27
#define PANEL_B 18

#define BORDER_R 80
#define BORDER_G 70
#define BORDER_B 30

#define GOLD_R 220
#define GOLD_G 180
#define GOLD_B 40

#define AMBER_R 200
#define AMBER_G 150
#define AMBER_B 20

#define TEXT_R 200
#define TEXT_G 190
#define TEXT_B 160

#define DIM_R 120
#define DIM_G 110
#define DIM_B 80

#define GREEN_R 40
#define GREEN_G 180
#define GREEN_B 80

#define BLUE_R 40
#define BLUE_G 80
#define BLUE_B 180

#define RED_R 200
#define RED_G 60
#define RED_B 40

#define SEL_R 60
#define SEL_G 50
#define SEL_B 20

/* ===== Menu & Order ===== */
typedef struct { const char *name; int price; int cat; } Item;
typedef struct { int item_idx; int qty; } OrderLine;

static Item menu[] = {
    {"Kopi Tubruk",   8000,  0},
    {"Es Kopi Susu", 15000,  0},
    {"Teh Tarik",    10000,  0},
    {"Nasi Goreng",  18000,  1},
    {"Mie Goreng",   15000,  1},
    {"Roti Bakar",   12000,  1},
    {"Pisang Goreng", 8000,  2},
    {"Es Jeruk",      8000,  2},
    {"Indomie",      10000,  2},
};
#define MENU_COUNT 9

static const char *cats[] = {"ALL","DRINKS","FOOD","SNACKS"};
static int cur_cat = 0;
static OrderLine order[32];
static int order_count = 0;
static int order_num = 247;

static void add_to_order(int idx) {
    for (int i = 0; i < order_count; i++) {
        if (order[i].item_idx == idx) { order[i].qty++; return; }
    }
    if (order_count < 32) {
        order[order_count].item_idx = idx;
        order[order_count].qty = 1;
        order_count++;
    }
}

static void clear_order(void) { order_count = 0; order_num++; }

static int order_total(void) {
    int t = 0;
    for (int i = 0; i < order_count; i++) t += order[i].qty * menu[order[i].item_idx].price;
    return t;
}

static int order_items(void) {
    int t = 0;
    for (int i = 0; i < order_count; i++) t += order[i].qty;
    return t;
}

/* ===== Layout regions (for hit testing) ===== */
typedef struct { int x,y,w,h; int action; } HitBox;
static HitBox hits[32];
static int hit_count = 0;

/* ===== Draw ===== */
static void draw(FB *f) {
    int W=f->w, H=f->h;
    hit_count = 0;

    /* Proportional layout */
    int hdr_h = H/14;
    int ftr_h = H/22;
    int cat_h = H/18;
    int menu_y = hdr_h;
    int menu_h = H - hdr_h - ftr_h - cat_h;
    int cat_y = menu_y + menu_h;
    int rpanel_w = W*35/100;
    int lpanel_w = W - rpanel_w - 4;

    /* Background */
    rect(f, 0, 0, W, H, BG_R, BG_G, BG_B);

    /* Header */
    rect(f, 0, 0, W, hdr_h, PANEL_R, PANEL_G, PANEL_B);
    rect(f, 0, hdr_h-2, W, 2, BORDER_R, BORDER_G, BORDER_B);
    text(f, 10, hdr_h/2-12, "WAYANG POS", 2, GOLD_R, GOLD_G, GOLD_B);

    /* Store name */
    text(f, W/3, hdr_h/2-6, "Warung Kopi Nusantara", 1, DIM_R, DIM_G, DIM_B);

    /* Clock */
    time_t now = time(NULL);
    struct tm *t_info = localtime(&now);
    char clock_str[32], date_str[16];
    strftime(clock_str, sizeof(clock_str), "%H:%M", t_info);
    strftime(date_str, sizeof(date_str), "%b %d", t_info);
    text(f, W-tw(clock_str,2)-tw(date_str,1)-30, hdr_h/2-12, clock_str, 2, GOLD_R, GOLD_G, GOLD_B);
    text(f, W-tw(date_str,1)-10, hdr_h/2-6, date_str, 1, DIM_R, DIM_G, DIM_B);

    /* === Left Panel: Menu === */
    text(f, 10, menu_y+5, "MENU", 1, DIM_R, DIM_G, DIM_B);

    int cols = 3;
    int rows = 3;
    int card_gap = 6;
    int card_w = (lpanel_w - 20 - (cols-1)*card_gap) / cols;
    int card_h = (menu_h - 30) / rows - card_gap;
    int grid_y = menu_y + 22;

    for (int i = 0; i < MENU_COUNT; i++) {
        /* Filter by category */
        if (cur_cat > 0 && menu[i].cat != cur_cat - 1) continue;

        int col = i % cols;
        int row = i / cols;
        int cx = 10 + col * (card_w + card_gap);
        int cy = grid_y + row * (card_h + card_gap);

        /* Card with border */
        rect(f, cx, cy, card_w, card_h, PANEL_R, PANEL_G, PANEL_B);

        /* Check if item is in order (highlight) */
        int in_order = 0;
        for (int j = 0; j < order_count; j++)
            if (order[j].item_idx == i) { in_order = order[j].qty; break; }

        if (in_order > 0) {
            rect(f, cx, cy, card_w, card_h, SEL_R, SEL_G, SEL_B);
            /* Quantity badge */
            char badge[8];
            snprintf(badge, sizeof(badge), "%d", in_order);
            int bx = cx + card_w - 22;
            rect(f, bx, cy+4, 18, 16, GOLD_R, GOLD_G, GOLD_B);
            draw_char(f, bx+5, cy+4, badge[0], 1, BG_R, BG_G, BG_B);
        }

        rect_border(f, cx, cy, card_w, card_h, 1, BORDER_R, BORDER_G, BORDER_B);

        /* Item name */
        text(f, cx+8, cy+8, menu[i].name, 1, TEXT_R, TEXT_G, TEXT_B);

        /* Price */
        char price[32];
        snprintf(price, sizeof(price), "Rp %d.%03d", menu[i].price/1000, menu[i].price%1000);
        text(f, cx+8, cy+card_h-20, price, 1, AMBER_R, AMBER_G, AMBER_B);

        /* Hit box */
        if (hit_count < 32) {
            hits[hit_count].x = cx; hits[hit_count].y = cy;
            hits[hit_count].w = card_w; hits[hit_count].h = card_h;
            hits[hit_count].action = i; /* menu item index */
            hit_count++;
        }
    }

    /* Category tabs */
    rect(f, 0, cat_y, lpanel_w+4, cat_h, PANEL_R, PANEL_G, PANEL_B);
    rect(f, 0, cat_y, lpanel_w+4, 1, BORDER_R, BORDER_G, BORDER_B);
    int tab_w = (lpanel_w) / 4;
    for (int i = 0; i < 4; i++) {
        int tx = 10 + i * tab_w;
        if (i == cur_cat) {
            rect(f, tx, cat_y+4, tab_w-8, cat_h-8, SEL_R, SEL_G, SEL_B);
            rect_border(f, tx, cat_y+4, tab_w-8, cat_h-8, 1, GOLD_R, GOLD_G, GOLD_B);
            text(f, tx+8, cat_y+cat_h/2-6, cats[i], 1, GOLD_R, GOLD_G, GOLD_B);
        } else {
            rect_border(f, tx, cat_y+4, tab_w-8, cat_h-8, 1, BORDER_R, BORDER_G, BORDER_B);
            text(f, tx+8, cat_y+cat_h/2-6, cats[i], 1, DIM_R, DIM_G, DIM_B);
        }
        /* Tab hitbox: action 100+i */
        if (hit_count < 32) {
            hits[hit_count].x=tx; hits[hit_count].y=cat_y;
            hits[hit_count].w=tab_w-8; hits[hit_count].h=cat_h;
            hits[hit_count].action=100+i;
            hit_count++;
        }
    }

    /* === Right Panel: Order === */
    int rx = lpanel_w + 4;
    rect(f, rx, hdr_h, rpanel_w, H-hdr_h-ftr_h, PANEL_R, PANEL_G, PANEL_B);
    rect(f, rx, hdr_h, 2, H-hdr_h-ftr_h, BORDER_R, BORDER_G, BORDER_B);

    /* Order header */
    text(f, rx+12, hdr_h+8, "CURRENT ORDER", 1, DIM_R, DIM_G, DIM_B);
    char onum[16];
    snprintf(onum, sizeof(onum), "#%04d", order_num);
    text_right(f, W-10, hdr_h+8, onum, 1, DIM_R, DIM_G, DIM_B);

    /* Order items */
    int oy = hdr_h + 30;
    rect(f, rx+10, oy, rpanel_w-20, 1, BORDER_R, BORDER_G, BORDER_B);
    oy += 8;

    for (int i = 0; i < order_count && oy < cat_y - 150; i++) {
        int idx = order[i].item_idx;
        text(f, rx+12, oy, menu[idx].name, 1, TEXT_R, TEXT_G, TEXT_B);

        char qty_str[8];
        snprintf(qty_str, sizeof(qty_str), "x%d", order[i].qty);
        text(f, rx+12, oy+18, qty_str, 1, DIM_R, DIM_G, DIM_B);

        char sub[16];
        int subtotal = order[i].qty * menu[idx].price;
        snprintf(sub, sizeof(sub), "Rp %d", subtotal);
        text_right(f, W-12, oy+4, sub, 1, AMBER_R, AMBER_G, AMBER_B);

        oy += 40;
    }

    /* Totals */
    int total = order_total();
    int tax = total * 11 / 100;
    int grand = total + tax;

    int tot_y = cat_y - 120;
    rect(f, rx+10, tot_y, rpanel_w-20, 1, BORDER_R, BORDER_G, BORDER_B);
    tot_y += 8;

    char buf[32];
    snprintf(buf, sizeof(buf), "Rp %d", total);
    text(f, rx+12, tot_y, "SUBTOTAL", 1, DIM_R, DIM_G, DIM_B);
    text_right(f, W-12, tot_y, buf, 1, TEXT_R, TEXT_G, TEXT_B);
    tot_y += 20;

    snprintf(buf, sizeof(buf), "Rp %d", tax);
    text(f, rx+12, tot_y, "TAX 11%", 1, DIM_R, DIM_G, DIM_B);
    text_right(f, W-12, tot_y, buf, 1, TEXT_R, TEXT_G, TEXT_B);
    tot_y += 25;

    /* Grand total */
    snprintf(buf, sizeof(buf), "Rp %d", grand);
    text(f, rx+12, tot_y, "TOTAL", 2, GOLD_R, GOLD_G, GOLD_B);
    text_right(f, W-12, tot_y, buf, 2, GOLD_R, GOLD_G, GOLD_B);
    tot_y += 40;

    /* Payment section */
    text(f, rx+12, tot_y, "PAYMENT", 1, DIM_R, DIM_G, DIM_B);
    tot_y += 18;

    int btn_w = (rpanel_w - 36) / 2;
    /* CASH */
    rect(f, rx+12, tot_y, btn_w, 28, GREEN_R, GREEN_G, GREEN_B);
    text(f, rx+20, tot_y+6, "CASH", 1, 255, 255, 255);
    if (hit_count < 32) {
        hits[hit_count].x=rx+12; hits[hit_count].y=tot_y;
        hits[hit_count].w=btn_w; hits[hit_count].h=28;
        hits[hit_count].action=200; hit_count++;
    }

    /* QRIS */
    rect(f, rx+16+btn_w, tot_y, btn_w, 28, BLUE_R, BLUE_G, BLUE_B);
    text(f, rx+24+btn_w, tot_y+6, "QRIS", 1, 255, 255, 255);
    if (hit_count < 32) {
        hits[hit_count].x=rx+16+btn_w; hits[hit_count].y=tot_y;
        hits[hit_count].w=btn_w; hits[hit_count].h=28;
        hits[hit_count].action=201; hit_count++;
    }
    tot_y += 36;

    /* PAY button */
    snprintf(buf, sizeof(buf), "PAY Rp %d.%03d", grand/1000, grand%1000);
    rect(f, rx+12, tot_y, rpanel_w-24, 36, AMBER_R, AMBER_G, AMBER_B);
    text(f, rx+rpanel_w/2-tw(buf,2)/2, tot_y+6, buf, 2, BG_R, BG_G, BG_B);
    if (hit_count < 32) {
        hits[hit_count].x=rx+12; hits[hit_count].y=tot_y;
        hits[hit_count].w=rpanel_w-24; hits[hit_count].h=36;
        hits[hit_count].action=202; hit_count++;
    }

    /* Footer */
    rect(f, 0, H-ftr_h, W, ftr_h, PANEL_R, PANEL_G, PANEL_B);
    rect(f, 0, H-ftr_h, W, 1, BORDER_R, BORDER_G, BORDER_B);
    text(f, 10, H-ftr_h+6, "wayang:pos", 1, GOLD_R, GOLD_G, GOLD_B);

    /* Uptime */
    FILE *up = fopen("/proc/uptime", "r");
    if (up) {
        float secs; fscanf(up, "%f", &secs); fclose(up);
        int d=(int)secs/86400, h=((int)secs%86400)/3600, m=((int)secs%3600)/60;
        snprintf(buf, sizeof(buf), "Uptime: %dd %dh %dm", d, h, m);
        text(f, W/3, H-ftr_h+6, buf, 1, DIM_R, DIM_G, DIM_B);
    }

    /* RAM */
    FILE *mi = fopen("/proc/meminfo", "r");
    if (mi) {
        long total_kb=0, free_kb=0;
        char line[128];
        while(fgets(line,sizeof(line),mi)) {
            if(strncmp(line,"MemTotal:",9)==0) sscanf(line+9,"%ld",&total_kb);
            if(strncmp(line,"MemAvailable:",13)==0) sscanf(line+13,"%ld",&free_kb);
        }
        fclose(mi);
        snprintf(buf, sizeof(buf), "RAM: %ld/%ld MB", (total_kb-free_kb)/1024, total_kb/1024);
        text_right(f, W-10, H-ftr_h+6, buf, 1, DIM_R, DIM_G, DIM_B);
    }

    /* SSH info */
    text(f, W/6, H-ftr_h+6, "SSH: :22", 1, DIM_R, DIM_G, DIM_B);
}

/* ===== Input handling ===== */
static int open_input_devices(int fds[], int max) {
    int count = 0;
    DIR *dir = opendir("/dev/input");
    if (!dir) return 0;
    struct dirent *ent;
    while ((ent = readdir(dir)) && count < max) {
        if (strncmp(ent->d_name, "event", 5) == 0) {
            char path[64];
            snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
            int fd = open(path, O_RDONLY | O_NONBLOCK);
            if (fd >= 0) fds[count++] = fd;
        }
    }
    closedir(dir);
    return count;
}

static int hit_test(int x, int y) {
    for (int i = 0; i < hit_count; i++) {
        if (x >= hits[i].x && x < hits[i].x + hits[i].w &&
            y >= hits[i].y && y < hits[i].y + hits[i].h)
            return hits[i].action;
    }
    return -1;
}

static void handle_action(int action) {
    if (action >= 0 && action < MENU_COUNT) {
        add_to_order(action);
    } else if (action >= 100 && action <= 103) {
        cur_cat = action - 100;
    } else if (action == 200 || action == 201 || action == 202) {
        /* Payment - clear order */
        clear_order();
    }
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

    FB fb = {.w=vi.xres,.h=vi.yres,.bpp=vi.bits_per_pixel/8,
             .stride=fi.line_length,.size=fi.line_length*vi.yres};
    unsigned char *fbmem = mmap(0, fb.size, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    if (fbmem == MAP_FAILED) { perror("mmap"); return 1; }

    /* Double buffer: draw offscreen then memcpy to fb */
    unsigned char *backbuf = malloc(fb.size);
    if (!backbuf) { perror("malloc"); return 1; }
    fb.mem = backbuf;

    /* Open input devices */
    int inp_fds[8];
    int inp_count = open_input_devices(inp_fds, 8);

    /* Initial render */
    int mouse_x = fb.w/2, mouse_y = fb.h/2;
    int needs_redraw = 1;
    int last_minute = -1;

    printf("WayangOS POS: %dx%d, %d inputs\n", fb.w, fb.h, inp_count);

    while (1) {
        if (needs_redraw) {
            draw(&fb);
            memcpy(fbmem, backbuf, fb.size); /* single atomic flip */
            needs_redraw = 0;
        }

        /* Poll input */
        fd_set rfds;
        FD_ZERO(&rfds);
        int maxfd = 0;
        for (int i = 0; i < inp_count; i++) {
            FD_SET(inp_fds[i], &rfds);
            if (inp_fds[i] > maxfd) maxfd = inp_fds[i];
        }

        struct timeval tv = {10, 0}; /* 10 second timeout */
        int ret = select(maxfd+1, &rfds, NULL, NULL, &tv);

        if (ret == 0) {
            /* Only redraw if minute changed */
            time_t now = time(NULL);
            struct tm *tm = localtime(&now);
            if (tm->tm_min != last_minute) {
                last_minute = tm->tm_min;
                needs_redraw = 1;
            }
            continue;
        }

        for (int i = 0; i < inp_count; i++) {
            if (!FD_ISSET(inp_fds[i], &rfds)) continue;

            struct input_event ev;
            while (read(inp_fds[i], &ev, sizeof(ev)) == sizeof(ev)) {
                if (ev.type == EV_KEY && ev.value == 1) {
                    /* Key press */
                    if (ev.code >= KEY_1 && ev.code <= KEY_9) {
                        int idx = ev.code - KEY_1;
                        if (idx < MENU_COUNT) { add_to_order(idx); needs_redraw = 1; }
                    } else if (ev.code == KEY_0 || ev.code == KEY_DELETE || ev.code == KEY_BACKSPACE) {
                        clear_order(); needs_redraw = 1;
                    } else if (ev.code == KEY_ENTER || ev.code == KEY_SPACE) {
                        /* Pay */
                        clear_order(); needs_redraw = 1;
                    } else if (ev.code == KEY_TAB) {
                        cur_cat = (cur_cat + 1) % 4; needs_redraw = 1;
                    } else if (ev.code == KEY_Q || ev.code == KEY_ESC) {
                        goto done;
                    }
                    /* Mouse button */
                    else if (ev.code == BTN_LEFT || ev.code == BTN_TOUCH) {
                        int action = hit_test(mouse_x, mouse_y);
                        if (action >= 0) { handle_action(action); needs_redraw = 1; }
                    }
                }
                /* Mouse movement */
                else if (ev.type == EV_REL) {
                    if (ev.code == REL_X) mouse_x += ev.value;
                    if (ev.code == REL_Y) mouse_y += ev.value;
                    if (mouse_x < 0) mouse_x = 0;
                    if (mouse_y < 0) mouse_y = 0;
                    if (mouse_x >= fb.w) mouse_x = fb.w-1;
                    if (mouse_y >= fb.h) mouse_y = fb.h-1;
                }
                /* Touchscreen (absolute) */
                else if (ev.type == EV_ABS) {
                    if (ev.code == ABS_X) mouse_x = ev.value * fb.w / 32768;
                    if (ev.code == ABS_Y) mouse_y = ev.value * fb.h / 32768;
                }
            }
        }
    }

done:
    for (int i = 0; i < inp_count; i++) close(inp_fds[i]);
    free(backbuf);
    munmap(fbmem, fb.size);
    close(fd);
    return 0;
}
