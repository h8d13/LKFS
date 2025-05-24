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

if cat /proc/mounts | cut -d' ' -f2 | grep -q "^$CHROOT"; then
    cat /proc/mounts | cut -d' ' -f2 | grep "^$CHROOT" | sort -r | while read path; do
        echo "Unmounting $path" >&2
        umount -fn "$path" 2>/dev/null || true
    done
else
    echo "[-] No mounts found under $CHROOT"
fi

echo "[-] Unmounting complete."