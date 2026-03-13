#!/bin/bash
set -e
cd ~/wayangos-build

killall -9 qemu-system-x86_64 2>/dev/null || true
sleep 1

cp "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/fbpos-v3.c" .
echo "=== Building POS ==="
# Get SQLite if needed
if [ ! -f sqlite3.c ]; then
    echo "Downloading SQLite..."
    wget -q https://www.sqlite.org/2024/sqlite-amalgamation-3450000.zip
    unzip -qo sqlite-amalgamation-3450000.zip
    cp sqlite-amalgamation-3450000/sqlite3.* .
fi
gcc -static -O2 -o fbpos-v3 fbpos-v3.c sqlite3.c -lm -lpthread -DSQLITE_INTEGRATION 2>&1 | grep -v "warning.*dlopen"
ls -lh fbpos-v3

echo "=== Building ISO ==="
WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v3 usr/bin/wayang-pos
chmod +x usr/bin/wayang-pos

cat > etc/init.d/viewer-demo <<'SCRIPT'
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

# Network setup
ifconfig eth0 up 2>/dev/null
udhcpc -i eth0 -s /usr/share/udhcpc/default.script -q 2>/dev/null &

# Start SSH (dropbear) — no password auth, allow root
mkdir -p /etc/dropbear /root/.ssh
echo "root::0:0:root:/root:/bin/sh" > /etc/passwd
echo "root:x:0:" > /etc/group
dropbear -R -B -p 22 2>/dev/null &

# Create /data for SQLite
mkdir -p /data

/usr/bin/wayang-pos &
SCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-final2.img
cd ~/wayangos-build
rm -rf "$WORK"
echo "Initramfs: $(ls -lh initramfs-final2.img | awk '{print $5}')"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-final2.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" <<'EOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz loglevel=1 vt.global_cursor_default=0 video=1024x600 quiet
    initrd /boot/initramfs.img
}
EOF
grub-mkrescue -o wayangos-final2.iso "$ISO" 2>/dev/null
rm -rf "$ISO"
echo "ISO: $(ls -lh wayangos-final2.iso | awk '{print $5}')"

echo "=== Booting ==="
setsid qemu-system-x86_64 \
    -cdrom wayangos-final2.iso \
    -m 256M \
    -vga std \
    -display gtk \
    -nic user,hostfwd=tcp::2222-:22 \
    -monitor unix:/tmp/qemu-f2-mon,server,nowait \
    < /dev/null > /dev/null 2>&1 &

sleep 20

# Send keys
printf 'sendkey 1\n' | socat - UNIX-CONNECT:/tmp/qemu-f2-mon; sleep 0.5
printf 'sendkey 2\n' | socat - UNIX-CONNECT:/tmp/qemu-f2-mon; sleep 0.5
printf 'sendkey 3\n' | socat - UNIX-CONNECT:/tmp/qemu-f2-mon; sleep 2

printf 'screendump /tmp/final2.ppm\n' | socat - UNIX-CONNECT:/tmp/qemu-f2-mon
sleep 2
convert /tmp/final2.ppm /tmp/final2.jpg
cp /tmp/final2.jpg "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/final2.jpg"
echo "DONE"
