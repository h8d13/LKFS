#!/bin/bash
## magic reset uncomment 
#rm -rf alpinestein
## check if the alpinestein directory exists
if [ ! -d "alpinestein" ]; then
    mkdir -p alpinestein
    wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.3-x86_64.tar.gz -O tmp.tar.gz
    tar xzf tmp.tar.gz -C alpinestein
    rm tmp.tar.gz
else
    echo "Skipping download and extraction."
fi

## ash dash stuff
cat << EOF > alpinestein/root/.ashrc
export PATH="/bin:\$PATH"
alias ll="ls -la"
alias apkli="apk list --installed | grep"
EOF

## set the ENV variable in .profile
cat << EOF > alpinestein/root/.profile
export ENV=\$HOME/.ashrc
EOF

## create the etc directory in the Alpine environment
mkdir -p alpinestein/etc

## copy the DNS resolver configuration from host to mfs
cp /etc/resolv.conf alpinestein/etc/resolv.conf

## create a symlink for apk so that we can access it directly. 
ln -s /sbin/apk alpinestein/bin/apk

## now start a shell using chroot
chroot alpinestein /bin/ash -c "source /root/.profile; exec /bin/ash"
