/* Minimal input device test - prints to console */
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <sys/select.h>
#include <linux/input.h>

int main(void) {
    printf("\n=== INPUT DEVICE TEST ===\n");
    
    /* List /dev/input */
    DIR *d = opendir("/dev/input");
    if (!d) {
        printf("ERROR: Cannot open /dev/input\n");
        /* Try to list /dev */
        printf("\n/dev contents:\n");
        DIR *dev = opendir("/dev");
        if (dev) {
            struct dirent *e;
            while ((e = readdir(dev))) printf("  %s\n", e->d_name);
            closedir(dev);
        }
    } else {
        printf("/dev/input contents:\n");
        struct dirent *e;
        while ((e = readdir(d))) printf("  %s\n", e->d_name);
        closedir(d);
    }
    
    /* Try to open event devices */
    int fds[8], nfds = 0;
    for (int i = 0; i < 8; i++) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/input/event%d", i);
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd >= 0) {
            printf("OPENED: %s (fd=%d)\n", path, fd);
            fds[nfds++] = fd;
        } else {
            printf("FAILED: %s\n", path);
        }
    }
    
    printf("\nTotal devices opened: %d\n", nfds);
    
    if (nfds == 0) {
        printf("\nNo input devices! Checking /proc/bus/input/devices:\n");
        FILE *f = fopen("/proc/bus/input/devices", "r");
        if (f) {
            char line[256];
            while (fgets(line, sizeof(line), f)) printf("%s", line);
            fclose(f);
        } else {
            printf("Cannot open /proc/bus/input/devices\n");
        }
        printf("\nWaiting 60s then exit...\n");
        sleep(60);
        return 1;
    }
    
    printf("\nWaiting for keyboard events... press keys!\n");
    printf("(Will print key codes as received)\n\n");
    
    for (int loop = 0; loop < 300; loop++) { /* 30 seconds */
        fd_set rfds;
        FD_ZERO(&rfds);
        int maxfd = 0;
        for (int i = 0; i < nfds; i++) {
            FD_SET(fds[i], &rfds);
            if (fds[i] > maxfd) maxfd = fds[i];
        }
        struct timeval tv = {0, 100000}; /* 100ms */
        int r = select(maxfd + 1, &rfds, NULL, NULL, &tv);
        if (r > 0) {
            for (int i = 0; i < nfds; i++) {
                if (!FD_ISSET(fds[i], &rfds)) continue;
                struct input_event ev;
                while (read(fds[i], &ev, sizeof(ev)) == sizeof(ev)) {
                    if (ev.type == EV_KEY) {
                        printf("KEY: code=%d value=%d (%s)\n", 
                               ev.code, ev.value,
                               ev.value == 1 ? "PRESS" : ev.value == 0 ? "RELEASE" : "REPEAT");
                    }
                }
            }
        }
    }
    
    for (int i = 0; i < nfds; i++) close(fds[i]);
    return 0;
}
