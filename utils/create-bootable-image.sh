#!/bin/sh
# Create a bootable Alpine disk image (for VMs/testing)

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"
IMAGE_FILE="${1:-alpine-boot.img}"
IMAGE_SIZE="${2:-2G}"

echo "==================================="
echo "Bootable Alpine Image Creator (UEFI)"
echo "==================================="
echo ""
echo "Creating: $IMAGE_FILE"
echo "Size: $IMAGE_SIZE"
echo ""

# Ensure Alpine is installed first
if [ ! -d "$CHROOT" ] || [ ! -f "$CHROOT/bin/sh" ]; then
    echo "[0/7] Alpine not found. Installing Alpine first..."
    "$SCRIPT_DIR/install.sh" "$(dirname "$CHROOT")/alpinestein"
fi

# Verify critical files exist
if [ ! -f "$CHROOT/sbin/apk" ]; then
    echo "Error: Alpine installation is incomplete. /sbin/apk not found!"
    echo "Please run: sudo ./run.sh private"
    echo "Then exit and try again."
    exit 1
fi

# Create disk image
echo "[1/7] Creating disk image..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek="$IMAGE_SIZE" 2>/dev/null

# Setup loop device
echo "[2/7] Setting up loop device..."
LOOP_DEV=$(losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    mountpoint -q /mnt/alpine-img 2>/dev/null && umount -R /mnt/alpine-img
    losetup -d "$LOOP_DEV" 2>/dev/null || true
}
trap cleanup EXIT

# Partition the disk (GPT/UEFI only)
echo "[3/7] Creating GPT partition table..."
parted -s "$LOOP_DEV" mklabel gpt
parted -s "$LOOP_DEV" mkpart primary fat32 1MiB 512MiB
parted -s "$LOOP_DEV" set 1 esp on
parted -s "$LOOP_DEV" mkpart primary ext4 512MiB 100%

# Reload partition table
partprobe "$LOOP_DEV"
sleep 1

# Format partitions
echo "[4/7] Formatting partitions..."
EFI_PART="${LOOP_DEV}p1"
PART_DEV="${LOOP_DEV}p2"
mkfs.vfat -F32 "$EFI_PART"
mkfs.ext4 -F "$PART_DEV"

# Mount and copy system
echo "[5/7] Copying Alpine system..."
mkdir -p /mnt/alpine-img
mount "$PART_DEV" /mnt/alpine-img
cp -a "$CHROOT"/* /mnt/alpine-img/

# Setup for package installation
echo "[6/7] Installing kernel and bootloader..."
mount -t proc proc /mnt/alpine-img/proc
mount -t sysfs sysfs /mnt/alpine-img/sys
mount -t tmpfs tmpfs /mnt/alpine-img/dev -o mode=0755
mkdir -p /mnt/alpine-img/dev/pts
mount -t devpts devpts /mnt/alpine-img/dev/pts

cp /etc/resolv.conf /mnt/alpine-img/etc/resolv.conf

# Ensure /etc/apk/repositories exists
if [ ! -f /mnt/alpine-img/etc/apk/repositories ]; then
    mkdir -p /mnt/alpine-img/etc/apk
    cat > /mnt/alpine-img/etc/apk/repositories <<'REPOS'
https://dl-cdn.alpinelinux.org/alpine/v3.22/main
https://dl-cdn.alpinelinux.org/alpine/v3.22/community
REPOS
fi

# Install packages and bootloader
# Note: grub-probe triggers will fail in chroot (can't access /dev/loop), this is expected and harmless
chroot /mnt/alpine-img /bin/sh <<'CHROOT_CMD' || true
. /root/.profile 2>/dev/null || true
apk update
apk add linux-lts linux-firmware-none acpi mkinitfs
apk add grub grub-efi efibootmgr
apk add openrc openrc-init util-linux coreutils e2fsprogs dosfstools
apk add acpid busybox-openrc busybox-extras busybox-mdev-openrc
apk add alpine-conf kbd-bkeymaps kbd zram-init
CHROOT_CMD

# Configure boot services (same for both modes)
chroot /mnt/alpine-img /bin/sh <<'CHROOT_CMD'
. /root/.profile 2>/dev/null || true

# Configure boot services (from official Alpine guide)
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hwdrivers sysinit

rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot

rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown

rc-update add acpid default

# Enable zram (compressed swap in RAM)
rc-update add zram-init boot

# Configure zram for swap
cat > /etc/conf.d/zram-init <<'ZRAMCONF'
load_on_start=yes
unload_on_stop=yes
num_devices=1
type0=swap
size0=2048
algo0=zstd
ZRAMCONF

# Create inittab
cat > /etc/inittab <<'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
tty1::respawn:/sbin/getty 38400 tty1
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF

CHROOT_CMD

# Install GRUB from outside chroot (to avoid device detection issues)
echo "[*] Installing GRUB bootloader..."
# Mount EFI partition for GRUB installation
mkdir -p /mnt/alpine-img/efi
mount "$EFI_PART" /mnt/alpine-img/efi

grub-install --target=x86_64-efi --efi-directory=/mnt/alpine-img/efi \
             --boot-directory=/mnt/alpine-img/boot --bootloader-id=Alpine \
             --removable --no-nvram

# Generate GRUB config (hardcoded since grub-mkconfig fails in chroot)
echo "[*] Generating GRUB configuration..."
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")
cat > /mnt/alpine-img/boot/grub/grub.cfg <<GRUBCFG
set timeout=1
set default=0

menuentry "Alpine Linux" {
    linux /boot/vmlinuz-lts root=UUID=$PART_UUID rootfstype=ext4 modules=ext4 console=tty0
    initrd /boot/initramfs-lts
}
GRUBCFG

# Unmount EFI partition
umount /mnt/alpine-img/efi

# Set root password in chroot
echo "[*] Setting root password..."
chroot /mnt/alpine-img /bin/sh <<'CHROOT_CMD'
. /root/.profile 2>/dev/null || true
echo "root:alpine" | chpasswd
CHROOT_CMD

# Generate fstab
echo "[7/7] Generating fstab..."
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat > /mnt/alpine-img/etc/fstab <<EOF
UUID=$PART_UUID / ext4 rw,relatime 0 1
UUID=$EFI_UUID /efi vfat defaults 0 2
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF

# Cleanup
umount /mnt/alpine-img/dev/pts
umount /mnt/alpine-img/dev
umount /mnt/alpine-img/sys
umount /mnt/alpine-img/proc
umount /mnt/alpine-img

echo ""
echo "==================================="
echo "✓ Bootable image created!"
echo "==================================="
echo ""
echo "Image: $IMAGE_FILE"
echo "Boot mode: UEFI"
echo "Default root password: alpine"
echo ""
