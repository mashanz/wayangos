#!/bin/bash
qemu-system-x86_64 \
  -kernel vmlinuz \
  -initrd initramfs.img \
  -append "console=ttyS0" \
  -nographic \
  -m 128M
