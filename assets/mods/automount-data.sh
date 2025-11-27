#!/bin/sh
# Auto-mount ALPINE_DATA partition if it exists

DATA_MOUNT="/mnt/data"
DATA_LABEL="ALPINE_DATA"

# Check if ALPINE_DATA partition exists
if blkid -L "$DATA_LABEL" >/dev/null 2>&1; then
    # Create mount point if it doesn't exist
    mkdir -p "$DATA_MOUNT"

    # Mount the data partition
    if ! mountpoint -q "$DATA_MOUNT"; then
        mount LABEL="$DATA_LABEL" "$DATA_MOUNT" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Mounted $DATA_LABEL at $DATA_MOUNT"
        fi
    fi
fi
