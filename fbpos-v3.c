/*
 * WayangOS POS Kiosk v3 - Direct Framebuffer + Input
 * Compact layout, amber/gold theme, double buffered
 * Keyboard + mouse + touchscreen via /dev/input + /dev/tty
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <time.h>
#include <errno.h>
/* termios.h removed - using pure evdev input */
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <linux/fb.h>
#include <linux/input.h>
#include <linux/kd.h>

#include "font8x16.h"

/* ===== Framebuffer ===== */
typedef struct { unsigned char *mem; int w,h,bpp,stride; long size; } FB;

static inline void px(FB *f, int x, int y, int r, int g, int b) {
    if(x<0||x>=f->w||y<0||y>=f->h) return;
    long o=y*f->stride+x*f->bpp;
    f->mem[o]=b;f->mem[o+1]=g;f->mem[o+2]=r;if(f->bpp==4)f->mem[o+3]=0xFF;
}

static void rect(FB *f,int x,int y,int w,int h,int r,int g,int b) {
    if(x<0){w+=x;x=0;} if(y<0){h+=y;y=0;}
    if(w<=0||h<=0)return;
    for(int j=y;j<y+h&&j<f->h;j++) for(int i=x;i<x+w&&i<f->w;i++) px(f,i,j,r,g,b);
}

static void hline(FB *f,int x,int y,int w,int r,int g,int b) { rect(f,x,y,w,1,r,g,b); }
static void vline(FB *f,int x,int y,int h,int r,int g,int b) { rect(f,x,y,1,h,r,g,b); }

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

static int tw(const char *s,int sc){int n=strlen(s);return n>0?n*(8*sc+sc)-sc:0;}

static void text_right(FB *f,int rx,int y,const char *s,int sc,int r,int g,int b) {
    text(f,rx-tw(s,sc),y,s,sc,r,g,b);
}

static void text_center(FB *f,int cx,int y,const char *s,int sc,int r,int g,int b) {
    text(f,cx-tw(s,sc)/2,y,s,sc,r,g,b);
}

/* ===== Amber/Gold Palette ===== */
enum {
    C_BG_R=20,C_BG_G=18,C_BG_B=12,
    C_PNL_R=30,C_PNL_G=27,C_PNL_B=18,
    C_BRD_R=70,C_BRD_G=60,C_BRD_B=25,
    C_GOLD_R=220,C_GOLD_G=180,C_GOLD_B=40,
    C_AMB_R=200,C_AMB_G=150,C_AMB_B=20,
    C_TXT_R=200,C_TXT_G=190,C_TXT_B=160,
    C_DIM_R=120,C_DIM_G=110,C_DIM_B=80,
    C_GRN_R=40,C_GRN_G=160,C_GRN_B=60,
    C_BLU_R=40,C_BLU_G=80,C_BLU_B=180,
    C_SEL_R=50,C_SEL_G=42,C_SEL_B=15,
};

/* ===== Menu & Order ===== */
typedef struct { const char *name; int price; int cat; } Item;
typedef struct { int idx; int qty; } OrderLine;

static Item menu[] = {
    {"Kopi Tubruk",    8000,  0},
    {"Es Kopi Susu",  15000,  0},
    {"Teh Tarik",     10000,  0},
    {"Nasi Goreng",   18000,  1},
    {"Mie Goreng",    15000,  1},
    {"Roti Bakar",    12000,  1},
    {"Pisang Goreng",  8000,  2},
    {"Es Jeruk",       8000,  2},
    {"Indomie",       10000,  2},
};
#define MCNT 9

static const char *cats[]={"ALL","DRINKS","FOOD","SNACKS"};
static int cur_cat=0;
static OrderLine order[32];
static int ocnt=0, onum=1;

static void order_add(int i){
    for(int j=0;j<ocnt;j++) if(order[j].idx==i){order[j].qty++;return;}
    if(ocnt<32){order[ocnt].idx=i;order[ocnt].qty=1;ocnt++;}
}
static void order_clear(void){ocnt=0;onum++;}
static int order_total(void){int t=0;for(int i=0;i<ocnt;i++)t+=order[i].qty*menu[order[i].idx].price;return t;}
static int order_count_items(void){int t=0;for(int i=0;i<ocnt;i++)t+=order[i].qty;return t;}

