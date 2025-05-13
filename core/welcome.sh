cat > /etc/profile.d/welcome.sh << EOF
#!/bin/sh
echo -e '\e[1;31mWelcome to Alpinestein.\e[0m'
echo -e "Kernel \e[1;31m\$(uname -r)\e[0m on an \e[1;31m\$(uname -m)\e[0m (\e[1;31m\$(uname -n)\e[0m)"
EOF
