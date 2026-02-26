#!/bin/bash

set -e

LOG="/var/log/cloud-agent-startup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"
}

log "╔══════════════════════════════════════════════════════════════╗"
log "║  🐕 CLOUD AGENT STARTUP - INITIALIZING                      ║"
log "╚══════════════════════════════════════════════════════════════╝"

# Update system
log "Updating system packages..."
apt-get update -qq
apt-get install -y -qq \
    curl \
    wget \
    git \
    tmux \
    vim \
    jq \
    python3 \
    python3-pip \
    unzip \
    tar \
    gzip

# Install gcloud SDK (if not already installed)
log "Installing Google Cloud SDK..."
if ! command -v gcloud &> /dev/null; then
    curl https://sdk.cloud.google.com | bash -s -- --disable-prompts
    source /root/.bashrc
fi

# Install kubectl
log "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Node.js 22 (required for AI coding agents)
log "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install AI coding agent CLIs
log "Installing Auggie CLI (Augment Code)..."
npm install -g @augmentcode/auggie

log "Installing Claude Code CLI (Anthropic)..."
npm install -g @anthropic-ai/claude-code

log "Installing Codex CLI (OpenAI)..."
npm install -g @openai/codex

# Configure kubectl for the cluster (if cluster_name is provided)
if [ -n "${cluster_name}" ] && [ "${cluster_name}" != "" ]; then
    log "Configuring kubectl for cluster ${cluster_name}..."
    gcloud container clusters get-credentials ${cluster_name} \
        --zone=${cluster_zone} \
        --project=${project_id}
else
    log "No GKE cluster specified, skipping kubectl configuration"
fi

# Create workspace directory (world-writable so any user can clone repos)
log "Creating workspace directory..."
mkdir -p /workspace
chmod 777 /workspace
cd /workspace

# Secure SSH configuration
log "Securing SSH configuration..."
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup original config
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

# Disable password authentication (key-only)
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSH_CONFIG"
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSH_CONFIG"
sed -i 's/^#*UsePAM.*/UsePAM no/' "$SSH_CONFIG"

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"

# Restrict to specific user if provided
if [ -n "${ssh_username}" ] && [ "${ssh_username}" != "" ]; then
    log "Restricting SSH access to user: ${ssh_username}"

    # Add AllowUsers directive (remove any existing first)
    sed -i '/^AllowUsers/d' "$SSH_CONFIG"
    echo "AllowUsers ${ssh_username}" >> "$SSH_CONFIG"

    # Create the user if it doesn't exist
    if ! id "${ssh_username}" &>/dev/null; then
        log "Creating user: ${ssh_username}"
        useradd -m -s /bin/bash "${ssh_username}"
        usermod -aG sudo "${ssh_username}"
    fi

    # Setup SSH key for the user if provided
    if [ -n "${ssh_public_key}" ] && [ "${ssh_public_key}" != "" ]; then
        log "Configuring SSH key for user: ${ssh_username}"
        SSH_DIR="/home/${ssh_username}/.ssh"
        mkdir -p "$SSH_DIR"
        echo "${ssh_public_key}" > "$SSH_DIR/authorized_keys"
        chmod 700 "$SSH_DIR"
        chmod 600 "$SSH_DIR/authorized_keys"
        chown -R "${ssh_username}:${ssh_username}" "$SSH_DIR"
        log "✅ SSH key configured for ${ssh_username}"
    fi

    # Give the user access to workspace
    chown -R "${ssh_username}:${ssh_username}" /workspace
fi

# Restart SSH service to apply changes
log "Restarting SSH service..."
systemctl restart sshd || systemctl restart ssh

log "✅ SSH secured: password auth disabled, root login disabled"

# Prepare workspace README
log "Preparing workspace..."
cat > /workspace/README.md << EOF
# Cloud Agent Workspace

This VM is ready to run AI coding agents.

## Available Agents

- **Auggie** (Augment Code): \`auggie\`
- **Claude Code** (Anthropic): \`claude\`
- **Codex** (OpenAI): \`codex\`

## Quick Start

1. Start tmux session:
   \`\`\`
   tmux new -s agent
   \`\`\`

2. Navigate to workspace:
   \`\`\`
   cd /workspace
   \`\`\`

3. Run your preferred agent and start working!

## VM Info

- **Project:** ${project_id}
- **Zone:** ${cluster_zone}

## Files

- Your project files will be transferred here by the deploy script

EOF

log "✅ Cloud Agent VM initialized successfully!"
log ""
log "Next steps:"
log "1. Transfer project files to /workspace/"
log "2. SSH in and start tmux"
log "3. Run Augment to continue testing"
log ""
log "Startup complete: $(date)"

