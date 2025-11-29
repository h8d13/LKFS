# ALPM-FS
----

## Alpine-Mini Chroot 👻

> Prereqs: Be on a linux system with tar, wget, bash, parted and **assumes x86_64 target.** for EFI stub boot.

----

Instead of building kernel (which honestly confuses me more than anything) we'll give full control by starting at the smallest point possible.

Coolest part of this project: Initial auto download is **3.3mb.** (Alpine [MiniRoot](https://alpinelinux.org/downloads/) FS) Extracted is < ~9mb, goal being a kind of TUI-os + turn it into a fully working system for bare-metal.

And for the whole process to take **less than 30 seconds.**.

Download the repo and extract or `git clone https://github.com/h8d13/ALPM-FS`

----

Add to `assets/` and in `utils/chroot_launcher.sh`

Using unshare:
```
#examples see unshare manpage
#sudo ./run.sh (--reset) shared | slave | private
#--reset to redownload ALPM-FS fresh. # should be before unshare options
## unshare options...
#--fork
#--uts --hostname alpine-test
#--user --map-root-user
#--pid
#--net
#--ipc
#...
```

This will download the base mini-FS and set it up using the assets. (Which you can obviously modify) You will then be inside the env.

----

## Configure

You can then just use it like a normal Alpine install `apk add micro-tetris`

(You can add `-vvv` if you want to see exactly where the 14kb of Tetris are going)

[1989 Tetris Obf](https://tromp.github.io/tetris.html)

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)

Type `exit` when you want to leave the chroot.

----

## Making it Bootable

Transform this chroot environment into a fully bootable Alpine Linux UEFI system!

See `ALPM-FS.conf` **BEFORE** proceeding. [Here](./ALPM-FS.conf)

### Create the image

```bash
sudo ./utils/create_boot_img.sh alpine-boot.img 2G
```

This will:
- Create a GPT/UEFI bootable disk image
- Install kernel and GRUB2/reFIND EFI stub bootloader
- Configure boot services, fstab, zram
- Set up a complete bootable system

### Test with QEMU

```bash
sudo ./test_qemu.sh
```
Test it with chroot: `sudo ./utils/chroot_usb.sh /dev/sdX2`

### Write to USB

> Usually reset the disk partition table just to make sure :) and zero it out if needed.

**Recommended:** Use the helper script to automatically create a data partition:
```bash
sudo ./utils/write_img_usb.sh alpine-boot.img /dev/sdX
```

This will: Write the bootable image to the USB as part2, part1 being `/efi`.

>[!TIP]
> Finally: using `partitionmanager` I resize the disk for it to take the full USB.
> **Default credentials:** root / alpine (change after first boot!)
> Also need to run `apk update && apk upgrade` once you are in.

TODO: Proper mgmnt of repos... Have no idea how they work :D

-----

## Post base install

### Setup essentials
Generally on alpine you're going to want to to run `setup-alpine` this is a script that let's you configure stuff like network, passwords, a user, etc all things that are required for graphical sessions.

**BUT** when it asks you about **disks or save locations** just answer `none` to last 3 prompts for disks, since we have created a live system.

### Setup personals
Finally they also have helpers for `setup-desktop <desktop>` and `setup-wayland-base` for example (Which desktop environment? ('gnome', 'xfce', 'mate', 'sway', 'lxqt', 'plasma' or 'none')

I would not recommend gnome as it's going to be a past version since ver48 introduced dependencies on systemd.
Plasma works beautifully with sound of the box! 

I've also included a Sway setup script where you can simple `su <user>` then go to `doas ./root/mods/sway_user.sh`. Probably also recommended to install something like SDDM or lightdm or similar (a firewall, etc). But I left it without and you can run `sway` as your user to start it.

<details>
<summary><b>More stuff</b></summary>

#### Keymaps

If you ran `setup-alpine` it should have prompted you. Otherwise you can use `loadkeys fr`

For sddm:
```
export KB_LAYOUT=$(ls /etc/keymap/*.bmap.gz 2>/dev/null | head -1 | sed 's|/etc/keymap/||' | sed 's|\.bmap\.gz$||')
echo "XKB_DEFAULT_LAYOUT=$KB_LAYOUT" | doas tee -a /etc/environment
```

#### Firewall

```
$ doas ufw enable
$ doas rc-update add ufw default
$ doas ufw allow out 443
$ doas ufw default deny incoming
```
Or you can be more restrictive/specific:
```
$ doas ufw default deny outgoing
$ doas ufw allow out 443
$ doas ufw allow out 22
$ doas ufw allow out 53
$ doas ufw allow out 80
$ doas ufw default deny incoming
```

</details>


>[!NOTE]
> Also can be found in [.github](./.github) where I documented some of the tricks/ressources I've used.

```
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install minitext
flatpak run io.github.nokse22.minitext
```
Of course this is an example please install something more useful.
Also `doas apk add gnome-2048` because always need that at hand.

----

<details>
<summary><b>STATS</b></summary>

### FOR NERDS

[3.399605] Mounting root: ok. (Grub) 
[3.100839] Mounting root: ok. (Refind)

VM Final size (using linux-virt): 87.5 MiB

Final size (lts / mainline): 195 MiB

With hardware drivers + mesa: 800 MiB

Full Intel HW + Full MESA: 1.1GB

With 3 github pages open on FF and Sway: Memory: 2.09 GiB / 15.29 GiB (14%)
And all I need to code: Packages: 637 (apk)

Or full plasma install: 3.59 GiB - 6.3.6

(With VSCodium and some more stuff) on edge/testing: 4.76 GiB - 6.5.3

</details>


