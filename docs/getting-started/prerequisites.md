# Prerequisites

Before using Cloud Agent, you need to set up a few things.

## Required

### Google Cloud SDK

Install and configure the `gcloud` CLI:

```bash
# Install (see https://cloud.google.com/sdk/docs/install)
# Then authenticate and configure:
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

!!! tip "Project Setup"
    Make sure your GCP project has Compute Engine API enabled:
    ```bash
    gcloud services enable compute.googleapis.com
    ```

### Terraform

Cloud Agent uses Terraform to provision GCP resources:

=== "macOS"

    ```bash
    brew install terraform
    ```

=== "Linux"

    ```bash
    # Ubuntu/Debian
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install terraform
    ```

### SSH Key for GitHub

You need an SSH key that can clone your repositories:

```bash
# Generate a new key (if you don't have one)
ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent"

# Add the public key to GitHub
cat ~/.ssh/cloud-agent.pub
# Copy and add to: GitHub → Settings → SSH Keys
```

## Optional

### AI Agent Authentication

Depending on which agent you use, you may need to authenticate:

=== "Auggie"

    ```bash
    # Install Auggie CLI
    npm install -g @anthropic/augment-cli
    
    # Login
    auggie login
    ```

=== "Claude Code"

    ```bash
    # Install Claude Code
    npm install -g @anthropic/claude-code
    
    # Login
    claude login
    ```

Cloud Agent will transfer your local credentials to the VM.

## Verify Setup

Run these commands to verify your setup:

```bash
# Check gcloud
gcloud config get project

# Check Terraform
terraform version

# Check SSH key
ls -la ~/.ssh/*.pub

# Check Cloud Agent
ca --help
```

## Next Steps

- [Quick start guide](quick-start.md)

