#!/bin/bash
set -e

BUILD=~/wayangos-build
ROOTFS=$BUILD/rootfs-v2
BUSYBOX_DIR=$BUILD/busybox-1.37.0
INITRAMFS=$BUILD/wayangos-0.2-x86_64-initramfs.img

echo "=== WayangOS v0.2 Rootfs Build ==="
echo "Target: deployment OS with networking + SSH + curl"

# Clean rootfs
rm -rf $ROOTFS
mkdir -p $ROOTFS/{bin,sbin,usr/bin,usr/sbin,etc,proc,sys,dev,tmp,var/log,var/run,root/.ssh,mnt}

# ============================================
# 1. BusyBox (already built static)
# ============================================
echo "[1/4] Installing BusyBox..."
cp $BUILD/rootfs/bin/busybox $ROOTFS/bin/busybox
chmod 755 $ROOTFS/bin/busybox

# Install all applets
cd $ROOTFS
for applet in $(chroot . /bin/busybox --list 2>/dev/null || $ROOTFS/bin/busybox --list); do
    if [ ! -e "bin/$applet" ] && [ ! -e "sbin/$applet" ] && [ ! -e "usr/bin/$applet" ] && [ ! -e "usr/sbin/$applet" ]; then
        ln -sf /bin/busybox bin/$applet 2>/dev/null || true
    fi
done
cd $BUILD

# ============================================
# 2. Dropbear SSH (static build)
# ============================================
echo "[2/4] Building Dropbear SSH..."
DROPBEAR_VER=2024.86
if [ ! -f "$BUILD/dropbear-$DROPBEAR_VER.tar.bz2" ]; then
    wget -q "https://matt.ucc.asn.au/dropbear/releases/dropbear-$DROPBEAR_VER.tar.bz2" -O "$BUILD/dropbear-$DROPBEAR_VER.tar.bz2"
fi

cd $BUILD
rm -rf dropbear-$DROPBEAR_VER
tar xjf dropbear-$DROPBEAR_VER.tar.bz2
cd dropbear-$DROPBEAR_VER

# Configure for static build with musl
./configure --enable-static --disable-zlib --disable-pam --disable-harden \
    --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
    LDFLAGS="-static" CFLAGS="-Os -s" 2>&1 | tail -3

# Build
make PROGRAMS="dropbear dropbearkey dbclient scp" MULTI=1 STATIC=1 -j$(nproc) 2>&1 | tail -5

# Install multi-call binary
cp dropbearmulti $ROOTFS/usr/bin/dropbearmulti
chmod 755 $ROOTFS/usr/bin/dropbearmulti
ln -sf /usr/bin/dropbearmulti $ROOTFS/usr/sbin/dropbear
ln -sf /usr/bin/dropbearmulti $ROOTFS/usr/bin/dropbearkey
ln -sf /usr/bin/dropbearmulti $ROOTFS/usr/bin/dbclient
ln -sf /usr/bin/dropbearmulti $ROOTFS/usr/bin/scp
ln -sf /usr/bin/dbclient $ROOTFS/usr/bin/ssh

echo "  Dropbear size: $(du -h $ROOTFS/usr/bin/dropbearmulti | cut -f1)"

# ============================================
# 3. Static curl with TLS
# ============================================
echo "[3/4] Downloading static curl..."
# Use pre-built static curl from moparisthebest
CURL_URL="https://github.com/moparisthebest/static-curl/releases/latest/download/curl-amd64"
wget -q "$CURL_URL" -O $ROOTFS/usr/bin/curl
chmod 755 $ROOTFS/usr/bin/curl
echo "  curl size: $(du -h $ROOTFS/usr/bin/curl | cut -f1)"

# ============================================
# 4. Init scripts & config
# ============================================
echo "[4/4] Writing init scripts..."

# /etc/passwd & shadow
cat > $ROOTFS/etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
nobody:x:65534:65534:nobody:/:/bin/false
EOF

cat > $ROOTFS/etc/shadow << 'EOF'
root::0:0:99999:7:::
nobody:!:0:0:99999:7:::
EOF
chmod 640 $ROOTFS/etc/shadow

cat > $ROOTFS/etc/group << 'EOF'
root:x:0:
nobody:x:65534:
EOF

# /etc/hostname
echo "wayangos" > $ROOTFS/etc/hostname

# /etc/hosts
cat > $ROOTFS/etc/hosts << 'EOF'
127.0.0.1   localhost wayangos
::1         localhost
EOF

# /etc/profile
cat > $ROOTFS/etc/profile << 'PROFILE'
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="/root"
export TERM="linux"
export PS1='\[\e[1;33m\]wayangos\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]# '

alias ll='ls -la'
alias ..='cd ..'

echo ""
echo "  ꦮꦪꦁ  WayangOS v0.2"
echo "  The Shadow that Powers the Machine"
echo ""
PROFILE

