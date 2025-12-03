#!/bin/bash
#HL#utils/create-bootable-image.sh#
# Create a bootable Alpine disk image

# ./utils/create_boot_img.sh [image_file] [image_size] [config_file]

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root!"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT="$SCRIPT_DIR/../alpinestein"
IMAGE_FILE="${1:-alpine-boot.img}"
IMAGE_SIZE="${2:-2G}"
CONFIG_FILE="${3:-$SCRIPT_DIR/../ALPM-FS.conf}"

# Source configuration file
if [ -f "$CONFIG_FILE" ]; then
    echo "[+] Loading configuration from $CONFIG_FILE"
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

# Check if Alpine base installation exists and has been configured
if [ ! -f "$CHROOT/sbin/apk" ]; then
    echo "Error: Alpine base installation not found!"
    echo "Please run: sudo ./run.sh private"
    echo "Then exit and run this script again."
    exit 1
fi

# Check if Alpine version matches config
if [ -f "$CHROOT/etc/apk/repositories" ]; then
    CHROOT_VERSION=$(grep -oP 'alpine/\K[^/]+' "$CHROOT/etc/apk/repositories" | head -1)
    if [ "$CHROOT_VERSION" != "$ALPINE_VERSION" ]; then
        echo "Warning: Alpine version mismatch detected"
        echo "  Config file wants: $ALPINE_VERSION"
        echo "  Base ALPM-FS has: $CHROOT_VERSION"
        echo ""
        echo "Rebuilding Alpine base installation..."
        rm -rf "$CHROOT"
        "$SCRIPT_DIR/install.sh" "$CHROOT"

        echo ""
        echo "Base installation rebuilt. Please run 'sudo ./run.sh private' to apply mods,"
        echo "then run this script again."
        exit 0
    fi
fi
############ CHECKS DONE.

# Create disk image
echo "[1/7] Creating disk image..."
dd if=/dev/zero of="$IMAGE_FILE" bs=1 count=0 seek="$IMAGE_SIZE" 2>/dev/null

# Setup loop device
echo "[2/7] Setting up loop device..."
LOOP_DEV=$(losetup -f --show "$IMAGE_FILE")
echo "Loop device: $LOOP_DEV"

# Cleanup trap in case of cancel or error
cleanup() {
    echo "Cleaning up..."
    mountpoint -q /mnt/alpine-img 2>/dev/null && umount -R /mnt/alpine-img
    losetup -d "$LOOP_DEV" 2>/dev/null || true
}
trap cleanup EXIT

# Partition the disk (GPT/UEFI only)
echo "[3/7] Creating GPT partition table..."
EFI_END=$((EFI_SIZE + 1))
parted -s --align=opt "$LOOP_DEV" mklabel gpt
parted -s --align=opt "$LOOP_DEV" mkpart primary fat32 1MiB ${EFI_END}MiB
parted -s --align=opt "$LOOP_DEV" set 1 esp on
parted -s --align=opt "$LOOP_DEV" mkpart primary "${ROOT_FS_TYPE}" "${EFI_END}MiB" 100%

# Reload partition table
echo "[*] Reloading partition table..."
partprobe "$LOOP_DEV"
sleep 1

# Format for EFI
echo "[4/7] Formatting partitions..."
EFI_PART="${LOOP_DEV}p1"
PART_DEV="${LOOP_DEV}p2"
mkfs.vfat -F32 "$EFI_PART"

# Format root part
echo "[*] Creating FS $ROOT_FS_TYPE..."
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
mount --bind /dev /mnt/alpine-img/dev
mkdir -p /mnt/alpine-img/dev/pts
mount -t devpts devpts /mnt/alpine-img/dev/pts

cp /etc/resolv.conf /mnt/alpine-img/etc/resolv.conf

# Configure /etc/apk/repositories based on config
mkdir -p /mnt/alpine-img/etc/apk
echo "[*] Enabling standard repos..."
cat > /mnt/alpine-img/etc/apk/repositories <<REPOS
${ALPINE_MIRROR}/${ALPINE_VERSION}/main
${ALPINE_MIRROR}/${ALPINE_VERSION}/community
REPOS

# Add testing repo if enabled (as tagged repository)
# Testing repository only exists in edge, not in versioned releases
if [ "$ENABLE_TESTING" = "yes" ]; then
    echo "[*] Enabling @testing tagged repo from /edge/testing (experimental)..."
    echo "@testing ${ALPINE_MIRROR}/edge/testing" >> /mnt/alpine-img/etc/apk/repositories
fi

