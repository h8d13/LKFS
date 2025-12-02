#!/bin/sh
# Sway mod - meant to be run as user: installs elogind, and adds to groups
# doas
set -e

USER="${DOAS_USER:-$1}"

# Install elogind
echo "[MOD] Installing elogind..."
apk add elogind

# Enable elogind service
echo "[MOD] Enabling elogind service..."
rc-update add elogind boot

echo "[MOD] Setting up Sway..."
setup-desktop sway

echo "[MOD] Copying default sway files..."
mkdir -p /home/"$USER"/.config/sway
cp /etc/sway/config /home/"$USER"/.config/sway/

chown -R "$USER":"$USER" "/home/$USER/.config"

# Add user to required groups
echo "[MOD] Adding $USER to groups: input, video, seat, audio..."
for group in input video seat audio; do
    # Create group if it doesn't exist
    if ! getent group "$group" >/dev/null 2>&1; then
        addgroup "$group"
    fi
    adduser "$USER" "$group"
done

apk add alsaconf alsa-utils sof-firmware
rc-update add alsa
