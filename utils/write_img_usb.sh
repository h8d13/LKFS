#!/bin/bash
#HL#utils/write-to-usb.sh#
# Write Alpine UEFI bootable image to USB and create data partition with remaining space

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

IMAGE_FILE="${1}"

# Show available devices
echo "==================================="
echo "Available block devices:"
echo "==================================="
lsblk
echo ""

# Prompt for target device
read -r -p "Enter target device (e.g., /dev/sdX): " TARGET_DEVICE

if [ -z "$TARGET_DEVICE" ]; then
    echo "Error: No device specified!"
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
read -r -p "Continue? [y/N]: " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Unmount any mounted partitions
echo ""
echo "[1/5] Unmounting any mounted partitions..."
umount "${TARGET_DEVICE}"* 2>/dev/null || true

# Write the image
echo ""
echo "[2/5] Writing image to $TARGET_DEVICE..."
dd if="$IMAGE_FILE" of="$TARGET_DEVICE" bs=4M status=progress conv=fsync

# Sync and wait
sync
sleep 2

# Reload partition table
echo ""
echo "[3/6] Reloading partition table..."
partprobe "$TARGET_DEVICE" #devnull
sleep 1

# Create data partition with remaining space
echo ""
echo "[4/5] Creating data partition with remaining space..."

# Get the size of the USB device in sectors
DISK_SIZE=$(blockdev --getsz "$TARGET_DEVICE")
# Get image size in bytes, convert to sectors (512 bytes each)
IMAGE_SIZE=$(stat -c%s "$IMAGE_FILE")
IMAGE_SECTORS=$((IMAGE_SIZE / 512))

echo "  Disk: $DISK_SIZE sectors"
echo "  Image: $IMAGE_SECTORS sectors"
echo "  Available: $((DISK_SIZE - IMAGE_SECTORS)) sectors"

# Create a new partition using the remaining space (fdisk will auto-start after partition 2)
echo -e "n\np\n3\n\n\nw" | fdisk "$TARGET_DEVICE" >/dev/null 2>&1 || true
sync

# Reload partition table
partprobe "$TARGET_DEVICE"
sleep 2

# Format the data partition
echo ""
echo "[5/5] Formatting data partition..."
# Determine the partition device name (partition 3)
if echo "$TARGET_DEVICE" | grep -q 'nvme\|mmcblk'; then
    DATA_PART="${TARGET_DEVICE}p3"
else
    DATA_PART="${TARGET_DEVICE}3"
fi

mkfs.ext4 -F -L "ALPINE_DATA" "$DATA_PART"

echo ""
echo "==================================="
echo "✓ USB drive ready!"
echo "==================================="
echo ""
lsblk "$TARGET_DEVICE"
echo ""
echo "Partitions:"
echo "  ${TARGET_DEVICE}p1 or ${TARGET_DEVICE}1 - EFI System"
echo "  ${TARGET_DEVICE}p2 or ${TARGET_DEVICE}2 - Alpine Root"
echo "  $DATA_PART - Data (labeled ALPINE_DATA)"
echo ""

