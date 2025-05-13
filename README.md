# LKFS
----

## Alpine-Mini Chroot 👻 

> Prereqs: Be on a linux system with tar, wget, bash

----

Coolest part of this project: Initial auto download is **3.3mb.**

Extracted is < ~10mb, end goal being a kind of TUI-os.

Then the limit is your imagination as always. 

---- 

Second part is more of technical Linux feature: using `unshare --mount --fork` 

Which makes it so that the host doesn't have any form of access to the files of Alpinestein. Or tiny hill?  

---- 

## Configure

Download the repo and extract or `git clone https://github.com/h8d13/LKFS`

```
chmod +x run.sh
./run.sh
```

You can also just use it like a normal Alpine install `apk add micro-tetris`
(You can add `-vvv` to see exactly where the 14kb of Tetris are going) 

[1989 Tetris Obf](https://tromp.github.io/tetris.html) 

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)

Or run docker containers ? You do you.

You could also possibly get x11 sharing to work? I don't even want to try. 
