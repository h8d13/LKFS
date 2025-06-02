#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ALPF_DIR="$SCRIPT_DIR/../alpinestein"
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"
MODS_DIR="$SCRIPT_DIR/../assets/mods"

# This script runs inside the unshared mount namespace
echo "[+] Setting up isolated chroot environment..."

# Mount filesystems
"$SCRIPT_DIR/mount.sh"

# Configure the chroot environment
cp "$SCRIPT_DIR/../assets/config.conf" "$ROOT_DIR/.ashrc"
chmod +x "$SCRIPT_DIR/../assets/profile.sh" && "$SCRIPT_DIR/../assets/profile.sh" "$ROOT_DIR"
cp /etc/resolv.conf "$ALPF_DIR/etc/resolv.conf"

# Setup profile scripts
cat "$SCRIPT_DIR/../assets/issue.ceauron" > "$PRO_D_DIR/logo.sh" && chmod +x "$PRO_D_DIR/logo.sh"
cp "$MODS_DIR/welcome.sh" "$PRO_D_DIR/welcome.sh" && chmod +x "$PRO_D_DIR/welcome.sh"
cp "$MODS_DIR/version.sh" "$PRO_D_DIR/version.sh" && chmod +x "$PRO_D_DIR/version.sh"

# Enter chroot as login
echo "[+] Entering Alpine chroot environment..."
chroot "$ALPF_DIR" /bin/sh -c ". /root/.profile; exec /bin/sh -l"