# Validate bootloader configuration and install packages
if [ "$BOOTLOADER" = "refind" ]; then
    if [ "$ENABLE_TESTING" != "yes" ]; then
        echo "Error: rEFInd bootloader requires ENABLE_TESTING=\"yes\""
        echo "rEFInd is only available in the edge/testing repository."
        echo "Please update ALPM-FS.conf to enable testing repos."
        exit 1
    fi
    echo "[*] Using rEFInd bootloader with with $KERNEL_FLAVOR"
    echo "[*] From /edge/testing repos experimental..."
elif [ "$BOOTLOADER" = "grub" ]; then
    echo "[*] Using GRUB bootloader with $KERNEL_FLAVOR"
    BOOT_PACKAGES="grub grub-efi"
else
    echo "Error: Invalid BOOTLOADER setting: $BOOTLOADER"
    echo "Valid options are: grub, refind"
    exit 1
fi

# Install packages and bootloader
echo "[*] Running main chroot script..."

# Skip Alpine kernel package if using custom kernel
if [ "$USE_CUSTOM_KERNEL" = "yes" ]; then
    echo "[*] Skipping $KERNEL_FLAVOR package (using custom kernel)"
    # Remove kernel package from CORE_PACKAGES but keep the rest
    INSTALL_CORE_PACKAGES="${CORE_PACKAGES//$KERNEL_FLAVOR/}"
else
    INSTALL_CORE_PACKAGES="$CORE_PACKAGES"
fi

chroot /mnt/alpine-img /bin/sh <<CHROOT_CMD
. /root/.profile 2>/dev/null || true
apk update
[ -n "$HW_GROUP_INTEL" ] && apk add intel-ucode
[ -n "$HW_GROUP_AMD" ] && apk add amd-ucode
[ -n "$INSTALL_CORE_PACKAGES" ] && apk add $INSTALL_CORE_PACKAGES
[ -n "$CORE_PACKAGES2" ] && apk add $CORE_PACKAGES2
apk add $BOOT_PACKAGES
[ "$BOOTLOADER" = "refind" ] && apk add refind@testing
apk add $SYSTEM_PACKAGES
[ -n "$DEV_PACKAGES" ] && apk add $DEV_PACKAGES
apk add $EXTRA_PACKAGES
[ "$WIFI_NEEDED" = "yes" ] && [ -n "$WIFI_PACKAGES" ] && apk add $WIFI_PACKAGES
[ -n "$NTH_PACKAGES" ] && apk add $NTH_PACKAGES
[ -n "$HW_GROUP_INTEL" ] && apk add $HW_GROUP_INTEL
[ -n "$HW_GROUP_AMD" ] && apk add $HW_GROUP_AMD
[ -n "$GP_GROUP_MESA" ] && apk add $GP_GROUP_MESA
CHROOT_CMD

# Install custom kernel if enabled
if [ "$USE_CUSTOM_KERNEL" = "yes" ]; then
    echo "[*] Installing custom kernel..."

    # Find custom kernel build directory
    CUSTOM_KERNEL_DIR=$(find "$CUSTOM_KERNEL_BUILD_DIR" -maxdepth 1 -type d -name "linux-*" 2>/dev/null | head -1)

    if [ -z "$CUSTOM_KERNEL_DIR" ] || [ ! -d "$CUSTOM_KERNEL_DIR" ]; then
        echo "Error: Custom kernel build not found in $CUSTOM_KERNEL_BUILD_DIR"
        echo "Please build the kernel first: ./comp_kernel.sh"
        exit 1
    fi

    CUSTOM_BZIMAGE="$CUSTOM_KERNEL_DIR/arch/x86/boot/bzImage"
    if [ ! -f "$CUSTOM_BZIMAGE" ]; then
        echo "Error: Custom kernel bzImage not found at $CUSTOM_BZIMAGE"
        exit 1
    fi

    # Get kernel version
    CUSTOM_KVER=$(make -C "$CUSTOM_KERNEL_DIR" -s kernelrelease 2>/dev/null)
    echo "[*] Custom kernel version: $CUSTOM_KVER"

    # Copy kernel to EFI partition
    cp "$CUSTOM_BZIMAGE" "/mnt/alpine-img/efi/vmlinuz-$CUSTOM_KVER"

    # Install kernel modules
    echo "[*] Installing custom kernel modules..."
    make -C "$CUSTOM_KERNEL_DIR" INSTALL_MOD_PATH="/mnt/alpine-img" modules_install -j"$(nproc)"

    # Generate initramfs for custom kernel
    echo "[*] Generating initramfs for custom kernel..."
    chroot /mnt/alpine-img /bin/sh <<CUSTOM_INITRAMFS
