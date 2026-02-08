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

# Install Node.js 22 (required for Auggie CLI)
log "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install Auggie CLI
log "Installing Auggie CLI..."
npm install -g @augmentcode/auggie

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

# Prepare workspace README
log "Preparing workspace..."
cat > /workspace/README.md << EOF
# Cloud Agent Workspace

This VM is ready to run Augment AI.

## Quick Start

1. Start tmux session:
   \`\`\`
   tmux new -s auggie
   \`\`\`

2. Navigate to workspace:
   \`\`\`
   cd /workspace
   \`\`\`

3. Run Augment and start working!

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

