# LKFS
----

## Alpine Chroot 👻 

> Prereqs: Be on a linux system with tar, wget, bash

----

Coolest part of this project: Initial download is 3.3mb.

Extracted is < ~10mb

Then the limit is your imagination as always. 

---- 

Second part is more of technical Linux feature: using `unshare --mount --fork` 
Which makes it so that the host doesn't have any form of access to the files of Alpinestein. 
