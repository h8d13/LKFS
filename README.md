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

Download the repo. 


```
chmod +x run.sh
./run.sh
```


You can also just use it like a normal Alpine install `apk add micro-tetris`

Then `tetris`

![Screenshot_20250513_182948](https://github.com/user-attachments/assets/1ee28de2-ba20-4aa2-b3c5-4d2793499d61)

Or run docker containers ? You do you.
