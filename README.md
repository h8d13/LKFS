# LKFS
----

## Alpine-Mini Chroot 👻 

> Prereqs: Be on a linux system with tar, wget, bash

----

Coolest part of this project: Initial auto download is **3.3mb.**

Extracted is < ~10mb, end goal being a kind of TUI-os. 

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

---- 

## Configure

Download the repo and extract or `git clone https://github.com/h8d13/LKFS`

```
sudo chmod +x run.sh
sudo ./run.sh args
```

You can then just use it like a normal Alpine install `apk add micro-tetris`

(You can add `-vvv` if you want to see exactly where the 14kb of Tetris are going) 

[1989 Tetris Obf](https://tromp.github.io/tetris.html) 

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)
