#!/bin/bash

qemu-system-x86_64 -m 2G -enable-kvm -cpu host -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd \
    -drive file=alpine-boot.img,format=raw \
    -nic user,model=virtio-net-pci