#!/bin/sh
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

ALPF_DIR="alpinestein"
# Magic reset/update line
#rm -rf alpinestein
# Install Alpine if needed
chmod +x ./utils/install.sh && ./utils/install.sh "$ALPF_DIR"
mkdir -p "$ALPF_DIR/root" "$ALPF_DIR/etc/profile.d"

# Launch in isolated mount namespace (cleanup handled inside)
echo "[+] Creating isolated mount namespace..."
chmod +x ./utils/chroot_launcher.sh && unshare --mount --propagation slave ./utils/chroot_launcher.sh

echo "[+] Exited chroot environment. Namespace cleanup completed automatically."