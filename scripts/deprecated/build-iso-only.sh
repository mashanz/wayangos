#!/bin/bash
set -e
cd ~/wayangos-build

WORK=$(mktemp -d)
cd "$WORK"
gunzip -c ~/wayangos-build/initramfs-viewer-v3.img | cpio -id 2>/dev/null
cp ~/wayangos-build/fbpos-v3 usr/bin/wayang-pos
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
udhcpc -i eth0 -s /usr/share/udhcpc/default.script -q 2>/dev/null &
mkdir -p /etc/dropbear /root/.ssh
echo "root::0:0:root:/root:/bin/sh" > /etc/passwd
echo "root:x:0:" > /etc/group
dropbear -R -B -p 22 2>/dev/null &
mkdir -p /data
/usr/bin/wayang-pos &
INITSCRIPT
chmod +x etc/init.d/viewer-demo

find . -print0 | cpio -0 -o -H newc | gzip > ~/wayangos-build/initramfs-pos.img
cd ~/wayangos-build
rm -rf "$WORK"

ISO=$(mktemp -d)
mkdir -p "$ISO/boot/grub"
cp vmlinuz-gui-with-input "$ISO/boot/vmlinuz"
cp initramfs-pos.img "$ISO/boot/initramfs.img"
cat > "$ISO/boot/grub/grub.cfg" << 'GRUBEOF'
set timeout=1
set default=0
menuentry "WayangOS POS" {
    linux /boot/vmlinuz loglevel=1 vt.global_cursor_default=0 video=1024x600 quiet
    initrd /boot/initramfs.img
}
GRUBEOF
grub-mkrescue -o wayangos-pos-v3.iso "$ISO" 2>/dev/null
rm -rf "$ISO"
ls -lh wayangos-pos-v3.iso
echo "ISO build complete!"
