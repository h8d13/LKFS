#!/bin/sh
# bootstrap.sh - Create bootable disk from within LKFS
set -e

echo "[+] Bootstrapping LKFS to bootable system..."

# Install required packages for host system
apk update
apk add linux-lts linux-firmware-none acpi mkinitfs grub grub-bios parted e2fsprogs util-linux

TARGET="/tmp/bootable-lkfs"
IMAGE_FILE="/tmp/lkfs-bootable.img"
IMAGE_SIZE="512M"
LOOP_DEV=""

# Cleanup function
cleanup() {
    echo "[+] Cleaning up..."
    # Unmount chroot mounts
    umount "$TARGET/sys" 2>/dev/null || true
    umount "$TARGET/proc" 2>/dev/null || true
    umount "$TARGET/dev/pts" 2>/dev/null || true
    umount "$TARGET/dev" 2>/dev/null || true
    
    # Unmount image
    umount /mnt 2>/dev/null || true
    
    # Remove loop device
    if [ -n "$LOOP_DEV" ] && [ -b "$LOOP_DEV" ]; then
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
    
    # Clean up directories
    rm -rf "$TARGET"
}
trap cleanup EXIT

# Create target directory with full Alpine structure
rm -rf "$TARGET"
mkdir -p "$TARGET"
mkdir -p "$TARGET"/{boot,dev,etc,home,lib,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var}
mkdir -p "$TARGET"/etc/{apk/keys,init.d,conf.d,network,profile.d}
mkdir -p "$TARGET"/dev/pts
mkdir -p "$TARGET"/usr/{bin,lib,sbin,share}
mkdir -p "$TARGET"/var/{cache,lib,log,run,spool,tmp}

