#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"  # Core Alpine root filesystem
MNT_DIR="$SCRIPT_DIR/../alpinestein_mnt"  # Separate directory for mounts

echo "[+] Creating mnt namespace"
# Create the mount directory if it doesn't exist
mkdir -p "$MNT_DIR"
echo "[+] Mounting VFS into $MNT_DIR..."

mkdir -p "$MNT_DIR/dev"
mkdir -p "$MNT_DIR/proc"
mkdir -p "$MNT_DIR/sys"
mkdir -p "$MNT_DIR/run"
mkdir -p "$MNT_DIR/tmp"
mkdir -p "$MNT_DIR/var"

echo "[+] Unsharing mount namespace"
# Use unshare to isolate the environment and mount the necessary directories
unshare --mount --fork bash <<EOF
echo "[+] Inside unshare environment"
# Bind mount necessary directories
mount --bind /dev "$MNT_DIR/dev" || { echo "Failed to mount /dev"; exit 1; }
mount -t proc proc "$MNT_DIR/proc" || { echo "Failed to mount /proc"; exit 1; }
mount -t sysfs sys "$MNT_DIR/sys" || { echo "Failed to mount /sys"; exit 1; }
mount -t tmpfs tmpfs "$MNT_DIR/run" || { echo "Failed to mount /run"; exit 1; }
mount --bind /tmp "$MNT_DIR/tmp" || { echo "Failed to mount /tmp"; exit 1; }
mount --bind /var "$MNT_DIR/var" || { echo "Failed to mount /var"; exit 1; }

echo "[+] Mounting complete within namespace."

# Check if /proc/mounts exists and list mounts inside the unshare namespace
if [ -f "$MNT_DIR/proc/mounts" ]; then
    echo "[+] /proc/mounts found."
    #DEBUGmount
else
    echo "[!] /proc/mounts not found"
fi
EOF
