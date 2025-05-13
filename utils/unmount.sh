#!/bin/bash
#HL#utils/unmount.sh#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MNT_DIR="$SCRIPT_DIR/../alpinestein_mnt"  # Path to the mount directory

echo "[-] Unmounting virtual filesystems from $MNT_DIR..."

# Unshare the mount namespace for unmounting (in the same context)
unshare --mount --fork bash <<EOF

# Check if mounts are active and unmount them uno a uno
if mountpoint -q "$MNT_DIR/var"; then
  umount "$MNT_DIR/var" || { echo "Failed to unmount /var"; exit 1; }
fi

if mountpoint -q "$MNT_DIR/tmp"; then
  umount "$MNT_DIR/tmp" || true
fi

if mountpoint -q "$MNT_DIR/run"; then
  umount "$MNT_DIR/run" || true
fi

if mountpoint -q "$MNT_DIR/sys"; then
  umount "$MNT_DIR/sys" || true
fi

if mountpoint -q "$MNT_DIR/proc"; then
  umount "$MNT_DIR/proc" || true
fi

if mountpoint -q "$MNT_DIR/dev"; then
  umount "$MNT_DIR/dev" || true
fi

echo "[-] Unmounting complete within namespace."
EOF
