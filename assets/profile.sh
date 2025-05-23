#!/bin/sh
#HL#assets/profile.sh#
ROOT_DIR="$1"
# Create .profile in the ROOT_DIR
cat << EOF > "$ROOT_DIR/.profile"
# Source .ashrc to load custom environment and prompt
export ENV=\$HOME/.ashrc
if [ -f \$ENV ]; then
  . \$ENV
fi
EOF
