#!/bin/bash
# Send commands to QEMU via monitor and capture screen
MON=/tmp/qemu-mon3

send_key() {
    echo "sendkey $1" | socat - UNIX-CONNECT:$MON
    sleep 0.05
}

type_string() {
    local str="$1"
    local i c key
    for (( i=0; i<${#str}; i++ )); do
        c="${str:$i:1}"
        case "$c" in
            " ") key="spc" ;;
            "/") key="slash" ;;
            ".") key="dot" ;;
            "-") key="minus" ;;
            "_") key="shift-minus" ;;
            "=") key="equal" ;;
            "*") key="shift-8" ;;
            "|") key="shift-backslash" ;;
            [0-9]) key="$c" ;;
            [a-z]) key="$c" ;;
            [A-Z]) key="shift-$(echo "$c" | tr 'A-Z' 'a-z')" ;;
            *) key="$c" ;;
        esac
        send_key "$key"
    done
    send_key "ret"
}

echo "[*] Waiting for boot..."
sleep 8

echo "[*] Typing: ls /dev/fb* /dev/dri/*"
type_string "ls /dev/fb0 /dev/dri/card0 2>&1"
sleep 2

echo "[*] Capturing screen..."
echo "screendump /tmp/qemu-screen1.ppm" | socat - UNIX-CONNECT:$MON
sleep 2

if [ -f /tmp/qemu-screen1.ppm ]; then
    convert /tmp/qemu-screen1.ppm /tmp/qemu-screen1.jpg 2>/dev/null
    echo "[*] Screen 1 captured: $(ls -lh /tmp/qemu-screen1.jpg 2>/dev/null | awk '{print $5}')"
else
    echo "[!] screendump failed"
fi

echo "[*] Typing: SDL_VIDEODRIVER=kmsdrm viewer /root/test.bmp"
type_string "SDL_VIDEODRIVER=kmsdrm viewer /root/test.bmp"
sleep 3

echo "[*] Capturing screen after viewer..."
echo "screendump /tmp/qemu-screen2.ppm" | socat - UNIX-CONNECT:$MON
sleep 2

if [ -f /tmp/qemu-screen2.ppm ]; then
    convert /tmp/qemu-screen2.ppm /tmp/qemu-screen2.jpg 2>/dev/null
    echo "[*] Screen 2 captured: $(ls -lh /tmp/qemu-screen2.jpg 2>/dev/null | awk '{print $5}')"
else
    echo "[!] screendump 2 failed"
fi

echo "[*] Trying fbdev instead..."
type_string "SDL_VIDEODRIVER=fbdev viewer /root/test.bmp"
sleep 3

echo "screendump /tmp/qemu-screen3.ppm" | socat - UNIX-CONNECT:$MON
sleep 2

if [ -f /tmp/qemu-screen3.ppm ]; then
    convert /tmp/qemu-screen3.ppm /tmp/qemu-screen3.jpg 2>/dev/null
    echo "[*] Screen 3 captured: $(ls -lh /tmp/qemu-screen3.jpg 2>/dev/null | awk '{print $5}')"
fi

echo "[*] Done"