static void fmt_rp(char *buf, int sz, int val) {
    if(val==0){snprintf(buf,sz,"Rp 0");return;}
    snprintf(buf, sz, "Rp %d.%03d", val/1000, val%1000);
}

/* ===== Hit regions ===== */
typedef struct{int x,y,w,h,act;}Hit;
static Hit hits[48];
static int nhit=0;

static int hit_test(int mx,int my){
    for(int i=0;i<nhit;i++)
        if(mx>=hits[i].x&&mx<hits[i].x+hits[i].w&&my>=hits[i].y&&my<hits[i].y+hits[i].h)
            return hits[i].act;
    return -1;
}

/* ===== Draw ===== */
static void draw(FB *f) {
    int W=f->w, H=f->h;
    nhit=0;
    char buf[64];

    /* Layout constants */
    int HDR=40, FTR=40, CAT_H=30;
    int RPW = W*33/100;         /* right panel width */
    int LPW = W - RPW - 2;     /* left panel width */
    int BODY_Y = HDR;
    int BODY_H = H - HDR - FTR;

    /* Background */
    rect(f,0,0,W,H,C_BG_R,C_BG_G,C_BG_B);

    /* ── Header ── */
    rect(f,0,0,W,HDR,C_PNL_R,C_PNL_G,C_PNL_B);
    hline(f,0,HDR-1,W,C_BRD_R,C_BRD_G,C_BRD_B);
    text(f,10,12,"WAYANG POS",2,C_GOLD_R,C_GOLD_G,C_GOLD_B);
    text(f,W/3,16,"Warung Kopi Nusantara",1,C_DIM_R,C_DIM_G,C_DIM_B);

    time_t now=time(NULL); struct tm *ti=localtime(&now);
    char clk[8],dt[12];
    strftime(clk,sizeof(clk),"%H:%M",ti);
    strftime(dt,sizeof(dt),"%b %d",ti);
    text(f,W-tw(clk,2)-tw(dt,1)-25,10,clk,2,C_GOLD_R,C_GOLD_G,C_GOLD_B);
    text(f,W-tw(dt,1)-8,16,dt,1,C_DIM_R,C_DIM_G,C_DIM_B);

    /* ── Left: Category tabs at top ── */
    int cat_y = BODY_Y;
    rect(f,0,cat_y,LPW,CAT_H,C_PNL_R,C_PNL_G,C_PNL_B);
    hline(f,0,cat_y+CAT_H-1,LPW,C_BRD_R,C_BRD_G,C_BRD_B);
    int tabw=LPW/4;
    for(int i=0;i<4;i++){
        int tx=i*tabw;
        if(i==cur_cat){
            rect(f,tx+2,cat_y+2,tabw-4,CAT_H-4,C_SEL_R,C_SEL_G,C_SEL_B);
            hline(f,tx+2,cat_y+CAT_H-3,tabw-4,C_GOLD_R,C_GOLD_G,C_GOLD_B);
            text_center(f,tx+tabw/2,cat_y+8,cats[i],1,C_GOLD_R,C_GOLD_G,C_GOLD_B);
        } else {
            text_center(f,tx+tabw/2,cat_y+8,cats[i],1,C_DIM_R,C_DIM_G,C_DIM_B);
        }
        if(nhit<48){hits[nhit]=(Hit){tx,cat_y,tabw,CAT_H,100+i};nhit++;}
    }

    /* ── Left: Menu grid ── */
    int grid_y = cat_y + CAT_H + 4;
    int cols=3, rows=3, gap=4;
    int cw=(LPW - 12 - (cols-1)*gap)/cols;
    int ch=56; /* compact fixed height: name + price only, no empty space */

    /* Visible items based on category filter */
    int vis[MCNT], nvis=0;
    for(int i=0;i<MCNT;i++) if(cur_cat==0||menu[i].cat==cur_cat-1) vis[nvis++]=i;

    for(int v=0;v<nvis&&v<9;v++){
        int i=vis[v];
        int col=v%cols, row=v/cols;
        int cx=6+col*(cw+gap);
        int cy=grid_y+row*(ch+gap);

        /* Card bg */
        int sel=0;
        for(int j=0;j<ocnt;j++) if(order[j].idx==i){sel=order[j].qty;break;}

        rect(f,cx,cy,cw,ch, sel?C_SEL_R:C_PNL_R, sel?C_SEL_G:C_PNL_G, sel?C_SEL_B:C_PNL_B);

        /* Border */
        hline(f,cx,cy,cw,C_BRD_R,C_BRD_G,C_BRD_B);
        hline(f,cx,cy+ch-1,cw,C_BRD_R,C_BRD_G,C_BRD_B);
        vline(f,cx,cy,ch,C_BRD_R,C_BRD_G,C_BRD_B);
        vline(f,cx+cw-1,cy,ch,C_BRD_R,C_BRD_G,C_BRD_B);

        /* Number key hint */
        snprintf(buf,sizeof(buf),"%d",v+1);
        draw_char(f,cx+6,cy+4,buf[0],1,C_DIM_R,C_DIM_G,C_DIM_B);

        /* Name */
        text(f,cx+20,cy+4,menu[i].name,1,C_TXT_R,C_TXT_G,C_TXT_B);

        /* Price */
        fmt_rp(buf,sizeof(buf),menu[i].price);
        text(f,cx+20,cy+ch-20,buf,1,C_AMB_R,C_AMB_G,C_AMB_B);

        /* Qty badge */
        if(sel>0){
            snprintf(buf,sizeof(buf),"%d",sel);
            rect(f,cx+cw-22,cy+3,18,16,C_GOLD_R,C_GOLD_G,C_GOLD_B);
            draw_char(f,cx+cw-17,cy+3,buf[0],1,C_BG_R,C_BG_G,C_BG_B);
        }

        if(nhit<48){hits[nhit]=(Hit){cx,cy,cw,ch,i};nhit++;}
    }

    /* ── Right Panel: Order ── */
    int rx=LPW+2;
    rect(f,rx,BODY_Y,RPW,BODY_H,C_PNL_R,C_PNL_G,C_PNL_B);
    vline(f,rx,BODY_Y,BODY_H,C_BRD_R,C_BRD_G,C_BRD_B);

    /* Order header */
    snprintf(buf,sizeof(buf),"ORDER #%04d",onum);
    text(f,rx+8,BODY_Y+6,buf,1,C_GOLD_R,C_GOLD_G,C_GOLD_B);
    snprintf(buf,sizeof(buf),"%d items",order_count_items());
    text_right(f,W-8,BODY_Y+6,buf,1,C_DIM_R,C_DIM_G,C_DIM_B);

    int oy=BODY_Y+24;
    hline(f,rx+6,oy,RPW-12,C_BRD_R,C_BRD_G,C_BRD_B);
    oy+=6;

    /* Order line items — fill until totals area */
    int max_order_y = H - FTR - 170; /* reserve for subtotal+tax+total+btns+pay */
    for(int i=0;i<ocnt&&oy<max_order_y;i++){
        int idx=order[i].idx;
        snprintf(buf,sizeof(buf),"%dx %s",order[i].qty,menu[idx].name);
        text(f,rx+8,oy,buf,1,C_TXT_R,C_TXT_G,C_TXT_B);
        int sub=order[i].qty*menu[idx].price;
        fmt_rp(buf,sizeof(buf),sub);
        text_right(f,W-8,oy,buf,1,C_AMB_R,C_AMB_G,C_AMB_B);
        oy+=20;
    }

    /* ── Totals + Buttons (anchored from bottom, computed upward) ── */
    int total=order_total();
    int tax=total*11/100;
    int grand=total+tax;
    /* ── Bottom section: build from footer upward ──
     * Footer:   H-FTR to H  (40px)
     * PAY:      above footer
     * CASH/QRIS: above PAY
     * Totals:    above buttons
     */
    int ftr_top = H - FTR;

    /* PAY button - 20px above footer */
    int pay_h=28, pay_y=ftr_top-pay_h-20;
    rect(f,rx+8,pay_y,RPW-16,pay_h,C_AMB_R,C_AMB_G,C_AMB_B);
    fmt_rp(buf,sizeof(buf),grand);
    char pay[48]; snprintf(pay,sizeof(pay),"PAY %s",buf);
    text_center(f,rx+RPW/2,pay_y+6,pay,2,C_BG_R,C_BG_G,C_BG_B);
    if(nhit<48){hits[nhit]=(Hit){rx+8,pay_y,RPW-16,pay_h,202};nhit++;}

    /* CASH + QRIS - above PAY */
    int btn_h=22, btn_y=pay_y-btn_h-4;
    int bw=(RPW-24)/2;
    rect(f,rx+8,btn_y,bw,btn_h,C_GRN_R,C_GRN_G,C_GRN_B);
    text_center(f,rx+8+bw/2,btn_y+3,"CASH",1,255,255,255);
    if(nhit<48){hits[nhit]=(Hit){rx+8,btn_y,bw,btn_h,200};nhit++;}
    rect(f,rx+12+bw,btn_y,bw,btn_h,C_BLU_R,C_BLU_G,C_BLU_B);
    text_center(f,rx+12+bw+bw/2,btn_y+3,"QRIS",1,255,255,255);
    if(nhit<48){hits[nhit]=(Hit){rx+12+bw,btn_y,bw,btn_h,201};nhit++;}

    /* PAYMENT label */
    int lbl_y=btn_y-16;
    text(f,rx+8,lbl_y,"PAYMENT",1,C_DIM_R,C_DIM_G,C_DIM_B);

    /* Divider */
    hline(f,rx+6,lbl_y-4,RPW-12,C_BRD_R,C_BRD_G,C_BRD_B);

    /* TOTAL */
    int tot_y=lbl_y-4-26;
    fmt_rp(buf,sizeof(buf),grand);
    text(f,rx+8,tot_y,"TOTAL",2,C_GOLD_R,C_GOLD_G,C_GOLD_B);
    text_right(f,W-8,tot_y,buf,2,C_GOLD_R,C_GOLD_G,C_GOLD_B);

    /* Tax */
    int tax_y=tot_y-18;
    fmt_rp(buf,sizeof(buf),tax);
    text(f,rx+8,tax_y,"TAX 11%",1,C_DIM_R,C_DIM_G,C_DIM_B);
    text_right(f,W-8,tax_y,buf,1,C_TXT_R,C_TXT_G,C_TXT_B);

    /* Subtotal */
    int sub_y=tax_y-18;
    fmt_rp(buf,sizeof(buf),total);
    text(f,rx+8,sub_y,"SUBTOTAL",1,C_DIM_R,C_DIM_G,C_DIM_B);
    text_right(f,W-8,sub_y,buf,1,C_TXT_R,C_TXT_G,C_TXT_B);

    /* Divider above subtotal */
    hline(f,rx+6,sub_y-6,RPW-12,C_BRD_R,C_BRD_G,C_BRD_B);

    /* ── Footer ── */
    rect(f,0,H-FTR,W,FTR,C_PNL_R,C_PNL_G,C_PNL_B);
    hline(f,0,H-FTR,W,C_BRD_R,C_BRD_G,C_BRD_B);
    text(f,8,H-FTR+3,"wayang:pos",1,C_GOLD_R,C_GOLD_G,C_GOLD_B);
    snprintf(buf,sizeof(buf),"%dx%d",W,H);
    text(f,140,H-FTR+3,buf,1,C_DIM_R,C_DIM_G,C_DIM_B);

    FILE *up=fopen("/proc/uptime","r");
    if(up){float s;if(fscanf(up,"%f",&s)==1){int m=(int)s/60,h=m/60;snprintf(buf,sizeof(buf),"Up: %dh%dm",h,m%60);text(f,W/2-40,H-FTR+3,buf,1,C_DIM_R,C_DIM_G,C_DIM_B);}fclose(up);}

    FILE *mi=fopen("/proc/meminfo","r");
    if(mi){long tot=0,avl=0;char l[128];while(fgets(l,128,mi)){if(!strncmp(l,"MemTotal:",9))sscanf(l+9,"%ld",&tot);if(!strncmp(l,"MemAvailable:",13))sscanf(l+13,"%ld",&avl);}fclose(mi);
    snprintf(buf,sizeof(buf),"RAM: %ld/%ldMB",(tot-avl)/1024,tot/1024);text_right(f,W-8,H-FTR+3,buf,1,C_DIM_R,C_DIM_G,C_DIM_B);}

    /* Keyboard hints in footer */
    text(f,8,H-FTR+14,"[1-9] Add  [0] Clear  [Enter] Pay  [Tab] Cat  [Q] Menu  [Esc] Exit",1,C_DIM_R,C_DIM_G,C_DIM_B);
}

