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
Which makes it so that the host doesn't have any form of access to the files of Alpinestein. 

---- 

My next thought is how far can you take such a small and lean install, perhaps run alpine in alpine in alpine lmao. 
