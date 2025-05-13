#!/bin/bash
#HL#run.sh#
## magic reset/testing uncomment 
#rm -rf alpinestein_mnt
#rm -rf alpinestein
#### keep in mind that everything is relative to this script
## constants for directories and files
ALPF_DIR=alpinestein
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"
MODS_DIR="assets/mods"
## check if the alpinestein directory exists, if it does, we skip install
chmod +x ./utils/install.sh 
./utils/install.sh $ALPF_DIR
# configure the profile from conf
cp assets/config.conf "$ROOT_DIR/.ashrc"
## set the ENV variable in .profile to ensure .ashrc is sourced if exist
chmod +x ./assets/profile.sh
./assets/profile.sh "$ROOT_DIR"
## copy DNS resolver configuration from host
cp /etc/resolv.conf $ALPF_DIR/etc/resolv.conf
# make exec + mount
chmod +x ./utils/mount.sh
./utils/mount.sh
#### wrapper done. example features:
cat assets/issue.ceauron > "$PRO_D_DIR/logo.sh"
chmod +x "$PRO_D_DIR/logo.sh"
cp "$MODS_DIR/welcome.sh" "$PRO_D_DIR/welcome.sh"
chmod +x "$PRO_D_DIR/welcome.sh"
cp "$MODS_DIR/version.sh" "$PRO_D_DIR/version.sh"
chmod +x "$PRO_D_DIR/version.sh"
## source and spawn a shell (as login -l)
chroot $ALPF_DIR /bin/sh -c "source /root/.profile; exec /bin/sh -l"
#### cleanup make exec + unmount
chmod +x ./utils/unmount.sh
./utils/unmount.sh
##dev util needs "tree" pkg
#chmod +x ./utils/tree.sh 
#./utils/tree.sh
