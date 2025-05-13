#!/bin/bash
#HL#utils/install.sh#
ALPF_DIR=$1
## check if $ALPF_DIR directory exists
if [ ! -d "$ALPF_DIR" ]; then
    mkdir -p $ALPF_DIR
    wget https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.3-x86_64.tar.gz -O tmp.tar.gz
    tar xzf tmp.tar.gz -C $ALPF_DIR
    rm tmp.tar.gz
else
    echo "Skipping download and extraction."
fi
# or skip