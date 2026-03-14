#!/bin/bash
set -e

cd /home/desktop_pc/wayangos-build
echo "=== Working directory ==="
ls -lh *.c 2>/dev/null | head -5
ls -lh *.img 2>/dev/null | head -5
ls -lh vmlinuz* 2>/dev/null | head -5

# Copy source file
cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbpos-v3.c" .
echo "=== Copied source ==="

# Rebuild POS binary
gcc -static -O2 -o fbpos-v3 fbpos-v3.c sqlite3.c -lm -lpthread -DSQLITE_INTEGRATION 2>&1 | grep -v "warning.*dlopen" || true
echo "=== Binary built ==="
ls -lh fbpos-v3

# Rebuild initramfs
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c /home/desktop_pc/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null

cp /home/desktop_pc/wayangos-build/fbpos-v3 usr/bin/wayang-pos
chmod +x usr/bin/wayang-pos

cat > etc/init.d/viewer-demo << 'INITSCRIPT'
#!/bin/sh
sleep 1
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/input
mdev -s 2>/dev/null || true
[ -e /dev/fb0 ] || exit 1
chmod 666 /dev/fb0
chmod 666 /dev/input/event* /dev/input/mice 2>/dev/null
echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null
echo 0 > /proc/sys/kernel/printk 2>/dev/null
dd if=/dev/zero of=/dev/fb0 bs=4096 count=1000 2>/dev/null
ifconfig eth0 up 2>/dev/null
udhcpc -i eth0 -q 2>/dev/null &
mkdir -p /etc/dropbear /root/.ssh
printf 'root::0:0:root:/root:/bin/sh\n' > /etc/passwd
printf 'root:x:0:\n' > /etc/group
dropbear -R -B -p 22 2>/dev/null &
mkdir -p /data
/usr/bin/wayang-pos &
INITSCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > /home/desktop_pc/wayangos-build/initramfs-uefi.img
cd /home/desktop_pc/wayangos-build
rm -rf "$WORK"
echo "=== Initramfs size: $(stat -c%s initramfs-uefi.img) bytes ==="

# Build hybrid UEFI+BIOS ISO
ISODIR=$(mktemp -d)
mkdir -p "$ISODIR/boot/grub"
cp /home/desktop_pc/wayangos-build/vmlinuz-gui-with-input "$ISODIR/boot/vmlinuz"
cp /home/desktop_pc/wayangos-build/initramfs-uefi.img "$ISODIR/boot/initramfs.img"

cat > "$ISODIR/boot/grub/grub.cfg" << 'GRUBCFG'
set timeout=3
set default=0
menuentry "WayangPOS" {
    linux /boot/vmlinuz loglevel=1 vt.global_cursor_default=0 video=1024x600 quiet
    initrd /boot/initramfs.img
}
GRUBCFG

echo "=== Building ISO with grub-mkrescue ==="
grub-mkrescue -o /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso "$ISODIR" 2>&1
rm -rf "$ISODIR"

echo "=== ISO built ==="
ls -lh /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso

# Verify UEFI support
echo "=== Checking for EFI in ISO ==="
which 7z >/dev/null 2>&1 && 7z l /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso 2>/dev/null | grep -i efi | head -10 || true
which isoinfo >/dev/null 2>&1 && isoinfo -d -i /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso 2>/dev/null | head -20 || true

# Alternative: check with file command
file /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso

# Copy to Windows
cp /home/desktop_pc/wayangos-build/wayangos-pos-uefi.iso "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/wayangos-pos-uefi.iso"
echo "=== Copied to Windows workspace ==="

# Upload to GitHub
echo "=== Uploading to GitHub ==="
cd /home/desktop_pc/wayangos-build
gh release upload v3.0.0 wayangos-pos-uefi.iso --repo mashanz/wayangos-pos --clobber 2>&1 || echo "GitHub upload failed - may need auth"

echo "=== DONE ==="
