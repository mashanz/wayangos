#!/bin/bash
set -e
export PATH=/home/desktop_pc/.cargo/bin:/usr/bin:/usr/sbin:/sbin:$PATH
cd /home/desktop_pc/wayangos-build

# Extract headless initramfs, replace wx, repack
INITDIR=$(mktemp -d)
cd "$INITDIR"
zcat /home/desktop_pc/wayangos-build/initramfs-headless-wx.img | cpio -idm 2>/dev/null

# Replace wx with fixed version
cp /home/desktop_pc/wayangos-explorer/target/x86_64-unknown-linux-musl/release/wx usr/bin/wx
chmod +x usr/bin/wx

# Also add TERM=linux to shell profile so wx works
mkdir -p etc/profile.d
echo 'export TERM=linux' > etc/profile.d/term.sh

# Repack
find . | cpio -H newc -o 2>/dev/null | gzip > /home/desktop_pc/wayangos-build/initramfs-minimal-wx2.img
ls -lh /home/desktop_pc/wayangos-build/initramfs-minimal-wx2.img
echo "=== INITRAMFS REPACKED ==="

# Build ISO using tiny kernel
cd /home/desktop_pc/wayangos-build
ISODIR=$(mktemp -d)
mkdir -p "$ISODIR/boot/grub"

ls -lh linux-6.19.7/arch/x86/boot/bzImage
cp linux-6.19.7/arch/x86/boot/bzImage "$ISODIR/boot/vmlinuz"
cp initramfs-minimal-wx2.img "$ISODIR/boot/initramfs.img"

printf 'set timeout=3\nset default=0\nmenuentry "WayangOS Minimal (64MB)" {\n    linux /boot/vmlinuz loglevel=3 vt.global_cursor_default=0 quiet\n    initrd /boot/initramfs.img\n}\n' > "$ISODIR/boot/grub/grub.cfg"

grub-mkrescue -o wayangos-minimal-wx.iso "$ISODIR" 2>&1 | tail -5
ls -lh wayangos-minimal-wx.iso
echo "=== ISO BUILT ==="

# Copy to workspace
mkdir -p "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/"
cp wayangos-minimal-wx.iso "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/"
rm -rf "$ISODIR" "$INITDIR"

# Kill old QEMU and restart with new ISO
pkill -9 qemu 2>/dev/null || true
tmux kill-session -t qemu 2>/dev/null || true
sleep 2

DISPLAY=:0 tmux new-session -d -s qemu \
  "qemu-system-x86_64 -m 64M \
   -cdrom /home/desktop_pc/wayangos-build/wayangos-minimal-wx.iso \
   -boot d \
   -net nic -net user,hostfwd=tcp::2223-:22 \
   -usb -device usb-kbd -device usb-mouse \
   -vga std -display sdl \
   2>/tmp/qemu-wx2.log; sleep 999"

sleep 3
pgrep -a qemu && echo "=== QEMU RUNNING WITH FIXED WX ===" || echo "=== QEMU FAILED TO START ==="
