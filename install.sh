#!/bin/bash
#
# Cloud Auggie CLI installer
# Adds the 'ca' command to your shell for easy access from anywhere
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND_NAME="${1:-ca}"

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
SHELL_NAME=$(basename "$SHELL")

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🐕 CLOUD AUGGIE CLI INSTALLER                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Installing '$COMMAND_NAME' command..."
echo "  Cloud Auggie directory: $SCRIPT_DIR"
echo "  Shell config: $SHELL_CONFIG"
echo ""

# Create the function definition
FUNCTION_DEF="
# Cloud Auggie - run deploy.sh from anywhere
$COMMAND_NAME() {
    \"$SCRIPT_DIR/deploy.sh\" \"\$@\"
}"

# Check if already installed
if grep -q "# Cloud Auggie - run deploy.sh from anywhere" "$SHELL_CONFIG" 2>/dev/null; then
    echo "⚠️  Cloud Auggie command already installed in $SHELL_CONFIG"
    echo ""
    read -p "Reinstall/update? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    # Remove old installation
    sed -i.bak '/# Cloud Auggie - run deploy.sh from anywhere/,/^}/d' "$SHELL_CONFIG"
    echo "Removed old installation."
fi

# Append to shell config
echo "$FUNCTION_DEF" >> "$SHELL_CONFIG"

echo "✅ Installed '$COMMAND_NAME' command!"
echo ""
echo "To start using it now, run:"
echo "  source $SHELL_CONFIG"
echo ""
echo "Or just open a new terminal."
echo ""
echo "Usage:"
echo "  $COMMAND_NAME --help                    # Show help"
echo "  $COMMAND_NAME git@github.com:org/repo   # Deploy a repo"
echo "  $COMMAND_NAME --skip-vm <repo>          # Add repo to existing VM"
echo ""
echo "🐕 Woof!"

