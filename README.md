# ALPM-FS
----

## Alpine-Mini Chroot 👻

> Prereqs: Be on a linux system with tar, wget, bash, parted and **assumes x86_64 target.** for EFI stub boot.

----

Instead of building kernel (which honestly confuses me more than anything) we'll give full control by starting at the smallest point possible.

Coolest part of this project: Initial auto download is **3.3mb.** (Alpine [MiniRoot](https://alpinelinux.org/downloads/) FS) Extracted is < ~10mb, goal being a kind of TUI-os + turn it into a fully working system for bare-metal.

And for the whole process to take **less than 30 seconds.**.

Download the repo and extract or `git clone https://github.com/h8d13/LKFS`

----

Using unshare:
```
#examples see unshare manpage
#sudo ./run.sh shared | slave | private (--reset) to redownload fresh.
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

Add to assets and in `utils/chroot_launcher.sh`
```
sudo ./run.sh args
```

You can then just use it like a normal Alpine install `apk add micro-tetris`

(You can add `-vvv` if you want to see exactly where the 14kb of Tetris are going)

[1989 Tetris Obf](https://tromp.github.io/tetris.html)

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)

Type `exit` when you want to leave the chroot.

----

## Making it Bootable

Transform this chroot environment into a fully bootable Alpine Linux UEFI system!

See `ALPM-FS.conf` **BEFORE** proceeding.

VM Final size (using linux-virt): 87.5 MiB
FULL Final size (lts / mainlaine): 195 MiB

With hardware drivers + mesa: 800 MiB
Full HW + Full MESA: 2GB

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
sudo ./test_qemu.sh
```
Test it with chroot: `sudo ./utils/chroot_usb.sh /dev/sdX2`

### Write to USB

**Recommended:** Use the helper script to automatically create a data partition:
```bash
sudo ./utils/write_img_usb.sh alpine-boot.img /dev/sdX
```

This will: Write the bootable image to the USB as part2, part1 being /efi.

**Default credentials:** root / alpine (change after first boot!)
Also need to run `apk update && apk upgrade` once you are in.

Finally: using partitionmanager I resize the disk for it to take the full USB.

-----

## Post install

Generally on alpine you're going to want to to run `setup-alpine` this is a script that let's you configure stuff like network, passwords, a user, etc all thigns that are required for graphical sessions. **BUT** when it asks you about disks or save location just answer "none" to all since we have created a live system.

Finally they also have helpers for `setup-desktop <desktop>` and `setup-wayland-base` for example.

I've also included a Sway setup script where you can simple `su <user>` then go to `doas ./root/mods/sway_user.sh`.
