#!/bin/sh
# simplified-bootstrap.sh - Create Alpine Linux system following official method
set -e

echo "[+] Bootstrapping Alpine Linux system..."

# Download apk.static if not present
if [ ! -f "./apk.static" ]; then
    echo "[+] Downloading apk.static..."
    wget https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/v2.14.6/x86_64/apk.static
    chmod +x apk.static
fi

# Create target directory
TARGET="/tmp/target"
mkdir -p "$TARGET"

echo "[+] Installing Alpine base system..."
./apk.static --arch $(arch) -X https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/ -U --allow-untrusted --root "$TARGET" --initdb add alpine-base

echo "[+] Configuring system files..."

# Configure fstab
cat > "$TARGET/etc/fstab" << EOF
/dev/sda1 / ext4 rw,relatime 0 1
tmpfs /tmp tmpfs defaults 0 0
EOF

# Configure inittab (use default, but ensure it exists)
if [ ! -f "$TARGET/etc/inittab" ]; then
    cp /etc/inittab "$TARGET/etc/inittab" 2>/dev/null || echo "::sysinit:/sbin/rc sysinit" > "$TARGET/etc/inittab"
fi

# Configure resolv.conf
cp /etc/resolv.conf "$TARGET/etc/resolv.conf"

echo "[+] Mounting proc/sys/dev..."
for a in proc sys dev; do 
    mkdir -p "$TARGET/$a"
    mount -o bind "/$a" "$TARGET/$a"
done

echo "[+] Chrooting and configuring system..."
chroot "$TARGET" /bin/sh << 'CHROOT_EOF'
# Setup hostname
echo "alpine-system" > /etc/hostname

# Setup basic networking
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Setup repositories
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/latest-stable/main
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF

# Update and add essential packages
apk update
apk add linux-lts linux-firmware-none acpi mkinitfs

# Add services to boot
rc-update add acpid default
rc-update add bootmisc boot
rc-update add crond default
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add hostname boot
rc-update add hwclock boot
rc-update add hwdrivers sysinit
rc-update add killprocs shutdown
rc-update add mdev sysinit
rc-update add modules boot
rc-update add mount-ro shutdown
rc-update add networking boot
rc-update add savecache shutdown
rc-update add seedrng boot
rc-update add swap boot

# Generate initramfs
mkinitfs $(ls /lib/modules/ | head -1)

echo "[+] Alpine Linux bootstrap complete!"
CHROOT_EOF

# Cleanup mounts
echo "[+] Cleaning up..."
for a in dev sys proc; do 
    umount "$TARGET/$a" 2>/dev/null || true
done

echo "[+] Alpine Linux system ready at: $TARGET"
