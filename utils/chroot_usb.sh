#!/bin/sh
#HL#utils/chroot_device.sh#
# Simple chroot script that takes a device as argument
set -e

# Check if device argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <device>"
    echo "Example: $0 /dev/sdb2"
    exit 1
fi

DEVICE="$1"
MOUNT_POINT="/mnt/chroot_$$"

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo "Error: Device $DEVICE does not exist or is not a block device"
    exit 1
fi

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Cleanup function
cleanup() {
    echo "[+] Cleaning up..."
    umount "$MOUNT_POINT/dev/pts" 2>/dev/null || true
    umount "$MOUNT_POINT/dev" 2>/dev/null || true
    umount "$MOUNT_POINT/proc" 2>/dev/null || true
    umount "$MOUNT_POINT/sys" 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# Create mount point
mkdir -p "$MOUNT_POINT"

# Mount the device
echo "[+] Mounting $DEVICE to $MOUNT_POINT..."
mount "$DEVICE" "$MOUNT_POINT"

# Mount essential filesystems
echo "[+] Mounting proc, sys, dev..."
mount -t proc proc "$MOUNT_POINT/proc"
mount -t sysfs sys "$MOUNT_POINT/sys"
mount -o bind /dev "$MOUNT_POINT/dev"
mount -t devpts devpts "$MOUNT_POINT/dev/pts"

# Copy resolv.conf for network access
if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"
fi

# Enter chroot
echo "[+] Entering chroot environment..."
chroot "$MOUNT_POINT" /bin/sh -l

echo "[+] Exited chroot"
