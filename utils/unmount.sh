#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[-] Unmounting VFS from $CHROOT..."

# Check if chroot directory exists
if [ ! -d "$CHROOT" ]; then
    echo "[-] Chroot directory doesn't exist, nothing to unmount."
    exit 0
fi

# More aggressive unmounting - check both /proc/mounts and mount command
CHROOT_ABS=$(readlink -f "$CHROOT" 2>/dev/null || echo "$CHROOT")

# Method 1: Using /proc/mounts
if cat /proc/mounts 2>/dev/null | cut -d' ' -f2 | grep -q "^$CHROOT_ABS"; then
    cat /proc/mounts | cut -d' ' -f2 | grep "^$CHROOT_ABS" | sort -r | while read path; do
        echo "[-] Unmounting $path" >&2
        umount -fn "$path" 2>/dev/null || umount -l "$path" 2>/dev/null || true
    done
fi

echo "[-] Unmounting complete."