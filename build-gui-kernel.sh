#!/bin/bash
set -e

BUILD=~/wayangos-build
KDIR=$BUILD/linux-6.12.6

echo "=== Building WayangOS GUI Kernel ==="

cd $KDIR

# Start from existing config
cp .config .config.headless.bak

# Enable framebuffer + DRM + input
cat >> .config << 'EXTRA'

# === GUI/Framebuffer support ===
CONFIG_DRM=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_FBDEV_OVERALLOC=100
CONFIG_FB=y
CONFIG_FB_CORE=y
CONFIG_FB_DEVICE=y
CONFIG_FB_VGA16=y
CONFIG_FB_VESA=y
CONFIG_FB_EFI=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_VGA_CONSOLE=y

# DRM drivers (QEMU + real hardware)
CONFIG_DRM_BOCHS=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_DRM_VKMS=y
CONFIG_DRM_QXL=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_DRM_I915=y
CONFIG_DRM_AMDGPU=n
CONFIG_DRM_NOUVEAU=n

# Input
CONFIG_INPUT=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_INPUT_MOUSEDEV=y
CONFIG_INPUT_MOUSEDEV_PSAUX=y

# USB HID (keyboard/mouse)
CONFIG_HID=y
CONFIG_HID_GENERIC=y
CONFIG_USB_HID=y

# Fonts
CONFIG_FONT_SUPPORT=y
CONFIG_FONT_8x16=y
CONFIG_FONT_8x8=y

# Backlight
CONFIG_BACKLIGHT_CLASS_DEVICE=y
EXTRA

# Resolve new config options
make olddefconfig 2>&1 | tail -5

echo "Building kernel..."
make -j$(nproc) bzImage 2>&1 | tail -10

# Copy output
cp arch/x86/boot/bzImage $BUILD/vmlinuz-gui
echo "GUI kernel: $(du -h $BUILD/vmlinuz-gui | cut -f1)"

# Restore headless config
cp .config.headless.bak .config

echo "=== GUI Kernel Done ==="