/* ===== Cursor (pixel-art arrow, amber/gold) ===== */
static const unsigned char cursor_data[16] = {
    0x80,  /* X....... */
    0xC0,  /* XX...... */
    0xE0,  /* XXX..... */
    0xF0,  /* XXXX.... */
    0xF8,  /* XXXXX... */
    0xFC,  /* XXXXXX.. */
    0xFE,  /* XXXXXXX. */
    0xFF,  /* XXXXXXXX */
    0xFC,  /* XXXXXX.. */
    0xFC,  /* XXXXXX.. */
    0xCC,  /* XX..XX.. */
    0x86,  /* X....XX. */
    0x06,  /* .....XX. */
    0x03,  /* ......XX */
    0x03,  /* ......XX */
    0x00,  /* ........ */
};
static const unsigned char cursor_outline[16] = {
    0xC0,  /* XX...... */
    0xE0,  /* XXX..... */
    0xF0,  /* XXXX.... */
    0xF8,  /* XXXXX... */
    0xFC,  /* XXXXXX.. */
    0xFE,  /* XXXXXXX. */
    0xFF,  /* XXXXXXXX */
    0xFF,  /* XXXXXXXX (same row, outline=fill here) */
    0xFE,  /* XXXXXXX. */
    0xFE,  /* XXXXXXX. */
    0xEE,  /* XXX.XXX. */
    0xCF,  /* XX..XXXX */
    0x8F,  /* X...XXXX */
    0x07,  /* .....XXX */
    0x07,  /* .....XXX */
    0x03,  /* ......XX */
};

