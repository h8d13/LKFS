#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"
CHROOT_ABS=$(readlink -f "$CHROOT")

echo "[+] Mounting VFS into $CHROOT_ABS..."

# Create necessary directories
mkdir -p "$CHROOT"/{dev,dev/pts,dev/shm,proc,sys,run,tmp}

# Safe mount function with proper option handling
safe_mount() {
    local mount_type="$1"
    local source="$2"
    local target="$3"
    local mount_opts="$4"
    
    if ! mount | grep -q " $target "; then
        echo "[+] Mounting $mount_type: $source -> $target"
        
        if [ "$mount_type" = "bind" ]; then
            mount --rbind "$source" "$target"
        elif [ -n "$mount_opts" ]; then
            mount -t "$mount_type" -o "$mount_opts" "$source" "$target"
        else
            mount -t "$mount_type" "$source" "$target"
        fi
        
        echo "[+] ✓ Successfully mounted $target"
    else
        echo "[+] Already mounted: $target"
    fi
}

# Mount filesystems
safe_mount "proc" "none" "$CHROOT/proc"

safe_mount "bind" "/sys" "$CHROOT/sys"
mount --make-rprivate "$CHROOT/sys"
echo "[+] Made $CHROOT/sys private"

safe_mount "bind" "/dev" "$CHROOT/dev"
mount --make-rprivate "$CHROOT/dev"
echo "[+] Made $CHROOT/dev private"

safe_mount "tmpfs" "tmpfs" "$CHROOT/run" "mode=0755,nodev,nosuid,noexec"
safe_mount "tmpfs" "tmpfs" "$CHROOT/tmp"
safe_mount "devpts" "devpts" "$CHROOT/dev/pts" "newinstance,ptmxmode=0666"
safe_mount "tmpfs" "tmpfs" "$CHROOT/dev/shm" "mode=1777"

echo "[+] All mounts completed successfully!"