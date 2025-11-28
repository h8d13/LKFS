#!/bin/sh
# Install git hooks for the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "[+] Installing git hooks..."

# Check if shellcheck is installed
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "Warning: shellcheck is not installed"
    echo "Install with: sudo pacman -S shellcheck (Arch) or sudo apt install shellcheck (Debian/Ubuntu)"
fi

# Install pre-commit hook
cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "[+] Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
echo "  - pre-commit (runs shellcheck on modified shell scripts)"
echo ""
echo "To bypass hooks, use: git commit --no-verify"