static void draw_cursor(FB *f, int cx, int cy) {
    /* Draw 2x scaled pixel cursor */
    for(int row=0;row<16;row++){
        unsigned char outline=cursor_outline[row];
        unsigned char fill=cursor_data[row];
        for(int col=0;col<8;col++){
            int sx=cx+col*2, sy=cy+row*2;
            if(outline&(0x80>>col)){
                if(fill&(0x80>>col)){
                    /* Fill: bright gold */
                    rect(f,sx,sy,2,2,212,175,55);
                } else {
                    /* Outline: dark border */
                    rect(f,sx,sy,2,2,40,30,10);
                }
            }
        }
    }
}

/* ===== Input ===== */
static int open_inputs(int fds[], int max) {
    int n=0;
    DIR *d=opendir("/dev/input");
    if(d){
        struct dirent *e;
        while((e=readdir(d))&&n<max){
            if(strncmp(e->d_name,"event",5)==0||strcmp(e->d_name,"mice")==0){
                char p[64]; snprintf(p,sizeof(p),"/dev/input/%s",e->d_name);
                int fd=open(p,O_RDONLY|O_NONBLOCK);
                if(fd>=0){fds[n++]=fd;printf("Input: %s (fd=%d)\n",p,fd);}
            }
        }
        closedir(d);
    }
    return n;
}

