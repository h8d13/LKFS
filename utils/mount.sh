#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[+] Mounting VFS into $CHROOT..."

# Create necessary directories
mkdir -p "$CHROOT"/{dev,dev/pts,proc,sys,run,tmp}

# Check if already mounted to avoid double-mounting
if ! mount | grep -q "$CHROOT/proc"; then
    mount -t proc none "$CHROOT/proc"
fi

if ! mount | grep -q "$CHROOT/sys"; then
    mount --rbind /sys "$CHROOT/sys"
    mount --make-rprivate "$CHROOT/sys"
fi

if ! mount | grep -q "$CHROOT/dev"; then
    mount --rbind /dev "$CHROOT/dev"
    mount --make-rprivate "$CHROOT/dev"
fi

if ! mount | grep -q "$CHROOT/tmp"; then
    mount -t tmpfs tmpfs "$CHROOT/tmp"
fi

echo "[+] Mounting complete."