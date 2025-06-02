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

# Get absolute path
CHROOT_ABS=$(readlink -f "$CHROOT" 2>/dev/null || echo "$CHROOT")

# Function to safely unmount with detailed output
safe_unmount() {
    local path="$1"
    if mountpoint -q "$path" 2>/dev/null; then
        echo "[-] Unmounting: $path"
        if umount "$path" 2>/dev/null; then
            echo "[-] ✓ Successfully unmounted $path"
        elif umount -l "$path" 2>/dev/null; then
            echo "[-] ✓ Lazy unmounted $path"
        else
            echo "[-] ✗ Failed to unmount $path"
        fi
    else
        echo "[-] Not mounted: $path (skipping)"
    fi
}

# Unmount in reverse order (most nested first)
for mount_point in \
    "$CHROOT_ABS/dev/pts" \
    "$CHROOT_ABS/dev/shm" \
    "$CHROOT_ABS/dev" \
    "$CHROOT_ABS/proc" \
    "$CHROOT_ABS/sys/fs/cgroup" \
    "$CHROOT_ABS/sys" \
    "$CHROOT_ABS/tmp" 
do
    safe_unmount "$mount_point"
done

# Double-check with findmnt if available
if command -v findmnt >/dev/null 2>&1; then
    remaining=$(findmnt -rn -o TARGET 2>/dev/null | grep "^$CHROOT_ABS" || true)
    if [ -n "$remaining" ]; then
        echo "[-] Found remaining mounts, cleaning up:"
        echo "$remaining" | sort -r | while read -r path; do
            safe_unmount "$path"
        done
    fi
fi

echo "[-] Unmounting process complete."