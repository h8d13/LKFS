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
        echo "Unmounting $path" >&2
        umount -fn "$path" 2>/dev/null || umount -l "$path" 2>/dev/null || true
    done
fi

# Method 2: Using mount command as backup
if mount 2>/dev/null | grep -q "$CHROOT_ABS"; then
    mount | grep "$CHROOT_ABS" | awk '{print $3}' | sort -r | while read mount_point; do
        echo "Force unmounting $mount_point" >&2
        umount -fl "$mount_point" 2>/dev/null || true
    done
fi

# Final check and lazy unmount if needed
if mount 2>/dev/null | grep -q "$CHROOT_ABS"; then
    echo "[-] Some mounts still active, performing lazy unmount..."
    mount | grep "$CHROOT_ABS" | awk '{print $3}' | while read mount_point; do
        echo "Lazy unmounting $mount_point" >&2
        umount -l "$mount_point" 2>/dev/null || true
    done
fi

echo "[-] Unmounting complete."