. /root/.profile 2>/dev/null || true
mkinitfs -o /efi/initramfs-$CUSTOM_KVER $CUSTOM_KVER
CUSTOM_INITRAMFS

    echo "[*] Custom kernel installed: vmlinuz-$CUSTOM_KVER"
fi

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

# Add WiFi services if enabled
if [ "$WIFI_NEEDED" = "yes" ] && [ -n "$SERVICES_DEFAULT_WIFI" ]; then
    for service in $SERVICES_DEFAULT_WIFI; do
        rc-update add \$service default
    done
fi

# Configure zram for swap
cat > /etc/conf.d/zram-init <<-ZRAMCONF
	load_on_start=yes
	unload_on_stop=yes
	num_devices=1
	type0=swap
	size0=$ZRAM_SIZE
	algo0=$ZRAM_ALGO
ZRAMCONF

# Configure NetworkManager
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/NetworkManager.conf <<-NMCONF
	[main]
	dhcp=internal
	plugins=ifupdown,keyfile

	[ifupdown]
	managed=true

	[device]
	wifi.scan-rand-mac-address=yes
	wifi.backend=wpa_supplicant
NMCONF

# Configure network interfaces for auto DHCP
cat > /etc/network/interfaces <<-NETCONF
	auto lo
	iface lo inet loopback

	auto eth0
	iface eth0 inet dhcp
	    hostname \$HOSTNAME
NETCONF

# Create inittab
cat > /etc/inittab <<'EOF'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default
tty1::respawn:/sbin/getty 38400 tty1
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF

# Enable Unicode support in rc.conf
sed -i 's/#unicode="NO"/unicode="YES"/' /etc/rc.conf

# Configure system locale
cat > /etc/profile.d/locale.sh <<-LOCALECONF
	export LANG=$LOCALE
	export LC_ALL=$LOCALE
LOCALECONF

CHROOT_CMD

# Get partition UUID (needed for both bootloaders)
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

# Auto-detect kernel and initramfs filenames
KERNEL_FILE=$(find /mnt/alpine-img/efi -name 'vmlinuz*' -type f 2>/dev/null | head -1)
INITRAMFS_FILE=$(find /mnt/alpine-img/efi -name 'initramfs*' -type f 2>/dev/null | head -1)

if [ -z "$KERNEL_FILE" ] || [ -z "$INITRAMFS_FILE" ]; then
    echo "Error: Could not find kernel or initramfs in /efi"
    echo "Contents of /mnt/alpine-img/efi:"
    ls -la /mnt/alpine-img/efi/
    exit 1
fi

# Extract just the filename
KERNEL_FILE=$(basename "$KERNEL_FILE")
INITRAMFS_FILE=$(basename "$INITRAMFS_FILE")

echo "[*] Detected kernel: $KERNEL_FILE"
echo "[*] Detected initramfs: $INITRAMFS_FILE"

# Check if microcode image exists
UCODE_FILE=""
UCODE_IMG=$(find /mnt/alpine-img/efi -name '*-ucode.img' -type f 2>/dev/null | head -1)
if [ -n "$UCODE_IMG" ]; then
    UCODE_FILE="/$(basename "$UCODE_IMG")"
    echo "[*] Found microcode: $UCODE_FILE"
else
    echo "[*] No microcode image found (skipping)"
fi

# Install and configure bootloader based on selection
if [ "$BOOTLOADER" = "grub" ]; then
    echo "[*] Installing GRUB bootloader..."

    # Install GRUB inside chroot
    chroot /mnt/alpine-img /bin/sh <<GRUB_INSTALL
. /root/.profile 2>/dev/null || true
grub-install --target=x86_64-efi --efi-directory=/efi \
             --boot-directory=/efi --bootloader-id=Alpine \
             --removable --no-nvram --no-floppy \
             --modules="part_gpt part_msdos" \
             --recheck
GRUB_INSTALL

    # Generate GRUB config
    echo "[*] Generating GRUB configuration..."
    if [ -n "$UCODE_FILE" ]; then
        cat > /mnt/alpine-img/efi/grub/grub.cfg <<GRUBCFG
set timeout=$GRUB_TIMEOUT
set default=0

menuentry "$MENUENTRY" {
    linux /$KERNEL_FILE root=UUID=$PART_UUID $KERNEL_CMDLINE
    initrd $UCODE_FILE /$INITRAMFS_FILE
}
GRUBCFG
    else
        cat > /mnt/alpine-img/efi/grub/grub.cfg <<GRUBCFG
set timeout=$GRUB_TIMEOUT
set default=0

menuentry "$MENUENTRY" {
    linux /$KERNEL_FILE root=UUID=$PART_UUID $KERNEL_CMDLINE
    initrd /$INITRAMFS_FILE
}
GRUBCFG
    fi


