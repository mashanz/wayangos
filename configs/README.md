# WayangOS Kernel Configs

Kernel configs for Linux 6.19.7 targeting different GPU/platform combos.

## Available Configs

### `defconfig-qemu` ✅ (CURRENT)
- **Base:** `make defconfig` + framebuffer/input/DRM overlays
- **GPU:** DRM_BOCHS, DRM_VIRTIO_GPU, DRM_QXL, DRM_SIMPLEDRM, DRM_VKMS
- **Input:** Full evdev + USB HID + i8042 PS/2 + AT keyboard
- **Status:** Working — keyboard input confirmed in QEMU
- **Kernel:** `bzImage-qemu` (14MB)
- **Notes:** This is the recommended config for QEMU testing. Uses `defconfig` as base which includes everything needed for PS/2 keyboard to work.

### Intel i915 (config lost)
- **GPU:** DRM_I915=y (Intel integrated graphics)
- **Built from:** `build-gui-kernel.sh` with `CONFIG_DRM_I915=y`
- **Kernel:** `bzImage-intel` (14MB)
- **Status:** Not tested on real hardware yet

### AMD amdgpu+radeon (config lost)
- **GPU:** DRM_AMDGPU=y, DRM_RADEON=y
- **Built from:** `build-x86-gpu-v4.sh` variant
- **Kernel:** `bzImage-amd` (19MB) — larger due to AMD firmware support
- **Status:** Not tested on real hardware yet

### NVIDIA nouveau (config lost)
- **GPU:** DRM_NOUVEAU=y
- **Built from:** `build-x86-gpu-v4.sh` variant
- **Kernel:** `bzImage-nvidia` (15MB)
- **Status:** Not tested on real hardware yet

### Custom minimal (config lost)
- **Base:** Hand-tuned minimal config with GUI/input stack
- **Kernel:** `vmlinuz-gui-with-input` (4.8MB)
- **Status:** ⚠️ BROKEN — keyboard doesn't work in QEMU (missing i8042/atkbd drivers)
- **Lesson:** Custom minimal configs miss subtle dependencies. Use `defconfig` as base.

## How Configs Were Built

All GPU-specific configs were built by starting from a base config and appending GPU-specific options, then running `make olddefconfig` to resolve dependencies:

```bash
cd ~/wayangos-build/linux-6.19.7
cp /path/to/base-config .config

# Append GPU-specific options
cat >> .config << 'EOF'
CONFIG_DRM_I915=y
# ... etc
EOF

make olddefconfig
make -j$(nproc) bzImage
```

## Known Issues

1. **Custom minimal configs break keyboard in QEMU** — The i8042 PS/2 controller and AT keyboard driver are needed for QEMU keyboard input. `defconfig` includes these; hand-tuned minimal configs often don't.

2. **Old configs can't be recovered** — Each kernel build overwrites `.config`. Only the latest (defconfig-qemu) was saved. Future builds should save configs before switching.

## Recovering Configs for GPU Variants

To regenerate GPU-specific configs, start from `defconfig-qemu` and add GPU flags:

```bash
# Intel
cp configs/defconfig-qemu .config
echo "CONFIG_DRM_I915=y" >> .config
make olddefconfig

# AMD
cp configs/defconfig-qemu .config
cat >> .config << 'EOF'
CONFIG_DRM_AMDGPU=y
CONFIG_DRM_RADEON=y
EOF
make olddefconfig

# NVIDIA
cp configs/defconfig-qemu .config
echo "CONFIG_DRM_NOUVEAU=y" >> .config
make olddefconfig
```
