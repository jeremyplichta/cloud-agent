#!/bin/bash
# Install the cloud-agent skill to your personal skills directory
# This makes the skill available across all your projects

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="cloud-agent"
SKILL_SOURCE="$SCRIPT_DIR/skills/$SKILL_NAME"

# Determine which skills directory to use
# Claude Code uses ~/.claude/skills
# VS Code Copilot uses ~/.copilot/skills
# We'll install to both if they exist, or create ~/.claude/skills by default

install_skill() {
    local target_dir="$1"
    local target_path="$target_dir/$SKILL_NAME"
    
    echo "Installing skill to $target_path..."
    mkdir -p "$target_path"
    cp -r "$SKILL_SOURCE"/* "$target_path/"
    echo "✓ Installed to $target_path"
}

# Check if source skill exists
if [ ! -d "$SKILL_SOURCE" ]; then
    echo "Error: Skill source not found at $SKILL_SOURCE"
    echo "Make sure you're running this from the cloud-agent repository root."
    exit 1
fi

echo "Installing $SKILL_NAME skill..."
echo ""

# Install to Claude Code skills directory
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
install_skill "$CLAUDE_SKILLS_DIR"

# Also install to VS Code Copilot skills directory if it exists
COPILOT_SKILLS_DIR="$HOME/.copilot/skills"
if [ -d "$HOME/.copilot" ]; then
    install_skill "$COPILOT_SKILLS_DIR"
fi

echo ""
echo "✅ Skill installed successfully!"
echo ""
echo "The '$SKILL_NAME' skill is now available in:"
echo "  - Claude Code (restart to discover)"
echo "  - VS Code Copilot (if ~/.copilot exists)"
echo ""
echo "Usage: When working in any project, you can now ask your AI agent to"
echo "       'hand off to cloud-agent' or 'deploy to cloud VM' and it will"
echo "       know how to commit, push, and deploy your work."
echo ""
echo "To uninstall:"
echo "  rm -rf ~/.claude/skills/$SKILL_NAME"
echo "  rm -rf ~/.copilot/skills/$SKILL_NAME"

