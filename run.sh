#!/bin/bash
#HL#run.sh#
## magic reset/testing uncomment 
#rm -rf alpinestein_mnt
#rm -rf alpinestein
## check if the alpinestein directory exists, if it does, we skip 3mb install.
chmod +x ./utils/install.sh
./utils/install.sh

## constants for directories and files
ALPF_DIR=alpinestein
ROOT_DIR="$ALPF_DIR/root"
PRO_D_DIR="$ALPF_DIR/etc/profile.d"

## ash dash stuff path aliases
cat << EOF > "$ROOT_DIR/.ashrc"
# Custom PS1 prompt for ash shell
export PS1='\033[0;34m┌──[\033[0;36m\t\033[0;34m]─[\033[0;39m\u\033[0;34m@\033[0;36m\h\033[0;34m]─[\033[0;32m\w\033[0;34m]\n\033[0;34m└──╼ \033[0;36m$ \033[0m'

# Useful aliases and environment setup
export PATH="/bin:\$PATH"
alias ll="ls -la"
alias apkli="apk list --installed | grep"
EOF

## Set the ENV variable in .profile to ensure .ashrc is sourced if exist
cat << EOF > "$ROOT_DIR/.profile"
# Source .ashrc to load custom environment and prompt
export ENV=\$HOME/.ashrc
if [ -f \$ENV ]; then
  source \$ENV
fi
EOF

## Copy DNS resolver configuration from host
cp /etc/resolv.conf $ALPF_DIR/etc/resolv.conf

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
