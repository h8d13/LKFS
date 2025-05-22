#!/bin/bash
rm -rf alpinestein  #reset/testing uncomment
ALPF_DIR=alpinestein
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"
MODS_DIR="assets/mods"
## check if the alpinestein directory exists, if it does, we skip install
chmod +x ./utils/install.sh && ./utils/install.sh $ALPF_DIR
####### 1 ######
chmod +x ./utils/mount.sh && ./utils/mount.sh
# configure the profile from conf
cp assets/config.conf "$ROOT_DIR/.ashrc"
## set the ENV variable in .profile to ensure .ashrc is sourced if exist
chmod +x ./assets/profile.sh && ./assets/profile.sh "$ROOT_DIR"
## copy DNS resolver configuration from host
cp /etc/resolv.conf $ALPF_DIR/etc/resolv.conf
####### do stuff ######
cat assets/issue.ceauron > "$PRO_D_DIR/logo.sh" && chmod +x "$PRO_D_DIR/logo.sh"
cp "$MODS_DIR/welcome.sh" "$PRO_D_DIR/welcome.sh" && chmod +x "$PRO_D_DIR/welcome.sh"
cp "$MODS_DIR/version.sh" "$PRO_D_DIR/version.sh" && chmod +x "$PRO_D_DIR/version.sh"
## source and spawn a shell (as login -l) ##
chroot $ALPF_DIR /bin/sh -c ". /root/.profile; exec /bin/sh -l"
####### 2 ######
chmod +x ./utils/unmount.sh && ./utils/unmount.sh