int main(void) {
    const char *dev=getenv("FBDEV");
    if(!dev) dev="/dev/fb0";
    int fd=open(dev,O_RDWR);
    if(fd<0){perror("open fb");return 1;}

    struct fb_var_screeninfo vi;
    struct fb_fix_screeninfo fi;
    ioctl(fd,FBIOGET_VSCREENINFO,&vi);
    ioctl(fd,FBIOGET_FSCREENINFO,&fi);

    FB fb={.w=vi.xres,.h=vi.yres,.bpp=vi.bits_per_pixel/8,.stride=fi.line_length,.size=fi.line_length*vi.yres};
    unsigned char *fbmem=mmap(0,fb.size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
    if(fbmem==MAP_FAILED){perror("mmap");return 1;}

    unsigned char *back=malloc(fb.size);
    if(!back){perror("malloc");return 1;}
    fb.mem=back;

    /* Suppress console text rendering (KD_GRAPHICS) */
    int tty_fd=-1;
    for(int i=0;i<4;i++){
        char path[16]; snprintf(path,sizeof(path),"/dev/tty%d",i);
        tty_fd=open(path,O_RDWR);
        if(tty_fd>=0) break;
    }
    if(tty_fd<0) tty_fd=open("/dev/console",O_RDWR);
    if(tty_fd>=0){
        ioctl(tty_fd,KDSETMODE,KD_GRAPHICS);
        fprintf(stderr,"KD_GRAPHICS set on tty fd=%d\n",tty_fd);
    }

    /* Try to open input devices directly by name */
    int inp[12]; int ninp=0;
    for(int i=0;i<8;i++){
        char path[32];
        snprintf(path,sizeof(path),"/dev/input/event%d",i);
        int ifd=open(path,O_RDONLY|O_NONBLOCK);
        if(ifd>=0){
            inp[ninp++]=ifd;
            fprintf(stderr,"Input: %s fd=%d\n",path,ifd);
        }
    }
    /* Also try mice */
    {
        int mfd=open("/dev/input/mice",O_RDONLY|O_NONBLOCK);
        if(mfd>=0){inp[ninp++]=mfd;fprintf(stderr,"Input: /dev/input/mice fd=%d\n",mfd);}
    }
    fprintf(stderr,"Total inputs: %d\n",ninp);

    int mx=fb.w/2, my=fb.h/2;
    int redraw=1, last_min=-1;

    fprintf(stderr,"WayangOS POS v3: %dx%d, %d bpp, %d inputs, tty=%d\n",fb.w,fb.h,fb.bpp*8,ninp,tty_fd);

welcome:
    /* ===== WELCOME SCREEN ===== */
    {
        rect(&fb,0,0,fb.w,fb.h,15,12,8);
        rect(&fb,0,0,fb.w,3,212,175,55);
        int cy=fb.h/2;
        text_center(&fb,fb.w/2,cy-90,"W A Y A N G O S",3,212,175,55);
        int sepw=300;
        rect(&fb,fb.w/2-sepw/2,cy-45,sepw,2,120,100,40);
        text_center(&fb,fb.w/2,cy-25,"Point of Sale System",1,180,150,60);
        text_center(&fb,fb.w/2,cy-5,"Warung Kopi Nusantara",1,140,120,50);
        text_center(&fb,fb.w/2,cy+25,"v0.6.0",1,100,85,35);
        rect(&fb,fb.w/2-sepw/2,cy+50,sepw,2,120,100,40);
        rect(&fb,fb.w/2-140,cy+70,280,36,35,28,15);
        rect(&fb,fb.w/2-139,cy+71,278,34,45,35,18);
        text_center(&fb,fb.w/2,cy+80,"Press ENTER to start",1,212,175,55);
        text_center(&fb,fb.w/2,fb.h-30,"Powered by WayangOS - Ultra Minimal Linux",1,80,65,30);
        text_center(&fb,fb.w/2,fb.h-50,"[ESC] Exit to shell",1,60,50,25);
        rect(&fb,0,fb.h-3,fb.w,3,212,175,55);
        memcpy(fbmem,back,fb.size);

        int waiting=1;
        while(waiting){
            fd_set rfds; FD_ZERO(&rfds);
            int maxfd=0;
            for(int i=0;i<ninp;i++){FD_SET(inp[i],&rfds);if(inp[i]>maxfd)maxfd=inp[i];}
            struct timeval tv={1,0};
            int r=select(maxfd+1,&rfds,NULL,NULL,&tv);
            if(r<=0) continue;
            for(int i=0;i<ninp;i++){
                if(!FD_ISSET(inp[i],&rfds)) continue;
                struct input_event ev;
                while(read(inp[i],&ev,sizeof(ev))==sizeof(ev)){
                    if(ev.type==EV_KEY&&ev.value==1){
                        if(ev.code==KEY_ENTER||ev.code==KEY_KPENTER||ev.code==KEY_SPACE)
                            waiting=0;
                        else if(ev.code==KEY_ESC) goto done;
                    }
                }
            }
        }
    }

    /* Reset order for fresh session */
    order_clear();
    redraw=1; last_min=-1;
    int cursor_dirty=0;

    /* Keep a clean copy of the scene (without cursor) for fast cursor updates */
    unsigned char *clean=malloc(fb.size);
    if(!clean){perror("malloc clean");return 1;}
    int omx=-1,omy=-1; /* old cursor position */
    #define CUR_W 16
    #define CUR_H 32

    while(1){
        if(redraw){
            draw(&fb);
            memcpy(clean,back,fb.size); /* save clean scene */
            draw_cursor(&fb,mx,my);
            memcpy(fbmem,back,fb.size);
            omx=mx; omy=my;
            redraw=0; cursor_dirty=0;
        } else if(cursor_dirty){
            /* Fast path: restore only old+new cursor rectangles from clean, then draw new cursor */
            /* Restore old cursor area directly to fbmem */
            if(omx>=0){
                for(int row=0;row<CUR_H&&omy+row<fb.h;row++){
                    int y=omy+row;
                    long off=y*fb.stride+omx*fb.bpp;
                    int w=CUR_W*fb.bpp;
                    if(omx+CUR_W>fb.w) w=(fb.w-omx)*fb.bpp;
                    if(w>0) memcpy(fbmem+off,clean+off,w);
                }
            }
            /* Draw cursor at new position on backbuffer and copy to fbmem */
            /* First restore new area from clean */
            for(int row=0;row<CUR_H&&my+row<fb.h;row++){
                int y=my+row;
                long off=y*fb.stride+mx*fb.bpp;
                int w=CUR_W*fb.bpp;
                if(mx+CUR_W>fb.w) w=(fb.w-mx)*fb.bpp;
                if(w>0){memcpy(back+off,clean+off,w);memcpy(fbmem+off,clean+off,w);}
            }
            draw_cursor(&fb,mx,my);
            /* Copy only cursor area to fbmem */
            for(int row=0;row<CUR_H&&my+row<fb.h;row++){
                int y=my+row;
                long off=y*fb.stride+mx*fb.bpp;
                int w=CUR_W*fb.bpp;
                if(mx+CUR_W>fb.w) w=(fb.w-mx)*fb.bpp;
                if(w>0) memcpy(fbmem+off,back+off,w);
            }
            omx=mx; omy=my;
            cursor_dirty=0;
        }

        fd_set rfds; FD_ZERO(&rfds);
        int maxfd=0;
        for(int i=0;i<ninp;i++){FD_SET(inp[i],&rfds);if(inp[i]>maxfd)maxfd=inp[i];}

        struct timeval tv={5,0};
        int r=select(maxfd+1,&rfds,NULL,NULL,&tv);

        if(r==0){
            time_t now=time(NULL);struct tm *t=localtime(&now);
            if(t->tm_min!=last_min){last_min=t->tm_min;redraw=1;}
            continue;
        }

        /* Read /dev/input/event* */
        for(int i=0;i<ninp;i++){
            if(!FD_ISSET(inp[i],&rfds)) continue;
            struct input_event ev;
            while(read(inp[i],&ev,sizeof(ev))==sizeof(ev)){
                if(ev.type==EV_KEY&&ev.value==1){
                    if(ev.code>=KEY_1&&ev.code<=KEY_9){order_add(ev.code-KEY_1);redraw=1;}
                    else if(ev.code==KEY_0||ev.code==KEY_BACKSPACE||ev.code==KEY_DELETE){order_clear();redraw=1;}
                    else if(ev.code==KEY_ENTER||ev.code==KEY_SPACE||ev.code==KEY_KPENTER){order_clear();redraw=1;}
                    else if(ev.code==KEY_TAB){cur_cat=(cur_cat+1)%4;redraw=1;}
                    else if(ev.code==KEY_Q) goto welcome;
                    else if(ev.code==KEY_ESC) goto done;
                    else if(ev.code==BTN_LEFT||ev.code==BTN_TOUCH){
                        int a=hit_test(mx,my);
                        if(a>=0&&a<MCNT){order_add(a);redraw=1;}
                        else if(a>=100&&a<=103){cur_cat=a-100;redraw=1;}
                        else if(a>=200){order_clear();redraw=1;}
                    }
                }
                else if(ev.type==EV_REL){
                    if(ev.code==REL_X)mx+=ev.value;
                    if(ev.code==REL_Y)my+=ev.value;
                    if(mx<0)mx=0;if(my<0)my=0;
                    if(mx>=fb.w)mx=fb.w-1;if(my>=fb.h)my=fb.h-1;
                    cursor_dirty=1;
                }
                else if(ev.type==EV_ABS){
                    if(ev.code==ABS_X||ev.code==ABS_MT_POSITION_X)mx=ev.value*fb.w/32768;
                    if(ev.code==ABS_Y||ev.code==ABS_MT_POSITION_Y)my=ev.value*fb.h/32768;
                    cursor_dirty=1;
                }
            }
        }
    }

done:
    if(tty_fd>=0){ioctl(tty_fd,KDSETMODE,KD_TEXT);close(tty_fd);}
    for(int i=0;i<ninp;i++)close(inp[i]);
    free(clean); free(back); munmap(fbmem,fb.size); close(fd);
    return 0;
}
