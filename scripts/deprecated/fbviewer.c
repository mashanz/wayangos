/*
 * WayangOS Framebuffer Image Viewer
 * Writes directly to /dev/fb0 — zero dependencies, no SDL2
 * Supports: JPEG, PNG, BMP, GIF via stb_image.h
 */

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/fb.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("WayangOS Framebuffer Viewer v1.0\n");
        printf("Usage: %s <image>\n", argv[0]);
        printf("Writes image directly to /dev/fb0\n");
        printf("Supports: JPEG, PNG, BMP, GIF, TGA, PSD, HDR\n");
        return 0;
    }

    /* Open framebuffer */
    const char *fbdev = getenv("FBDEV");
    if (!fbdev) fbdev = "/dev/fb0";
    
    int fb = open(fbdev, O_RDWR);
    if (fb < 0) {
        perror("Cannot open framebuffer");
        return 1;
    }

    /* Get screen info */
    struct fb_var_screeninfo vinfo;
    struct fb_fix_screeninfo finfo;
    
    if (ioctl(fb, FBIOGET_VSCREENINFO, &vinfo) < 0) {
        perror("Cannot get variable screen info");
        close(fb);
        return 1;
    }
    if (ioctl(fb, FBIOGET_FSCREENINFO, &finfo) < 0) {
        perror("Cannot get fixed screen info");
        close(fb);
        return 1;
    }

    int scr_w = vinfo.xres;
    int scr_h = vinfo.yres;
    int bpp = vinfo.bits_per_pixel / 8;
    int line_len = finfo.line_length;
    long screensize = line_len * scr_h;

    printf("Screen: %dx%d, %d bpp, line_length=%d\n", scr_w, scr_h, bpp * 8, line_len);

    /* Map framebuffer to memory */
    unsigned char *fbmem = mmap(0, screensize, PROT_READ | PROT_WRITE, MAP_SHARED, fb, 0);
    if (fbmem == MAP_FAILED) {
        perror("Cannot mmap framebuffer");
        close(fb);
        return 1;
    }

    /* Load image */
    int img_w, img_h, channels;
    unsigned char *pixels = stbi_load(argv[1], &img_w, &img_h, &channels, 3); /* Force RGB */
    if (!pixels) {
        fprintf(stderr, "Failed to load: %s (%s)\n", argv[1], stbi_failure_reason());
        munmap(fbmem, screensize);
        close(fb);
        return 1;
    }

    printf("Image: %dx%d, %d channels\n", img_w, img_h, channels);

    /* Calculate fit-to-screen with aspect ratio */
    float scale_x = (float)scr_w / img_w;
    float scale_y = (float)scr_h / img_h;
    float scale = (scale_x < scale_y) ? scale_x : scale_y;
    
    int dst_w = (int)(img_w * scale);
    int dst_h = (int)(img_h * scale);
    int off_x = (scr_w - dst_w) / 2;
    int off_y = (scr_h - dst_h) / 2;

    /* Clear screen to dark */
    memset(fbmem, 0x0A, screensize);

    /* Draw image with nearest-neighbor scaling */
    for (int y = 0; y < dst_h; y++) {
        int src_y = (int)(y * img_h / dst_h);
        if (src_y >= img_h) src_y = img_h - 1;
        
        for (int x = 0; x < dst_w; x++) {
            int src_x = (int)(x * img_w / dst_w);
            if (src_x >= img_w) src_x = img_w - 1;

            unsigned char *src_pixel = &pixels[(src_y * img_w + src_x) * 3];
            int fb_x = off_x + x;
            int fb_y = off_y + y;
            
            if (fb_x >= 0 && fb_x < scr_w && fb_y >= 0 && fb_y < scr_h) {
                long offset = fb_y * line_len + fb_x * bpp;
                
                if (bpp == 4) {
                    /* BGRA32 */
                    fbmem[offset + 0] = src_pixel[2]; /* B */
                    fbmem[offset + 1] = src_pixel[1]; /* G */
                    fbmem[offset + 2] = src_pixel[0]; /* R */
                    fbmem[offset + 3] = 0xFF;         /* A */
                } else if (bpp == 3) {
                    /* BGR24 */
                    fbmem[offset + 0] = src_pixel[2];
                    fbmem[offset + 1] = src_pixel[1];
                    fbmem[offset + 2] = src_pixel[0];
                } else if (bpp == 2) {
                    /* RGB565 */
                    unsigned short color = 
                        ((src_pixel[0] >> 3) << 11) |
                        ((src_pixel[1] >> 2) << 5) |
                        (src_pixel[2] >> 3);
                    *(unsigned short *)(fbmem + offset) = color;
                }
            }
        }
    }

    printf("Rendered %dx%d at offset (%d,%d)\n", dst_w, dst_h, off_x, off_y);

    stbi_image_free(pixels);
    
    /* Keep displayed until killed */
    printf("Displaying. Press Ctrl+C to exit.\n");
    while (1) sleep(60);

    munmap(fbmem, screensize);
    close(fb);
    return 0;
}
