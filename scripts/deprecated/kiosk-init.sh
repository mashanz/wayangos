#!/bin/sh
case "$1" in
    start)
        echo "  Starting kiosk display..."
        sleep 2
        export SDL_VIDEODRIVER=fbdev
        export SDL_FBDEV=/dev/fb0
        /usr/bin/kiosk-demo > /var/log/kiosk.log 2>&1 &
        echo "  Kiosk PID: $!"
        ;;
    stop)
        killall kiosk-demo 2>/dev/null
        ;;
esac
