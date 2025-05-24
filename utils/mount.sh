#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[+] Mounting VFS into $CHROOT..."

# Create necessary directories
mkdir -p "$CHROOT"/{dev,dev/pts,proc,sys,run,tmp}

# Mount filesystems (similar to alpine-chroot-install)
mount -t proc none "$CHROOT/proc"
mount --rbind /sys "$CHROOT/sys"
mount --make-rprivate "$CHROOT/sys"
mount --rbind /dev "$CHROOT/dev"
mount --make-rprivate "$CHROOT/dev"

# Handle /dev/shm symlink case
if [ -L /dev/shm ] && [ -d /run/shm ]; then
    mkdir -p "$CHROOT/run/shm"
    mount --bind /run/shm "$CHROOT/run/shm"
    mount --make-private "$CHROOT/run/shm"
fi

echo "[+] Mounting complete."