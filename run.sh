#!/bin/bash
## magic reset/testing uncomment 
#rm -rf alpinestein_mnt

## check if the alpinestein directory exists, if it does, we skip 3mb install.
chmod +x ./utils/install.sh
./utils/install.sh

## constants for directories and files
ALPF_DIR=alpinestein
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"

## ash dash stuff path aliases
cat << EOF > "$ROOT_DIR/.ashrc"
export PATH="/bin:\$PATH"
alias ll="ls -la"
alias apkli="apk list --installed | grep"
EOF

## set the ENV variable in .profile
cat << EOF > "$ROOT_DIR/.profile"
export ENV=\$HOME/.ashrc
EOF

## copy DNS resolver configuration from host
cp /etc/resolv.conf $ALPF_DIR/etc/resolv.conf

## create a symlink for apk so that we can access it directly. 
## we also need it to be conditional because symlinks persist
if [ ! -L $ALPF_DIR/bin/apk ]; then
  ln -s /sbin/apk alpinestein/bin/apk
fi

# make exec + mount
chmod +x ./utils/mount.sh
./utils/mount.sh

#### wrapper done. example features.
cat assets/issue.ceauron > "$PRO_D_DIR/logo.sh"
chmod +x "$PRO_D_DIR/logo.sh"

## create custom welcome message
cat > "$PRO_D_DIR/welcome.sh" << EOF
echo -e '\e[1;31mWelcome to Alpinestein.\e[0m'
echo -e "Kernel \e[1;31m\$(uname -r)\e[0m on an \e[1;31m\$(uname -m)\e[0m (\e[1;31m\$(uname -n)\e[0m)"
EOF
chmod +x "$PRO_D_DIR/welcome.sh"

## create version script
cat > "$PRO_D_DIR/version.sh" << EOF
#!/bin/sh
version=\$(cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | tr -d '"')
echo -e "\e[1;31m\$version\e[0m"
EOF
chmod +x "$PRO_D_DIR/version.sh"

## source and spawn a shell (as login -l)
chroot $ALPF_DIR /bin/ash -c "source /root/.profile; exec /bin/ash -l"

#### cleanup
## make exec + Unmount
chmod +x ./utils/unmount.sh
./utils/unmount.sh
