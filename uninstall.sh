#!/bin/bash
#
# Cloud Agent CLI uninstaller
# Removes the 'ca' binary
#

set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="ca"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🐕 CLOUD AGENT CLI UNINSTALLER                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check for binary installation
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    rm "$INSTALL_DIR/$BINARY_NAME"
    echo "✅ Removed $INSTALL_DIR/$BINARY_NAME"
else
    echo "⚠️  Binary not found at $INSTALL_DIR/$BINARY_NAME"
fi

# Also check for legacy shell function installation
detect_shell_config() {
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "/bin/zsh" ]; then
        echo "${ZDOTDIR:-$HOME}/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "/bin/bash" ]; then
        if [ -f "$HOME/.bash_profile" ]; then
            echo "$HOME/.bash_profile"
        else
            echo "$HOME/.bashrc"
        fi
    else
        echo "$HOME/.profile"
    fi
}

SHELL_CONFIG=$(detect_shell_config)

if grep -q "# Cloud Agent - run deploy.sh from anywhere" "$SHELL_CONFIG" 2>/dev/null; then
    sed -i.bak '/# Cloud Agent - run deploy.sh from anywhere/,/^}/d' "$SHELL_CONFIG"
    echo "✅ Removed legacy shell function from $SHELL_CONFIG"
    echo ""
    echo "Restart your terminal or run:"
    echo "  source $SHELL_CONFIG"
fi

echo ""
echo "🐕 Goodbye!"

