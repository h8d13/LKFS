#!/bin/sh
set -e

ALPF_DIR="alpinestein"
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"
MODS_DIR="assets/mods"

# Cleanup function
cleanup() {
    echo "[+] Cleaning up..."
    chmod +x ./utils/unmount.sh && ./utils/unmount.sh
}
trap cleanup EXIT

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

# Install Alpine if needed
chmod +x ./utils/install.sh && ./utils/install.sh "$ALPF_DIR"

# Mount filesystems
chmod +x ./utils/mount.sh && ./utils/mount.sh

# Configure the chroot environment
cp assets/config.conf "$ROOT_DIR/.ashrc"
chmod +x ./assets/profile.sh && ./assets/profile.sh "$ROOT_DIR"
cp /etc/resolv.conf "$ALPF_DIR/etc/resolv.conf"

# Setup profile scripts
mkdir -p "$PRO_D_DIR"
cat assets/issue.ceauron > "$PRO_D_DIR/logo.sh" && chmod +x "$PRO_D_DIR/logo.sh"
cp "$MODS_DIR/welcome.sh" "$PRO_D_DIR/welcome.sh" && chmod +x "$PRO_D_DIR/welcome.sh"
cp "$MODS_DIR/version.sh" "$PRO_D_DIR/version.sh" && chmod +x "$PRO_D_DIR/version.sh"

# Enter chroot
echo "[+] Entering Alpine chroot environment..."
chroot "$ALPF_DIR" /bin/sh -c ". /root/.profile; exec /bin/sh -l"