#!/bin/bash

## Constants for directories and files
ALPF_DIR=alpinestein
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"

## Check if $ALPF_DIR directory exists
if [ ! -d "$ALPF_DIR" ]; then
    mkdir -p $ALPF_DIR
    wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.3-x86_64.tar.gz -O tmp.tar.gz
    tar xzf tmp.tar.gz -C $ALPF_DIR
    rm tmp.tar.gz
else
    echo "Skipping download and extraction."
fi

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

## Copy DNS resolver configuration
cp /etc/resolv.conf $ALPF_DIR/etc/resolv.conf

## create a symlink for apk so that we can access it directly. 
## we also need it to be conditional because symlinks persist
if [ ! -L $ALPF_DIR/bin/apk ]; then
  ln -s /sbin/apk alpinestein/bin/apk
fi

# Make exec + Mount
chmod +x ./utils/mount.sh
./utils/mount.sh

## Create custom welcome message
cat > "$PRO_D_DIR/welcome.sh" << EOF
echo -e '\e[1;31mWelcome to Alpinestein.\e[0m'
echo -e "Kernel \e[1;31m\$(uname -r)\e[0m on an \e[1;31m\$(uname -m)\e[0m (\e[1;31m\$(uname -n)\e[0m)"
EOF
chmod +x "$PRO_D_DIR/welcome.sh"

## Create version script
cat > "$PRO_D_DIR/version.sh" << EOF
#!/bin/sh
version=\$(cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | tr -d '"')
echo -e "\e[1;31m\$version\e[0m"
EOF
chmod +x "$PRO_D_DIR/version.sh"

## Source and spawn a shell (as login -l)
chroot $ALPF_DIR /bin/ash -c "source /root/.profile; exec /bin/ash -l"

# Make exec + Unmount
chmod +x ./utils/unmount.sh
./utils/unmount.sh
