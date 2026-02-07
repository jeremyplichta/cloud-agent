#!/bin/bash
# Agent Hook: Auggie (Augment CLI)
# This hook handles credential transfer for the Auggie CLI agent

HOOK_NAME="auggie"
HOOK_DISPLAY_NAME="Auggie (Augment CLI)"
HOOK_CLI_COMMAND="auggie"
HOOK_INSTALL_COMMAND="npm install -g @augmentcode/auggie"

# Check if the agent CLI is available locally
hook_check_local() {
    if command -v auggie &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if the agent is logged in locally
hook_check_logged_in() {
    if auggie tokens print &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get the credential token to transfer
hook_get_token() {
    # Extract just the JSON token from auggie tokens print output
    auggie tokens print 2>/dev/null | grep -o '{.*}' | head -1
}

# Transfer credentials to the remote VM
# Arguments: $1 = zone, $2 = token
hook_transfer_credentials() {
    local zone="$1"
    local token="$2"
    
    gcloud compute ssh cloud-agent --zone="$zone" --command="
        mkdir -p ~/.augment
        echo '$token' > ~/.augment/session.json
        chmod 600 ~/.augment/session.json
        echo '✅ Augment credentials configured'
    " 2>/dev/null
}

# Install the agent CLI on the remote VM (called by startup script)
hook_install_on_vm() {
    cat << 'EOF'
# Install Node.js 22 (required for Auggie CLI)
log "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Auggie CLI
log "Installing Auggie CLI..."
npm install -g @augmentcode/auggie
EOF
}

# Get the command to run the agent on the VM
hook_agent_command() {
    echo "auggie"
}

# Get login instructions for the user
hook_login_instructions() {
    echo "Run 'auggie login' locally first."
}

