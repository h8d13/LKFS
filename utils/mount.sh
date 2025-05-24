#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[+] Mounting VFS into $CHROOT..."

# Create necessary directories
mkdir -p "$CHROOT"/{dev,dev/pts,proc,sys,run,tmp}

mount -t proc none "$CHROOT/proc"
mount --rbind /sys "$CHROOT/sys"
mount --make-rprivate "$CHROOT/sys"
mount --rbind /dev "$CHROOT/dev"
mount --make-rprivate "$CHROOT/dev"

echo "[+] Mounting complete."