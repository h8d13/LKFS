#!/bin/sh
#HL#assets/mods/version.sh#
version=$(grep VERSION_ID /etc/os-release | cut -d'=' -f2 | tr -d '"')
printf "\e[1;31m%s\e[0m\n" "$version"