elif [ "$BOOTLOADER" = "refind" ]; then
    echo "[*] Installing rEFInd bootloader..."

    # Manually install rEFInd (refind-install has issues with pre-mounted ESP in chroot)
    echo "[*] Creating rEFInd directory structure..."
    mkdir -p /mnt/alpine-img/efi/EFI/refind
    mkdir -p /mnt/alpine-img/efi/EFI/BOOT

    # Copy rEFInd binaries
    echo "[*] Copying rEFInd binaries..."
    if [ -f /mnt/alpine-img/usr/share/refind/refind_x64.efi ]; then
        cp /mnt/alpine-img/usr/share/refind/refind_x64.efi /mnt/alpine-img/efi/EFI/refind/
        cp /mnt/alpine-img/usr/share/refind/refind_x64.efi /mnt/alpine-img/efi/EFI/BOOT/bootx64.efi
    else
        echo "Error: rEFInd binary not found in /usr/share/refind/"
        exit 1
    fi

    # Copy icons if they exist
    if [ -d /mnt/alpine-img/usr/share/refind/icons ]; then
        echo "[*] Copying rEFInd icons..."
        cp -r /mnt/alpine-img/usr/share/refind/icons /mnt/alpine-img/efi/EFI/refind/
    fi

    # Copy btrfs driver if using btrfs filesystem
    if [ "$ROOT_FS_TYPE" = "btrfs" ]; then
        echo "[*] Copying Btrfs driver for rEFInd..."
        if [ -f /mnt/alpine-img/usr/share/refind/drivers_x86_64/btrfs_x64.efi ]; then
            mkdir -p /mnt/alpine-img/efi/EFI/refind/drivers_x64
            cp /mnt/alpine-img/usr/share/refind/drivers_x86_64/btrfs_x64.efi \
               /mnt/alpine-img/efi/EFI/refind/drivers_x64/
        fi
    fi

    # Generate rEFInd configuration
    echo "[*] Generating rEFInd configuration..."
    if [ -n "$UCODE_FILE" ]; then
        cat > /mnt/alpine-img/efi/EFI/refind/refind.conf <<REFINDCFG
timeout $REFIND_TIMEOUT
resolution $REFIND_RESOLUTION
use_graphics_for linux

menuentry "$MENUENTRY" {
    icon     /EFI/refind/icons/os_linux.png
    loader   /$KERNEL_FILE
    initrd   $UCODE_FILE
    initrd   /$INITRAMFS_FILE
    options  "root=UUID=$PART_UUID $KERNEL_CMDLINE"
}
REFINDCFG
    else
        cat > /mnt/alpine-img/efi/EFI/refind/refind.conf <<REFINDCFG
timeout $REFIND_TIMEOUT
resolution $REFIND_RESOLUTION
use_graphics_for linux

menuentry "$MENUENTRY" {
    icon     /EFI/refind/icons/os_linux.png
    loader   /$KERNEL_FILE
    initrd   /$INITRAMFS_FILE
    options  "root=UUID=$PART_UUID $KERNEL_CMDLINE"
}
REFINDCFG
    fi

    # Create refind_linux.conf in the EFI partition root
    echo "[*] Creating refind_linux.conf..."
    cat > /mnt/alpine-img/efi/refind_linux.conf <<REFINDLINUX
"Boot with standard options" "root=UUID=$PART_UUID $KERNEL_CMDLINE"
"Boot to single-user mode" "root=UUID=$PART_UUID $KERNEL_CMDLINE single"
"Boot with minimal options" "root=UUID=$PART_UUID ro"
REFINDLINUX
fi

echo "[*] Unmouting EFI..."
umount /mnt/alpine-img/efi

echo "[*] Setting hostname..."
echo "$HOSTNAME" > /mnt/alpine-img/etc/hostname

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
echo "[*] Unmouting dev/pts/sys/proc..."
umount /mnt/alpine-img/dev/pts
umount /mnt/alpine-img/dev
umount /mnt/alpine-img/sys
umount /mnt/alpine-img/proc

echo "[*] Unmouting full..."
umount /mnt/alpine-img

echo ""
echo "==================================="
echo "✓ Bootable image created!"
echo "==================================="
echo ""
echo "Image: $IMAGE_FILE Size: $IMAGE_SIZE"
echo "Boot mode: UEFI : $BOOTLOADER"
echo "System hostname: $HOSTNAME"
echo "Root password: $ROOT_PASSWORD"
echo "You can now use 'sudo ./utils/write_img_usb.sh $IMAGE_FILE /dev/sdb' for example"
echo "Then resize part2 to take the full disk space."
echo ""
