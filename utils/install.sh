#!/bin/sh
#HL#utils/install.sh#
ALPF_DIR=$1
if [ ! -d "$ALPF_DIR" ]; then
    echo "[+] Init setup/install."
    mkdir -p "$ALPF_DIR"
    
    # Add error checking
    if ! wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.3-x86_64.tar.gz -O tmp.tar.gz; then
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