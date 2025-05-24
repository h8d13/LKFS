#!/bin/sh
set -e

ALPF_DIR="$1"
ALPINE_VERSION="3.21"
ALPINE_RELEASE="3.21.3"
ARCH="x86_64"

if [ ! -d "$ALPF_DIR" ]; then
    echo "[+] Downloading Alpine Linux minirootfs..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download with error checking
    ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/alpine-minirootfs-${ALPINE_RELEASE}-${ARCH}.tar.gz"
    
    if command -v curl >/dev/null; then
        curl -fsSL "$ALPINE_URL" -o alpine.tar.gz
    elif command -v wget >/dev/null; then
        wget -O alpine.tar.gz "$ALPINE_URL"
    else
        echo "Error: Neither curl nor wget found!"
        exit 1
    fi
    
    # Extract to target directory
    mkdir -p "$ALPF_DIR"
    tar xzf alpine.tar.gz -C "$ALPF_DIR"
    
    # Cleanup
    cd - >/dev/null
    rm -rf "$TEMP_DIR"
    
    echo "[+] Alpine Linux installation complete."
else
    echo "[+] Alpine Linux already installed, skipping download."
fi