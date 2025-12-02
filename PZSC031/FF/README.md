# Kernel Compilation Module

Build custom Linux kernels from source with automated configuration and compilation.

## Quick Reference

| File | Purpose |
|------|---------|
| [`deps.txt`](./deps.txt) | Required system dependencies for building kernels |
| [`kernel.conf`](./kernel.conf) | Build configuration (version, config type, jobs, work dir) |
| [`defconfig-essentials-only.config`](./defconfig-essentials-only.config) | Minimal kernel fragment config (defconfig + essentials) |
| [`alpine-stable-6.17-x86_64.config`](./alpine-stable-6.17-x86_64.config) | Full kernel configuration example from upstream |

## Config Types

### Fragment Config (Recommended)
Uses `defconfig` + your custom additions. Minimal and maintainable.

**Example:** [`defconfig-essentials-only.config`](./defconfig-essentials-only.config)

### Full Config
Complete kernel configuration with all options specified.

**Example:** [`alpine-stable-6.17-x86_64.config`](./alpine-stable-6.17-x86_64.config)

## Usage

1. Edit [`kernel.conf`](./kernel.conf) to set your preferences
2. Run `./comp_kern.sh` from repo root to build the kernel
3. Edit [`ALPM-FS.conf`](../../ALPM-FS.conf) and set `USE_CUSTOM_KERNEL="yes"`
4. Run `./create_boot_img.sh <name> <size>` to create bootable image (note: it's size minus /efi part size.)

The bootable image creator will automatically use your custom kernel (bzImage) and install its modules instead of using Alpine's kernel packages.
