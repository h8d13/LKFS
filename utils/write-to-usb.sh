#!/bin/sh
# Write Alpine UEFI bootable image to USB and create data partition with remaining space

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

IMAGE_FILE="${1}"
TARGET_DEVICE="${2}"

if [ -z "$IMAGE_FILE" ] || [ -z "$TARGET_DEVICE" ]; then
    echo "Usage: $0 <image-file> <target-device>"
    echo "Example: $0 alpine-boot.img /dev/sdb"
    echo ""
    echo "Available devices:"
    lsblk -d -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: Image file '$IMAGE_FILE' not found!"
    exit 1
fi

if [ ! -b "$TARGET_DEVICE" ]; then
    echo "Error: '$TARGET_DEVICE' is not a valid block device!"
    exit 1
fi

# Safety check - make sure it's not a system disk
if echo "$TARGET_DEVICE" | grep -qE '(sda|nvme0n1|mmcblk0)$'; then
    echo "WARNING: $TARGET_DEVICE looks like a system disk!"
    read -p "Are you ABSOLUTELY sure you want to continue? [yes/NO]: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "==================================="
echo "Alpine USB Writer (UEFI)"
echo "==================================="
echo ""
echo "Image: $IMAGE_FILE"
echo "Target: $TARGET_DEVICE"
echo ""
lsblk "$TARGET_DEVICE"
echo ""
echo "WARNING: This will ERASE all data on $TARGET_DEVICE!"
read -p "Continue? [y/N]: " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Unmount any mounted partitions
echo ""
echo "[1/5] Unmounting any mounted partitions..."
umount ${TARGET_DEVICE}* 2>/dev/null || true

# Write the image
echo ""
echo "[2/5] Writing image to $TARGET_DEVICE..."
dd if="$IMAGE_FILE" of="$TARGET_DEVICE" bs=4M status=progress conv=fsync

# Sync and wait
sync
sleep 2

# Reload partition table
echo ""
echo "[3/5] Reloading partition table..."
partprobe "$TARGET_DEVICE"
sleep 1

# GPT: EFI partition (1) + Root partition (2) = next is 3
NEXT_PART=3

# Create data partition with remaining space
echo ""
echo "[4/5] Creating data partition with remaining space..."
# Get the end of partition 2 (root partition)
LAST_END=$(parted -s "$TARGET_DEVICE" unit s print | grep "^ 2" | awk '{print $3}' | sed 's/s//')
START_SECTOR=$((LAST_END + 1))

parted -s "$TARGET_DEVICE" mkpart primary ext4 ${START_SECTOR}s 100%

# Reload partition table
partprobe "$TARGET_DEVICE"
sleep 2

# Format the data partition
echo ""
echo "[5/5] Formatting data partition..."
# Determine the partition device name
if echo "$TARGET_DEVICE" | grep -q 'nvme\|mmcblk'; then
    DATA_PART="${TARGET_DEVICE}p${NEXT_PART}"
else
    DATA_PART="${TARGET_DEVICE}${NEXT_PART}"
fi

mkfs.ext4 -L "ALPINE_DATA" "$DATA_PART"

echo ""
echo "==================================="
echo "✓ USB drive ready!"
echo "==================================="
echo ""
lsblk "$TARGET_DEVICE"
echo ""
echo "Partitions:"
echo "  ${TARGET_DEVICE}p1 (or ${TARGET_DEVICE}1) - EFI System"
echo "  ${TARGET_DEVICE}p2 (or ${TARGET_DEVICE}2) - Alpine Root"
echo "  $DATA_PART - Data (labeled ALPINE_DATA)"
echo ""
echo "After booting Alpine, mount the data partition with:"
echo "  mkdir -p /mnt/data"
echo "  mount $DATA_PART /mnt/data"
echo ""
echo "Or add to /etc/fstab for automatic mounting:"
echo "  LABEL=ALPINE_DATA /mnt/data ext4 defaults 0 2"
echo ""
