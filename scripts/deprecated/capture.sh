#!/bin/bash
cd /tmp
export DISPLAY=:0
ffmpeg -f x11grab -s 1920x1080 -i :0 -vframes 1 /tmp/screen.png -y 2>/dev/null
if [ -f /tmp/screen.png ]; then
    cp /tmp/screen.png "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/display.png"
    ls -lh /tmp/screen.png
else
    echo "Capture failed"
fi
