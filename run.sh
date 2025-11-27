#!/bin/sh
# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

ALPF_DIR="alpinestein"

# Handle --reset flag
if [ "$1" = "--reset" ]; then
    echo "[+] Removing LKFS..."
    rm -rf "$ALPF_DIR"
    shift
fi

# Install Alpine if needed
echo "[+] Installing LKFS..."
chmod +x ./utils/install.sh && ./utils/install.sh "$ALPF_DIR"

# Launch in isolated mount namespace (cleanup handled inside)
echo "[+] Creating isolated mount namespace..."
chmod +x ./utils/chroot_launcher.sh && unshare --mount --propagation "$@" ./utils/chroot_launcher.sh

#examples see unshare manpage
#sudo ./run.sh (--reset) shared | slave | private
#--fork 
#--uts --hostname alpine-test 
#--user --map-root-user 
#--pid
#--net 
#--ipc

echo "[+] Exited chroot environment. Namespace cleanup completed automatically."