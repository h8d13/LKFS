#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[-] Unmounting VFS from $CHROOT..."

# Unmount all filesystems under chroot (from alpine-chroot-install approach)
cat /proc/mounts | cut -d' ' -f2 | grep "^$CHROOT" | sort -r | while read path; do
    echo "Unmounting $path" >&2
    umount -fn "$path" 2>/dev/null || true
done

echo "[-] Unmounting complete."