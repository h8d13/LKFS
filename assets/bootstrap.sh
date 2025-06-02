#!/bin/sh
# bootstrap.sh - Create bootable disk from within LKFS
set -e
echo "[+] Bootstrapping LKFS to bootable system..."
apk update
apk add linux-lts linux-firmware-none acpi mkinitfs grub grub-bios parted e2fsprogs

# Create target directory
TARGET="/tmp/bootable-lkfs"
mkdir -p "$TARGET"

# Copy repository configuration AND signing keys to target
mkdir -p "$TARGET/etc/apk/keys"
cp /etc/apk/repositories "$TARGET/etc/apk/repositories"
cp /etc/apk/keys/* "$TARGET/etc/apk/keys/"

# Bootstrap fresh Alpine base (cleaner than copying current chroot)
echo "[+] Creating clean Alpine base system..."
apk add --root "$TARGET" --initdb alpine-base linux-lts acpi mkinitfs

# Copy your custom LKFS configurations
echo "[+] Applying LKFS customizations..."
cp /root/.ashrc "$TARGET/root/.ashrc"
mkdir -p "$TARGET/etc/profile.d"
cp /etc/profile.d/* "$TARGET/etc/profile.d/" 2>/dev/null || true

# Basic system config
cat > "$TARGET/etc/fstab" << EOF
/dev/sda1 / ext4 defaults 1 1
tmpfs /tmp tmpfs defaults 0 0
EOF
cp /etc/resolv.conf "$TARGET/etc/resolv.conf"
echo "lkfs-bootable" > "$TARGET/etc/hostname"

# Create bootable disk
echo "[+] Creating bootable disk image..."
dd if=/dev/zero of=/tmp/lkfs-bootable.img bs=1M count=256

# Proper partitioning with enough space for GRUB
parted -s /tmp/lkfs-bootable.img mklabel msdos
parted -s /tmp/lkfs-bootable.img mkpart primary ext4 2048s 100%
parted -s /tmp/lkfs-bootable.img set 1 boot on

# **FIX: BusyBox-compatible loop device setup**
LOOP_DEV=$(losetup -f)
losetup -P "$LOOP_DEV" /tmp/lkfs-bootable.img
echo "[+] Using loop device: $LOOP_DEV"

# Format and mount the partition
mkfs.ext4 "${LOOP_DEV}p1"
mount "${LOOP_DEV}p1" /mnt

# Copy system
echo "[+] Copying system to disk image..."
cp -a "$TARGET"/* /mnt/

# Proper GRUB installation for loop devices
# Mount virtual filesystems for chroot
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys

# Create device map for GRUB
mkdir -p /mnt/boot/grub
cat > /mnt/boot/grub/device.map << EOF
(hd0) $LOOP_DEV
EOF

echo "[+] Installing GRUB..."
# Install GRUB with proper modules for MBR/MSDOS partition support
chroot /mnt grub-install --target=i386-pc --modules="part_msdos ext2" --boot-directory=/boot "$LOOP_DEV"

echo "[+] Generating GRUB configuration..."
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Configure services in the target system
chroot /mnt /bin/sh << 'CHROOT_EOF'
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add networking boot
mkinitfs $(ls /lib/modules/)
CHROOT_EOF

# Cleanup
umount /mnt/sys /mnt/proc /mnt/dev /mnt
losetup -d "$LOOP_DEV"

echo "[+] Bootable LKFS created: /tmp/lkfs-bootable.img"
echo "[+] Size: $(du -h /tmp/lkfs-bootable.img | cut -f1)"