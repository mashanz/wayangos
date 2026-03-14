# Building WayangOS

## Prerequisites

### Debian/Ubuntu
```bash
sudo apt install build-essential flex bison bc libelf-dev libssl-dev \
  gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu \
  cpio gzip qemu-system-x86 qemu-system-arm qemu-system-misc
```

### Arch Linux
```bash
sudo pacman -S base-devel flex bison bc libelf openssl \
  aarch64-linux-gnu-gcc riscv64-linux-gnu-gcc \
  cpio qemu-full
```

## Building the Kernel

```bash
# Make scripts executable
chmod +x build/*.sh

# Build x86_64 minimal kernel
./build/build-kernel.sh x86_64 minimal

# Build ARM64 server kernel
./build/build-kernel.sh arm64 server

# Build RISC-V real-time kernel
./build/build-kernel.sh riscv rt
```

Output goes to `build/output/<arch>-<config>/`.

## Building the Root Filesystem

```bash
./build/build-rootfs.sh x86_64
```

Output: `build/output/rootfs/<arch>-initramfs.cpio.gz`

## Testing with QEMU

### x86_64
```bash
qemu-system-x86_64 \
  -kernel build/output/x86_64-minimal/bzImage \
  -initrd build/output/rootfs/x86_64-initramfs.cpio.gz \
  -append "console=ttyS0" \
  -nographic -m 64M
```

### ARM64
```bash
qemu-system-aarch64 \
  -machine virt -cpu cortex-a72 \
  -kernel build/output/arm64-minimal/Image \
  -initrd build/output/rootfs/arm64-initramfs.cpio.gz \
  -append "console=ttyAMA0" \
  -nographic -m 64M
```

### RISC-V
```bash
qemu-system-riscv64 \
  -machine virt \
  -kernel build/output/riscv-minimal/Image \
  -initrd build/output/rootfs/riscv-initramfs.cpio.gz \
  -append "console=ttyS0" \
  -nographic -m 64M
```

## Custom Configurations

To create a custom kernel config:

1. Start from an existing profile: `cp configs/minimal.config configs/custom.config`
2. Edit with menuconfig: `cd kernel && make ARCH=x86_64 menuconfig`
3. Save the result: `cp .config ../configs/custom.config`
4. Build: `./build/build-kernel.sh x86_64 custom`
