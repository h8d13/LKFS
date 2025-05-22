#!/bin/bash
#HL#utils/mount.sh#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"

echo "[+] Creating mount namespace and mounting VFS into $CHROOT..."

# Create necessary directories in the chroot
mkdir -p "$CHROOT/dev"
mkdir -p "$CHROOT/dev/pts"
mkdir -p "$CHROOT/proc"
mkdir -p "$CHROOT/sys"
mkdir -p "$CHROOT/run"
mkdir -p "$CHROOT/tmp"

echo "[+] Unsharing mount namespace"

# Use unshare to isolate the environment and mount the necessary directories
unshare --mount --fork bash <<EOF
echo "[+] Inside unshare environment - mounting to $CHROOT"

# Mount essential filesystems in correct order
mount --bind /dev "$CHROOT/dev" || { echo "Failed to mount /dev"; exit 1; }
mount --bind /dev/pts "$CHROOT/dev/pts" || { echo "Failed to mount /dev/pts"; exit 1; }
mount -t proc proc "$CHROOT/proc" || { echo "Failed to mount /proc"; exit 1; }
mount -t sysfs sys "$CHROOT/sys" || { echo "Failed to mount /sys"; exit 1; }
mount -t tmpfs tmpfs "$CHROOT/run" || { echo "Failed to mount /run"; exit 1; }
mount --bind /tmp "$CHROOT/tmp" || { echo "Failed to mount /tmp"; exit 1; }

echo "[+] Mounting complete within namespace."

# Verify mounts
echo "[+] Verifying mounts:"
for mp in dev dev/pts proc sys run tmp; do
    if mountpoint -q "$CHROOT/\$mp" 2>/dev/null; then
        echo "[✓] \$mp mounted successfully"
    else
        echo "[!] \$mp mount verification failed"
    fi
done

EOF