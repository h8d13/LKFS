#!/bin/bash
#HL#utils/create-bootable-image.sh#
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

# Source configuration file
CONFIG_FILE="$SCRIPT_DIR/../ALPM-FS.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo "[+] Loading configuration from ALPM-FS.conf"
    # shellcheck source=../ALPM-FS.conf
    # shellcheck disable=SC1091
    . "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at $CONFIG_FILE"
    exit 1
fi

echo "==================================="
echo "Bootable Alpine Image Creator (UEFI)"
echo "==================================="
echo ""
echo "Creating: $IMAGE_FILE"
echo "Size: $IMAGE_SIZE"
echo ""
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
EFI_END=$((EFI_SIZE + 1))
parted -s "$LOOP_DEV" mklabel gpt
parted -s "$LOOP_DEV" mkpart primary fat32 1MiB ${EFI_END}MiB
parted -s "$LOOP_DEV" set 1 esp on
parted -s "$LOOP_DEV" mkpart primary "${ROOT_FS_TYPE}" "${EFI_END}MiB" 100%

# Reload partition table
partprobe "$LOOP_DEV"
sleep 1

# Format partitions
echo "[4/7] Formatting partitions..."
EFI_PART="${LOOP_DEV}p1"
PART_DEV="${LOOP_DEV}p2"
mkfs.vfat -F32 "$EFI_PART"

# Format root partition based on ROOT_FS_TYPE
case "$ROOT_FS_TYPE" in
    ext4)
        mkfs.ext4 -F "$PART_DEV"
        ;;
    xfs)
        mkfs.xfs -f "$PART_DEV"
        ;;
    btrfs)
        mkfs.btrfs -f "$PART_DEV"
        ;;
    f2fs)
        mkfs.f2fs -f "$PART_DEV"
        ;;
    *)
        echo "Error: Unsupported filesystem type: $ROOT_FS_TYPE"
        exit 1
        ;;
esac

# Mount and copy system
echo "[5/7] Copying Alpine system..."
mkdir -p /mnt/alpine-img
mount "$PART_DEV" /mnt/alpine-img
cp -a "$CHROOT"/* /mnt/alpine-img/

# Mount EFI partition and create symlink so kernel installs there
mkdir -p /mnt/alpine-img/efi
mount "$EFI_PART" /mnt/alpine-img/efi
ln -sf /efi /mnt/alpine-img/boot

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
    cat > /mnt/alpine-img/etc/apk/repositories <<REPOS
${ALPINE_MIRROR}/${ALPINE_VERSION}/main
${ALPINE_MIRROR}/${ALPINE_VERSION}/community
REPOS
fi

# Install packages and bootloader
chroot /mnt/alpine-img /bin/sh <<CHROOT_CMD
. /root/.profile 2>/dev/null || true
apk update
apk add $CORE_PACKAGES
apk add --no-scripts $BOOT_PACKAGES
apk add $SYSTEM_PACKAGES
apk add $EXTRA_PACKAGES
CHROOT_CMD

# Configure boot services (same for both modes)
chroot /mnt/alpine-img /bin/sh <<CHROOT_CMD
. /root/.profile 2>/dev/null || true

# Configure boot services
for service in $SERVICES_SYSINIT; do
    rc-update add \$service sysinit
done

for service in $SERVICES_BOOT; do
    rc-update add \$service boot
done

for service in $SERVICES_SHUTDOWN; do
    rc-update add \$service shutdown
done

for service in $SERVICES_DEFAULT; do
    rc-update add \$service default
done

# Configure zram for swap
cat > /etc/conf.d/zram-init <<-ZRAMCONF
	load_on_start=yes
	unload_on_stop=yes
	num_devices=1
	type0=swap
	size0=$ZRAM_SIZE
	algo0=$ZRAM_ALGO
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

# Install GRUB from outside chroot (needs access to loop device)
echo "[*] Installing GRUB bootloader..."
grub-install --target=x86_64-efi --efi-directory=/mnt/alpine-img/efi \
             --boot-directory=/mnt/alpine-img/efi --bootloader-id=Alpine \
             --removable --no-nvram

# Generate GRUB config
echo "[*] Generating GRUB configuration..."
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")

# Build kernel cmdline based on filesystem type
case "$ROOT_FS_TYPE" in
    ext4)
        FS_MODULES="modules=ext4"
        ;;
    xfs)
        FS_MODULES="modules=xfs"
        ;;
    btrfs)
        FS_MODULES="modules=btrfs"
        ;;
    f2fs)
        FS_MODULES="modules=f2fs"
        ;;
    *)
        FS_MODULES=""
        ;;
esac

KERNEL_CMDLINE="rootfstype=$ROOT_FS_TYPE $FS_MODULES $KERNEL_CMDLINE_EXTRA"

cat > /mnt/alpine-img/efi/grub/grub.cfg <<GRUBCFG
set timeout=$GRUB_TIMEOUT
set default=0

menuentry "Alpine Linux" {
    linux /vmlinuz-lts root=UUID=$PART_UUID $KERNEL_CMDLINE
    initrd /initramfs-lts
}
GRUBCFG

# Unmount EFI partition
umount /mnt/alpine-img/efi

# Set hostname
echo "[*] Setting hostname..."
echo "$HOSTNAME" > /mnt/alpine-img/etc/hostname

# Create network interfaces configuration
echo "[*] Configuring network interfaces..."
cat > /mnt/alpine-img/etc/network/interfaces <<NETCONF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
NETCONF

# Set root password in chroot
echo "[*] Setting root password..."
chroot /mnt/alpine-img /bin/sh <<CHROOT_CMD
. /root/.profile 2>/dev/null || true
echo "root:$ROOT_PASSWORD" | chpasswd
CHROOT_CMD

# Generate fstab
echo "[7/7] Generating fstab..."
PART_UUID=$(blkid -s UUID -o value "$PART_DEV")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
cat > /mnt/alpine-img/etc/fstab <<EOF
UUID=$PART_UUID / $ROOT_FS_TYPE $ROOT_FS_OPTS 0 1
UUID=$EFI_UUID /efi vfat defaults 0 2
tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0
EOF

# Cleanup
umount /mnt/alpine-img/dev/pts
umount /mnt/alpine-img/dev
umount /mnt/alpine-img/sys
umount /mnt/alpine-img/proc

# Remove the /boot symlink we created for installation
rm /mnt/alpine-img/boot

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
