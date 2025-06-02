#!/bin/sh
# bootstrap.sh - Create bootable disk from within LKFS
set -e

echo "[+] Bootstrapping LKFS to bootable system..."
apk update
apk add linux-lts linux-firmware-none acpi mkinitfs grub grub-bios parted e2fsprogs

# Create target directory 
TARGET="/tmp/bootable-lkfs"
mkdir -p "$TARGET"

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

# Mount and configure services
for a in proc sys dev; do 
    mkdir -p "$TARGET/$a"
    mount -o bind "/$a" "$TARGET/$a"
done

chroot "$TARGET" /bin/sh << 'CHROOT_EOF'
rc-update add devfs sysinit
rc-update add dmesg sysinit  
rc-update add mdev sysinit
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add networking boot
mkinitfs $(ls /lib/modules/)
CHROOT_EOF

# Create bootable disk
echo "[+] Creating bootable disk image..."
dd if=/dev/zero of=/tmp/lkfs-bootable.img bs=1M count=256
parted -s /tmp/lkfs-bootable.img mklabel msdos
parted -s /tmp/lkfs-bootable.img mkpart primary ext4 1MiB 100%
parted -s /tmp/lkfs-bootable.img set 1 boot on

LOOP_DEV=$(losetup --show -fP /tmp/lkfs-bootable.img)
mkfs.ext4 "${LOOP_DEV}p1"
mount "${LOOP_DEV}p1" /mnt

# Copy system and install GRUB
cp -a "$TARGET"/* /mnt/
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc  
mount --bind /sys /mnt/sys

chroot /mnt grub-install --target=i386-pc "$LOOP_DEV"
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Cleanup
umount /mnt/sys /mnt/proc /mnt/dev /mnt
losetup -d "$LOOP_DEV"
for a in proc sys dev; do umount "$TARGET/$a" 2>/dev/null || true; done

echo "[+] Bootable LKFS created: /tmp/lkfs-bootable.img"
echo "[+] Size: $(du -h /tmp/lkfs-bootable.img | cut -f1)"
