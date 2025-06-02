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

# Function to safely unmount
safe_unmount() {
    local path="$1"
    if mountpoint -q "$path" 2>/dev/null; then
        echo "[-] Unmounting $path"
        if ! umount "$path" 2>/dev/null; then
            # Try lazy unmount as fallback
            umount -l "$path" 2>/dev/null || true
        fi
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
    "$CHROOT_ABS/tmp" \
    "$CHROOT_ABS/run"
do
    safe_unmount "$mount_point"
done

# Alternative method: find all mounts under chroot and unmount
if command -v findmnt >/dev/null 2>&1; then
    findmnt -rn -o TARGET | grep "^$CHROOT_ABS" | sort -r | while read -r path; do
        safe_unmount "$path"
    done
fi

echo "[-] Unmounting complete."