# /etc/inittab
cat > $ROOTFS/etc/inittab << 'EOF'
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
tty2::askfirst:-/bin/sh
tty3::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/etc/init.d/rcK
EOF

# Init scripts directory
mkdir -p $ROOTFS/etc/init.d
mkdir -p $ROOTFS/etc/dropbear

# Master init script
cat > $ROOTFS/etc/init.d/rcS << 'INIT'
#!/bin/sh
echo "WayangOS booting..."

# Mount virtual filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /tmp
mount -t tmpfs tmpfs /var/run

# Set hostname
hostname -F /etc/hostname

# Seed kernel log
dmesg -n 1

# Network
echo "Starting network..."
/etc/init.d/network start

# SSH
echo "Starting SSH..."
/etc/init.d/sshd start

# Syslog
echo "Starting syslog..."
syslogd -O /var/log/messages -s 200 -b 2

# NTP (background, don't block boot)
ntpd -p pool.ntp.org -S /bin/true &

echo ""
echo "  ꦮꦪꦁ  WayangOS v0.2 ready"
ip -4 addr show scope global 2>/dev/null | grep inet | awk '{print "  IP: " $2}'
echo ""
INIT
chmod +x $ROOTFS/etc/init.d/rcS

# Shutdown script
cat > $ROOTFS/etc/init.d/rcK << 'SHUTDOWN'
#!/bin/sh
echo "WayangOS shutting down..."
killall dropbear 2>/dev/null
killall syslogd 2>/dev/null
killall ntpd 2>/dev/null
ifconfig eth0 down 2>/dev/null
umount -a -r 2>/dev/null
SHUTDOWN
chmod +x $ROOTFS/etc/init.d/rcK

# Network init script
cat > $ROOTFS/etc/init.d/network << 'NETWORK'
#!/bin/sh
case "$1" in
    start)
        # Bring up loopback
        ifconfig lo 127.0.0.1 netmask 255.0.0.0 up

        # Auto-detect and bring up first ethernet interface
        for iface in eth0 enp0s3 ens3 ens33; do
            if [ -d "/sys/class/net/$iface" ]; then
                echo "  DHCP on $iface..."
                ifconfig $iface up
                udhcpc -i $iface -q -s /etc/udhcpc.script -t 5 -T 3 2>/dev/null &
                break
            fi
        done
        ;;
    stop)
        killall udhcpc 2>/dev/null
        for iface in eth0 enp0s3 ens3 ens33; do
            ifconfig $iface down 2>/dev/null
        done
        ;;
    restart)
        $0 stop; sleep 1; $0 start
        ;;
esac
NETWORK
chmod +x $ROOTFS/etc/init.d/network

# DHCP client script
cat > $ROOTFS/etc/udhcpc.script << 'DHCP'
#!/bin/sh
case "$1" in
    bound|renew)
        ifconfig $interface $ip netmask $subnet up
        if [ -n "$router" ]; then
            route del default 2>/dev/null
            for gw in $router; do
                route add default gw $gw dev $interface
            done
        fi
        : > /etc/resolv.conf
        for ns in $dns; do
            echo "nameserver $ns" >> /etc/resolv.conf
        done
        echo "  $interface: $ip (gw: $router)"
        ;;
    deconfig)
        ifconfig $interface 0.0.0.0
        ;;
esac
DHCP
chmod +x $ROOTFS/etc/udhcpc.script

# SSH init script
cat > $ROOTFS/etc/init.d/sshd << 'SSHD'
#!/bin/sh
case "$1" in
    start)
        # Generate host keys if missing
        if [ ! -f /etc/dropbear/dropbear_ed25519_host_key ]; then
            echo "  Generating SSH host keys..."
            dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key 2>/dev/null
        fi
        # Start dropbear (allow root login, no password by default — add key to /root/.ssh/authorized_keys)
        dropbear -R -E -p 22
        echo "  SSH listening on port 22"
        ;;
    stop)
        killall dropbear 2>/dev/null
        ;;
    restart)
        $0 stop; sleep 1; $0 start
        ;;
esac
SSHD
chmod +x $ROOTFS/etc/init.d/sshd

# DNS fallback
cat > $ROOTFS/etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# ============================================
# Build initramfs
# ============================================
echo ""
echo "=== Building initramfs ==="
cd $ROOTFS
find . | cpio -o -H newc 2>/dev/null | gzip -9 > $INITRAMFS

echo ""
echo "=== Rootfs contents ==="
echo "  BusyBox: $(du -h bin/busybox | cut -f1)"
echo "  Dropbear: $(du -h usr/bin/dropbearmulti | cut -f1)"
echo "  curl: $(du -h usr/bin/curl | cut -f1)"
echo "  Initramfs: $(du -h $INITRAMFS | cut -f1)"
echo ""
echo "=== Build complete ==="
