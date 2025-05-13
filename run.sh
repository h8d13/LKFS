## magic reset/testing uncomment 
#rm -rf alpinestein_mnt
## check if the alpinestein directory exists
if [ ! -d "alpinestein" ]; then
    mkdir -p alpinestein
    wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.3-x86_64.tar.gz -O tmp.tar.gz
    tar xzf tmp.tar.gz -C alpinestein
    rm tmp.tar.gz
else
    echo "Skipping download and extraction."
fi

## ash dash stuff path aliases
cat << EOF > alpinestein/root/.ashrc
export PATH="/bin:\$PATH"
alias ll="ls -la"
alias apkli="apk list --installed | grep"
EOF

## set the ENV variable in .profile
cat << EOF > alpinestein/root/.profile
export ENV=\$HOME/.ashrc
EOF

## copy the DNS resolver configuration from host to mfs
cp /etc/resolv.conf alpinestein/etc/resolv.conf

## create a symlink for apk so that we can access it directly. 
## we also need it to be conditional because symlinks persist
if [ ! -L alpinestein/bin/apk ]; then
  ln -s /sbin/apk alpinestein/bin/apk
fi

# Make exec + Mount
chmod +x ./utils/mount.sh
./utils/mount.sh

## Example features can go to local.d or profile.d
## The former being services and latter being login scripts. 

## Example features: Create a custom welcome message script for login shells in /etc/profile.d/
cat > alpinestein/etc/profile.d/welcome.sh << EOF
echo -e '\e[1;31mWelcome to Alpinestein.\e[0m'
EOF
chmod +x alpinestein/etc/profile.d/welcome.sh

cat > alpinestein/etc/profile.d/version.sh << EOF
#!/bin/sh
cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | tr -d '"'
EOF
chmod +x alpinestein/etc/profile.d/version.sh

## source and spawn a shell (as login -l)
chroot alpinestein /bin/ash -c "source /root/.profile; exec /bin/ash -l"

# Make exec + Unmount
chmod +x ./utils/unmount.sh
./utils/unmount.sh
