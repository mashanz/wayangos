#!/bin/bash
# Wait for QEMU to boot
sleep 2

# Send screendump command
echo "screendump /tmp/demo-shot.ppm" | socat - UNIX-CONNECT:/tmp/qemu-demo-mon
sleep 3

# Check and convert
if [ -f /tmp/demo-shot.ppm ]; then
    convert /tmp/demo-shot.ppm /tmp/demo-shot.jpg
    cp "/tmp/demo-shot.jpg" "/mnt/c/Users/Desktop PC/.openclaw/workspace/linux-distro/demo-shot.jpg"
    ls -lh /tmp/demo-shot.jpg
    echo "SAVED"
else
    echo "No screenshot captured"
    # Debug: check if socket exists
    ls -la /tmp/qemu-demo-mon
    echo "screendump /tmp/demo-shot.ppm" | timeout 3 socat -d -d - UNIX-CONNECT:/tmp/qemu-demo-mon 2>&1
fi
