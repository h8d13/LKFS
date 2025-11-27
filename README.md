# LKFS
----

## Alpine-Mini Chroot 👻 

> Prereqs: Be on a linux system with tar, wget, bash
> Assumes x86_64

----

Instead of building kernel (which honestly confuses me more than anything) we'll give full control by starting at the smallest point possible.

Coolest part of this project: Initial auto download is **3.3mb.** (Alpine MiniRoot FS)

Extracted is < ~10mb, end goal being a kind of TUI-os

> With keyboard symbols.

And for the whole process to take **less than 30 seconds.**

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

This will download the base mini-FS and set it up using the assets. (Which you can obviously modify)

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

See `ALPM-FS.conf` **BEFORE** proceeding.

VM Final size (using linux-virt): 87.5 MiB
FULL Final size (lts / mainlaine): 195 MiB

With hardware drivers + mesa: 800 MiB

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

This will: Write the bootable image to the USB as part2, part1 being /efi.

**Default credentials:** root / alpine (change after first boot!)
Also need to run `apk update && apk upgrade` once you are in.

Then you can run setup-alpine like you normally would and at disk selection pick "none".

Finally: using partitionmanager I resize the disk for it to take the full USB.