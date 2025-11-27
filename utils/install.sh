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

    # Fetch latest minirootfs from latest-releases.yaml (works for both edge and stable)
    echo "[+] Fetching latest release info..."
    LATEST_FILE=$(wget -qO- "${ALPINE_MIRROR}/${ALPINE_VERSION}/releases/x86_64/latest-releases.yaml" | grep 'file:.*alpine-minirootfs.*x86_64.tar.gz' | head -1 | sed 's/.*file: //')

    if [ -z "$LATEST_FILE" ]; then
        echo "Error: Could not determine latest minirootfs file!"
        exit 1
    fi

    MINIROOTFS_URL="${ALPINE_MIRROR}/${ALPINE_VERSION}/releases/x86_64/${LATEST_FILE}"
    CHECKSUM_URL="${MINIROOTFS_URL}.sha256"

    echo "[+] Downloading: $LATEST_FILE"
    if ! wget "$MINIROOTFS_URL" -O tmp.tar.gz; then
        echo "Error: Download failed!"
        exit 1
    fi

    echo "[+] Downloading checksum..."
    if ! wget "$CHECKSUM_URL" -O tmp.tar.gz.sha256; then
        echo "Warning: Checksum download failed, skipping verification"
    else
        echo "[+] Verifying checksum..."
        # Extract expected checksum and verify
        EXPECTED_SUM=$(cut -d' ' -f1 tmp.tar.gz.sha256)
        ACTUAL_SUM=$(sha256sum tmp.tar.gz | cut -d' ' -f1)

        if [ "$EXPECTED_SUM" != "$ACTUAL_SUM" ]; then
            echo "Error: Checksum verification failed!"
            echo "  Expected: $EXPECTED_SUM"
            echo "  Actual:   $ACTUAL_SUM"
            rm -f tmp.tar.gz tmp.tar.gz.sha256
            exit 1
        fi
        echo "[+] Checksum verified successfully"
        rm tmp.tar.gz.sha256
    fi

    echo "[+] Extracting..."
    if ! tar xzf tmp.tar.gz -C "$ALPF_DIR"; then
        echo "Error: Extraction failed!"
        rm tmp.tar.gz
        exit 1
    fi

    rm tmp.tar.gz
    echo "[+] Alpine installation complete."
else
    echo "[+] Skipping setup/install."
fi