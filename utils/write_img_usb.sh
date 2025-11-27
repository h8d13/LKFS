#!/bin/bash
#HL#utils/write_img_usb.sh#
# Write bootable Alpine image to USB and create data partition

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

set -e

IMAGE_FILE="$1"
USB_DEVICE="$2"

if [ -z "$IMAGE_FILE" ] || [ -z "$USB_DEVICE" ]; then
    echo "Usage: $0 <image-file> <usb-device>"
    echo "Example: $0 alpine-boot.img /dev/sdb"
    exit 1
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo "Error: Image file '$IMAGE_FILE' not found!"
    exit 1
fi

if [ ! -b "$USB_DEVICE" ]; then
    echo "Error: Device '$USB_DEVICE' is not a block device!"
    exit 1
fi

echo "==================================="
echo "USB Image Writer"
echo "==================================="
echo ""
echo "Image file: $IMAGE_FILE"
echo "Target device: $USB_DEVICE"
echo ""
echo "WARNING: This will DESTROY all data on $USB_DEVICE!"
echo "Press Ctrl+C to abort, or Enter to continue..."
read -r _

# Determine partition names (handles both /dev/sdX and /dev/nvmeXnY)
if echo "$USB_DEVICE" | grep -q "nvme"; then
    PART1="${USB_DEVICE}p1"
    PART2="${USB_DEVICE}p2"
else
    PART1="${USB_DEVICE}1"
    PART2="${USB_DEVICE}2"
fi

# Unmount any mounted partitions
echo "[1/2] Unmounting any mounted partitions..."
umount "${USB_DEVICE}"* 2>/dev/null || true

# Write the entire image to the disk
echo "[2/2] Writing Alpine system (entire image)..."

# Write the complete image file
dd if="$IMAGE_FILE" of="$USB_DEVICE" bs=4M status=progress oflag=sync
sync

echo ""
echo "==================================="
echo "✓ USB drive ready!"
echo "==================================="
echo ""
echo "Partitions:"
echo "  $PART1 - EFI Boot"
echo "  $PART2 - Alpine Root System"
echo ""

