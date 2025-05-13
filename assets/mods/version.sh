#!/bin/sh
# assets/mods/version.sh
version=$(cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | tr -d '"')
echo -e "\e[1;31m$version\e[0m"
