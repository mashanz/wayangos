#!/bin/bash
MON=/tmp/qemu-v3-mon

send_key() {
    printf 'sendkey %s\n' "$1" | socat - UNIX-CONNECT:$MON
    sleep 0.08
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
            [0-9]) key="$c" ;;
            [a-z]) key="$c" ;;
            [A-Z]) key="shift-$(echo "$c" | tr 'A-Z' 'a-z')" ;;
        esac
        send_key "$key"
    done
    send_key "ret"
    sleep 1
}

echo "[*] Running viewer with fbdev backend..."
type_string "SDL_VIDEODRIVER=fbdev SDL_FBDEV=/dev/fb0 viewer /root/test.bmp"

echo "[*] Waiting 5s for viewer to render..."
sleep 5

echo "[*] Capturing screenshot..."
printf 'screendump /tmp/viewer-fbdev.ppm\n' | socat - UNIX-CONNECT:$MON
sleep 2

if [ -f /tmp/viewer-fbdev.ppm ]; then
    convert /tmp/viewer-fbdev.ppm /tmp/viewer-fbdev.jpg
    cp "/tmp/viewer-fbdev.jpg" "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/viewer-fbdev.jpg"
    echo "Screenshot: $(ls -lh /tmp/viewer-fbdev.jpg | awk '{print $5}')"
else
    echo "No screenshot"
fi
