#!/bin/bash
#HL#utils/mount.sh#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"
CHROOT_ABS=$(readlink -f "$CHROOT")

echo "[+] Mounting VFS into $CHROOT_ABS..."

# Create necessary directories first
mkdir -p "$CHROOT"/{dev,proc,sys,run,tmp}

# Safe mount function
safe_mount() {
    local mount_type="$1"
    local source="$2"
    local target="$3"
    local mount_opts="$4"
    if mountpoint -q "$target" 2>/dev/null; then
        echo "[+] Already mounted: $target"
        return 0
    fi
    echo "[+] Mounting $mount_type: $source -> $target"
    case "$mount_type" in
        "bind")
            mount --bind "$source" "$target"
            ;;
        "rbind")
            mount --rbind "$source" "$target"
            ;;
        *)
            if [ -n "$mount_opts" ]; then
                mount -t "$mount_type" -o "$mount_opts" "$source" "$target"
            else
                mount -t "$mount_type" "$source" "$target"
            fi
            ;;
    esac
    echo "[+] ✓ Successfully mounted $target"
}

# Mount basic filesystems first
safe_mount "proc" "proc" "$CHROOT/proc"
safe_mount "sysfs" "sysfs" "$CHROOT/sys"
safe_mount "tmpfs" "tmpfs" "$CHROOT/run" "mode=0755,nodev,nosuid,noexec"
safe_mount "tmpfs" "tmpfs" "$CHROOT/tmp"

# Mount tmpfs on /dev
safe_mount "tmpfs" "tmpfs" "$CHROOT/dev" "mode=0755"

# NOW create the subdirectories inside the tmpfs /dev
mkdir -p "$CHROOT/dev"/{pts,shm}

# Mount the device filesystems
safe_mount "devpts" "devpts" "$CHROOT/dev/pts" "newinstance,ptmxmode=0666"
safe_mount "tmpfs" "tmpfs" "$CHROOT/dev/shm" "mode=1777"

# Create essential device nodes
echo "[+] Creating essential device nodes..."
mknod -m 666 "$CHROOT/dev/null" c 1 3 2>/dev/null || true
mknod -m 666 "$CHROOT/dev/zero" c 1 5 2>/dev/null || true
mknod -m 644 "$CHROOT/dev/random" c 1 8 2>/dev/null || true
mknod -m 644 "$CHROOT/dev/urandom" c 1 9 2>/dev/null || true
mknod -m 666 "$CHROOT/dev/tty" c 5 0 2>/dev/null || true
mknod -m 600 "$CHROOT/dev/console" c 5 1 2>/dev/null || true

# Create symbolic links
ln -sf /proc/self/fd "$CHROOT/dev/fd" 2>/dev/null || true
ln -sf /proc/self/fd/0 "$CHROOT/dev/stdin" 2>/dev/null || true
ln -sf /proc/self/fd/1 "$CHROOT/dev/stdout" 2>/dev/null || true
ln -sf /proc/self/fd/2 "$CHROOT/dev/stderr" 2>/dev/null || true
ln -sf /proc/kcore "$CHROOT/dev/core" 2>/dev/null || true

echo "[+] All mounts completed successfully!"