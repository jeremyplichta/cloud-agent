#!/bin/bash
#
# Cloud Agent CLI uninstaller
# Removes the 'ca' command from your shell
#

set -e

# Detect shell config file
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

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🐕 CLOUD AGENT CLI UNINSTALLER                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if grep -q "# Cloud Agent - run deploy.sh from anywhere" "$SHELL_CONFIG" 2>/dev/null; then
    # Remove the Cloud Agent function block
    sed -i.bak '/# Cloud Agent - run deploy.sh from anywhere/,/^}/d' "$SHELL_CONFIG"
    # Clean up any empty lines that might be left behind
    echo "✅ Removed Cloud Agent command from $SHELL_CONFIG"
    echo ""
    echo "Restart your terminal or run:"
    echo "  source $SHELL_CONFIG"
else
    echo "⚠️  Cloud Agent command not found in $SHELL_CONFIG"
    echo "   Nothing to uninstall."
fi
echo ""
echo "🐕 Goodbye!"

