# LKFS
----

## Alpine-Mini Chroot 👻 

> Prereqs: Be on a linux system with tar, wget, bash
> Assumes x86_64

----

Coolest part of this project: Initial auto download is **3.3mb.**

Extracted is < ~10mb, end goal being a kind of TUI-os + Port it to actual hardware (190mb +/-)
And for the whole process to take less than 30 seconds.

Download the repo and extract or `git clone https://github.com/h8d13/LKFS`

----

Using unshare:
```
#examples see unshare manpage
#sudo ./run.sh shared | slave | private
#--fork
#--uts --hostname alpine-test
#--user --map-root-user
#--pid
#--net
#--ipc
```

This will download the base mini-FS and set it up using the assets.

----

## Configure

```
sudo chmod +x run.sh
sudo ./run.sh args
```

You can then just use it like a normal Alpine install `apk add micro-tetris`

(You can add `-vvv` if you want to see exactly where the 14kb of Tetris are going)

[1989 Tetris Obf](https://tromp.github.io/tetris.html)

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)

Type `exit` when you want to leave.

----

## Making it Bootable

Transform this chroot environment into a fully bootable Alpine Linux UEFI system!

### Create Bootable Disk Image

```bash
sudo ./utils/create_boot_img.sh alpine-boot.img 2G
```

This will:
- Create a GPT/UEFI bootable disk image
- Install kernel and GRUB2 EFI bootloader
- Configure boot services, fstab, zram
- Set up a complete bootable system

### Test with QEMU

```bash
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/OVMF_VARS.fd
sudo ./test_qemu.sh
```

### Write to USB

**Recommended:** Use the helper script to automatically create a data partition:
```bash
sudo ./utils/write_img_usb.sh alpine-boot.img /dev/sdX
```

This will:
- Write the bootable image
- Create a third partition using all remaining space
- Format it as ext4 with label "ALPINE_DATA"

**Manual:** Simple dd write (wastes space on large USB drives):
```bash
sudo dd if=alpine-boot.img of=/dev/sdX bs=4M status=progress
```

**Default credentials:** root / alpine (change after first boot!)
Also need to run `apk fix && apk update && apk upgrade`

The error is cause by installing grub inside chroot which it then gets confused as to where /dev/loop2 is.