# Copy repository configuration first
echo "[+] Setting up APK configuration..."
cp /etc/apk/repositories "$TARGET/etc/apk/repositories"
cp /etc/apk/keys/* "$TARGET/etc/apk/keys/"

# Set up basic chroot environment BEFORE package installation
echo "[+] Setting up chroot environment..."
mount --bind /dev "$TARGET/dev"
mount --bind /proc "$TARGET/proc"
mount --bind /sys "$TARGET/sys"

# Create a temporary script to run package installation with error handling
cat > /tmp/install_packages.sh << 'EOF'
#!/bin/sh
set -e
cd /tmp/bootable-lkfs

# Initialize APK database
/sbin/apk --root . --initdb --quiet add

# Add packages one by one to better handle errors
echo "[+] Installing base system..."
/sbin/apk --root . --quiet add alpine-base || exit 1

echo "[+] Installing kernel..."
/sbin/apk --root . --quiet add linux-lts || exit 1

echo "[+] Installing boot tools..."
/sbin/apk --root . --quiet add mkinitfs || exit 1

echo "[+] Installing system tools..."
/sbin/apk --root . --quiet add acpi util-linux || exit 1

echo "[+] Installing SSH..."
/sbin/apk --root . --quiet add openssh || exit 1

# Install GRUB last and handle the error gracefully
echo "[+] Installing GRUB (may show device errors - this is normal)..."
/sbin/apk --root . --quiet add grub 2>/dev/null || {
    echo "[!] GRUB installation had warnings (expected in chroot)"
    # The package is still installed, just the trigger failed
}

echo "[+] Package installation complete"
EOF

chmod +x /tmp/install_packages.sh
/tmp/install_packages.sh
rm /tmp/install_packages.sh

# Copy LKFS customizations
echo "[+] Applying LKFS customizations..."
cp /root/.ashrc "$TARGET/root/.ashrc" 2>/dev/null || true
mkdir -p "$TARGET/etc/profile.d"
cp /etc/profile.d/* "$TARGET/etc/profile.d/" 2>/dev/null || true

# System configuration
echo "[+] Configuring system..."
cat > "$TARGET/etc/fstab" << 'EOF'
/dev/sda1 / ext4 defaults,noatime 1 1
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF

cp /etc/resolv.conf "$TARGET/etc/resolv.conf"
echo "lkfs-bootable" > "$TARGET/etc/hostname"

# Network configuration
cat > "$TARGET/etc/network/interfaces" << 'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Configure system services in chroot
echo "[+] Configuring system services..."
chroot "$TARGET" /bin/sh << 'CHROOT_EOF'
# Enable basic services
rc-update add devfs sysinit
rc-update add dmesg sysinit  
rc-update add mdev sysinit
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add networking boot
rc-update add sshd default

# Set root password
echo "root:alpine" | chpasswd

# Create a regular user
adduser -D -s /bin/sh user
echo "user:user" | chpasswd

# Generate initramfs
echo "[+] Generating initramfs..."
mkinitfs $(ls /lib/modules/ | head -1)
CHROOT_EOF

# Create disk image
echo "[+] Creating bootable disk image ($IMAGE_SIZE)..."
rm -f "$IMAGE_FILE"

# Convert size to MB number
SIZE_MB=$(echo "$IMAGE_SIZE" | sed 's/[MB]*$//')
echo "[+] Creating ${SIZE_MB}MB image..."

dd if=/dev/zero of="$IMAGE_FILE" bs=1M count="$SIZE_MB" status=progress

# Verify the image was created
if [ ! -f "$IMAGE_FILE" ] || [ ! -s "$IMAGE_FILE" ]; then
    echo "[!] Error: Failed to create disk image"
    exit 1
fi

echo "[+] Created disk image: $(ls -lh "$IMAGE_FILE" | awk '{print $5}')"

# Partition the disk
echo "[+] Partitioning disk..."
parted -s "$IMAGE_FILE" mklabel msdos
parted -s "$IMAGE_FILE" mkpart primary ext4 2048s 100%
parted -s "$IMAGE_FILE" set 1 boot on

# Setup loop device
echo "[+] Setting up loop device..."
LOOP_DEV=$(losetup -f --show -P "$IMAGE_FILE")
echo "[+] Using loop device: $LOOP_DEV"

# Wait for partition device to appear
sleep 2
PART_DEV="${LOOP_DEV}p1"
if [ ! -b "$PART_DEV" ]; then
    echo "[!] Partition device $PART_DEV not found, trying partprobe..."
    partprobe "$LOOP_DEV" 2>/dev/null || true
    sleep 2
fi

if [ ! -b "$PART_DEV" ]; then
    echo "[!] Error: Partition device $PART_DEV still not available"
    ls -la "$LOOP_DEV"* || true
    exit 1
fi

# Format and mount
echo "[+] Formatting partition..."
mkfs.ext4 -F "$PART_DEV"
mkdir -p /mnt
mount "$PART_DEV" /mnt

# Copy system to disk
echo "[+] Copying system to disk image..."
cp -a "$TARGET"/* /mnt/

# Ensure proper mounts for GRUB installation
echo "[+] Setting up final chroot for GRUB..."
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc  
mount --bind /sys /mnt/sys

# Install GRUB
echo "[+] Installing GRUB bootloader..."
chroot /mnt grub-install --target=i386-pc --boot-directory=/boot "$LOOP_DEV"

# Generate GRUB config
echo "[+] Generating GRUB configuration..."
cat > /mnt/boot/grub/grub.cfg << 'EOF'
set timeout=5
set default=0

menuentry "LKFS Alpine Linux" {
    linux /boot/vmlinuz-lts root=/dev/sda1 console=tty0 console=ttyS0,115200n8
    initrd /boot/initramfs-lts
}
EOF

# Final verification
echo "[+] Verifying bootable image..."
if [ -f "/mnt/boot/vmlinuz-lts" ] && [ -f "/mnt/boot/initramfs-lts" ]; then
    echo "[+] ✓ Kernel and initramfs found"
else
    echo "[!] ✗ Missing kernel or initramfs"
fi

if [ -f "/mnt/boot/grub/grub.cfg" ]; then
    echo "[+] ✓ GRUB configuration found"
else
    echo "[!] ✗ Missing GRUB configuration"
fi

# Cleanup will be handled by trap
echo "[+] Bootable LKFS created successfully: $IMAGE_FILE"
echo "[+] Size: $(du -h "$IMAGE_FILE" | cut -f1)"
echo "[+] Test with: qemu-system-x86_64 -hda $IMAGE_FILE -m 512M -serial stdio"