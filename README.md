# WayangOS POS — Touchscreen Point of Sale System

Production-grade POS for Indonesian UMKM (warung, kafe, toko), running on minimal Linux (WayangOS) with direct framebuffer rendering. No X11, no Wayland — just raw pixels on `/dev/fb0`.

## Features

- **Touchscreen-ready** — full touch UI with tap navigation, no physical keyboard needed
- **Virtual keyboard** — on-screen QWERTY for text input (login, menu names, prices)
- **SQLite persistence** — all data stored locally in `/data/pos.db`
- **Multi-user auth** — PIN-based login with admin/cashier roles
- **Menu CRUD** — add, edit, delete menu items with categories and prices
- **Category management** — organize menu by category with touch selector
- **Order history** — complete transaction log with date/time stamps
- **Pagination** — smooth scrolling through long lists with nav buttons
- **18MB bootable ISO** — boots in seconds, runs entirely from RAM
- **No internet required** — fully offline, your data stays yours

## Hardware Target

- **SBC:** Orange Pi Zero 2W (~$15)
- **Display:** 7" touchscreen LCD (1024×600)
- **Storage:** MicroSD card (any size)
- **Total cost:** Under $50 for a complete POS terminal

Also runs on any x86_64 machine via QEMU or bare metal.

## Screenshots

<!-- TODO: Add screenshots of login, menu, order flow -->

## Building

### Prerequisites (Ubuntu/Debian)

```bash
sudo apt install gcc make libsqlite3-dev
```

### Build the POS binary

```bash
# You need sqlite3.c amalgamation in the build directory
gcc -static -O2 -o fbpos-v3 fbpos-v3.c sqlite3.c -lm -lpthread -DSQLITE_INTEGRATION
```

### Build bootable ISO

```bash
# Requires: kernel image, base initramfs, grub-mkrescue
./build-final.sh
```

See `build-final.sh` for the full ISO build process.

## Project Structure

```
fbpos-v3.c       — Main POS application (single-file C, ~5000 lines)
font8x16.h       — Embedded 8×16 bitmap font
input-test.c     — Input device testing utility
kiosk-init.sh    — Init script for kiosk boot
build-final.sh   — Full ISO build script
```

## Architecture

- **Rendering:** Direct framebuffer writes to `/dev/fb0` (32-bit BGRA)
- **Input:** Linux evdev (`/dev/input/eventN`) for touch + mouse
- **Database:** SQLite3 compiled-in (amalgamation build)
- **Font:** Embedded 8×16 bitmap font, no external dependencies
- **Boot:** Custom BusyBox initramfs → dropbear SSH → POS app

## Default Login

- **Admin:** username `admin`, PIN `1234`

## License

MIT
