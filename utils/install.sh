#!/bin/bash
#HL#utils/install.sh#
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../ALPM-FS.conf"

# Source config if exists
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=../ALPM-FS.conf
    # shellcheck disable=SC1091
    . "$CONFIG_FILE"
fi

ALPF_DIR=$1
if [ ! -d "$ALPF_DIR" ]; then
    echo "[+] Init setup/install."
    mkdir -p "$ALPF_DIR"

    # Construct download URL
    MINIROOTFS_URL="${ALPINE_MIRROR}/${ALPINE_VERSION}/releases/x86_64/alpine-minirootfs-${ALPINE_VERSION#v}.0-x86_64.tar.gz"
    echo "[+] Downloading from: $MINIROOTFS_URL"

    # Add error checking
    if ! wget "$MINIROOTFS_URL" -O tmp.tar.gz; then
        echo "Error: Download failed!"
        exit 1
    fi
    
    if ! tar xzf tmp.tar.gz -C "$ALPF_DIR"; then
        echo "Error: Extraction failed!"
        exit 1
    fi
    
    rm tmp.tar.gz
    echo "[+] Alpine installation complete."
else
    echo "[+] Skipping setup/install."
fi