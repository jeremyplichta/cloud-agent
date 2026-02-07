#!/bin/bash
# Agent Hook: Claude Code
# This hook handles credential transfer for the Claude Code CLI agent

HOOK_NAME="claude"
HOOK_DISPLAY_NAME="Claude Code"
HOOK_CLI_COMMAND="claude"
HOOK_INSTALL_COMMAND="npm install -g @anthropic-ai/claude-code"

# Check if the agent CLI is available locally
hook_check_local() {
    if command -v claude &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if the agent is logged in locally
hook_check_logged_in() {
    # Check if ~/.claude.json exists and has oauthAccount
    if [ -f ~/.claude.json ] && grep -q '"oauthAccount"' ~/.claude.json 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get the credential token to transfer
# For Claude, we transfer the entire settings file
hook_get_token() {
    if [ -f ~/.claude.json ]; then
        cat ~/.claude.json
    else
        echo ""
    fi
}

# Transfer credentials to the remote VM
# Arguments: $1 = zone, $2 = token (settings file content)
hook_transfer_credentials() {
    local zone="$1"
    local token="$2"
    
    # Create a temp file to transfer (avoids shell escaping issues with large JSON)
    local temp_file=$(mktemp)
    echo "$token" > "$temp_file"
    
    gcloud compute scp "$temp_file" cloud-agent:~/.claude.json --zone="$zone" 2>/dev/null
    gcloud compute ssh cloud-agent --zone="$zone" --command="
        chmod 600 ~/.claude.json
        mkdir -p ~/.claude
        echo '✅ Claude Code credentials configured'
    " 2>/dev/null
    
    rm -f "$temp_file"
}

# Install the agent CLI on the remote VM (called by startup script)
hook_install_on_vm() {
    cat << 'EOF'
# Install Node.js 22 (required for Claude Code)
log "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Claude Code CLI
log "Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code
EOF
}

# Get the command to run the agent on the VM
hook_agent_command() {
    echo "claude"
}

# Get login instructions for the user
hook_login_instructions() {
    echo "Run 'claude' locally and complete the login flow first."
}

