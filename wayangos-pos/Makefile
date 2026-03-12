CC = gcc
CFLAGS = -Os -Wall
LDFLAGS_STATIC = -static -lSDL2 -ldrm -lm -lpthread -ldl -lrt
LDFLAGS_DYNAMIC = $(shell sdl2-config --libs 2>/dev/null || echo "-lSDL2")
SDL_CFLAGS = $(shell sdl2-config --cflags 2>/dev/null || echo "-I/usr/include/SDL2")

.PHONY: all static clean

all: wayang-pos

# Dynamic build (for testing on desktop)
wayang-pos: pos.c
	$(CC) $(CFLAGS) $(SDL_CFLAGS) -o $@ $< $(LDFLAGS_DYNAMIC)

# Static build (for WayangOS deployment)
static: pos.c
	$(CC) $(CFLAGS) -static -o wayang-pos $< $(LDFLAGS_STATIC)
	strip wayang-pos

clean:
	rm -f wayang-pos

# Generate screenshot (headless)
screenshot: wayang-pos
	SDL_VIDEODRIVER=dummy ./wayang-pos
	@echo "Screenshot saved to /tmp/wayangos-pos.bmp"
