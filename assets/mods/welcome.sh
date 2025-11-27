#!/bin/sh
#HL#assets/mods/welcome.sh#
printf '\e[1;31mWelcome to Alpinestein.\e[0m\n'
printf "Kernel \e[1;31m%s\e[0m on an \e[1;31m%s\e[0m (\e[1;31m%s\e[0m)\n" "$(uname -r)" "$(uname -m)" "$(uname -n)"
