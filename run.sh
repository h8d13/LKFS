#!/bin/sh
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

ALPF_DIR="alpinestein"
# Magic reset/update line
rm -rf alpinestein
# Install Alpine if needed
chmod +x ./utils/install.sh && ./utils/install.sh "$ALPF_DIR"

# Launch in isolated mount namespace (cleanup handled inside)
echo "[+] Creating isolated mount namespace..."
chmod +x ./utils/chroot_launcher.sh && unshare --mount --propagation "$@" ./utils/chroot_launcher.sh

#examples see unshare manpage
#sudo ./run.sh shared | slave | private
# --fork --uts --hostname alpine-test --user --map-root-user --pid

echo "[+] Exited chroot environment. Namespace cleanup completed automatically."