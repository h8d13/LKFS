#!/bin/bash
#HL#utils/unmount.sh#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"  # Match the actual chroot directory

echo "[-] Unmounting VFS from $CHROOT..."

# Unshare the mount namespace for unmounting
unshare --mount --fork bash <<EOF
echo "[-] Unshare env - unmounting from $CHROOT"

# Check if mounts are active and unmount them in reverse order
if mountpoint -q "$CHROOT/tmp"; then
  umount "$CHROOT/tmp" || echo "Warning: Failed to unmount /tmp"
fi
if mountpoint -q "$CHROOT/run"; then
  umount "$CHROOT/run" || echo "Warning: Failed to unmount /run"
fi
if mountpoint -q "$CHROOT/sys"; then
  umount "$CHROOT/sys" || echo "Warning: Failed to unmount /sys"
fi
if mountpoint -q "$CHROOT/proc"; then
  umount "$CHROOT/proc" || echo "Warning: Failed to unmount /proc"
fi
if mountpoint -q "$CHROOT/dev/pts"; then
  umount "$CHROOT/dev/pts" || echo "Warning: Failed to unmount /dev/pts"
fi
if mountpoint -q "$CHROOT/dev"; then
  umount "$CHROOT/dev" || echo "Warning: Failed to unmount /dev"
fi

echo "[-] Unmounting complete within namespace."
EOF