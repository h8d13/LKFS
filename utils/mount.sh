#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[+] Mounting VFS into $CHROOT..."

# Create necessary directories
mkdir -p "$CHROOT"/{dev,dev/pts,proc,sys,tmp}

# Mount with detailed output
mount_with_details() {
    local mount_type="$1"
    local source="$2"
    local target="$3"
    local options="$4"
    
    if ! mount | grep -q "$target"; then
        echo "[+] Mounting $mount_type: $source -> $target"
        if [ -n "$options" ]; then
            mount $options "$source" "$target"
        else
            mount -t "$mount_type" "$source" "$target"
        fi
        echo "[+] ✓ Successfully mounted $target"
    else
        echo "[+] Already mounted: $target"
    fi
}

# Mount filesystems with detailed output
mount_with_details "proc" "none" "$CHROOT/proc"
mount_with_details "sysfs" "/sys" "$CHROOT/sys" "--rbind"
mount --make-rprivate "$CHROOT/sys"
echo "[+] Made $CHROOT/sys private"

mount_with_details "devtmpfs" "/dev" "$CHROOT/dev" "--rbind"
mount --make-rprivate "$CHROOT/dev" 
echo "[+] Made $CHROOT/dev private"

mount_with_details "tmpfs" "tmpfs" "$CHROOT/tmp"

echo "[+] All mounts completed successfully!"