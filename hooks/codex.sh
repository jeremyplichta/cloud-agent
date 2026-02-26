#!/bin/bash
# Agent Hook: Codex (OpenAI CLI)
# This hook handles credential transfer for the OpenAI Codex CLI agent

HOOK_NAME="codex"
HOOK_DISPLAY_NAME="Codex (OpenAI CLI)"
HOOK_CLI_COMMAND="codex"
HOOK_INSTALL_COMMAND="npm install -g @openai/codex"

# Check if the agent CLI is available locally
hook_check_local() {
    if command -v codex &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if the agent is logged in locally
hook_check_logged_in() {
    # Check if ~/.codex/config.toml exists
    if [ -f ~/.codex/config.toml ]; then
        return 0
    else
        return 1
    fi
}

# Get the credential token to transfer
# For Codex, we transfer the config.toml file
hook_get_token() {
    if [ -f ~/.codex/config.toml ]; then
        cat ~/.codex/config.toml
    else
        echo ""
    fi
}

# Transfer credentials to the remote VM
# Arguments: $1 = zone, $2 = token (config file content), $3 = vm_name
hook_transfer_credentials() {
    local zone="$1"
    local token="$2"
    local vm_name="$3"

    # Create a temp file to transfer (avoids shell escaping issues)
    local temp_file=$(mktemp)
    echo "$token" > "$temp_file"

    gcloud compute scp "$temp_file" "$vm_name":~/codex-config-temp.toml --zone="$zone" 2>/dev/null
    gcloud compute ssh "$vm_name" --zone="$zone" --command="
        mkdir -p ~/.codex
        mv ~/codex-config-temp.toml ~/.codex/config.toml
        chmod 600 ~/.codex/config.toml
        echo '✅ Codex credentials configured'
    " 2>/dev/null

    rm -f "$temp_file"
}

# Install the agent CLI on the remote VM (called by startup script)
hook_install_on_vm() {
    cat << 'EOF'
# Install Node.js 22 (required for Codex CLI)
log "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Codex CLI
log "Installing Codex CLI..."
npm install -g @openai/codex
EOF
}

# Get the command to run the agent on the VM
hook_agent_command() {
    echo "codex"
}

# Get login instructions for the user
hook_login_instructions() {
    echo "Run 'codex' locally and complete the login flow first, or set OPENAI_API_KEY."
}

