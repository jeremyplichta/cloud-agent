# Cloud Agent 🐕☁️

**Remote GCP VM for running AI coding agents on long-running tasks**

## What is Cloud Agent?

Cloud Agent is a GCP VM that lets you:
- Run AI coding agents (Auggie, Claude Code, etc.) remotely and close your laptop
- Clone multiple git repos and work on them in the cloud
- Let the agent commit and push changes back to GitHub
- Access GCP resources (compute, GKE, storage) from the cloud

Perfect for tasks that take hours - deploy Cloud Agent, start your task in tmux, detach, and check back later.

## Supported Agents

| Agent | Status | Command |
|-------|--------|---------|
| [Auggie](https://www.augmentcode.com/) (Augment CLI) | ✅ Supported | `--agent auggie` (default) |
| [Claude Code](https://claude.ai/code) | ✅ Supported | `--agent claude` |

Want to add support for another agent? See [Adding New Agent Hooks](#adding-new-agent-hooks) below.

## Installation

### Install the Agent Skill (Recommended)

Install the Cloud Agent skill so AI agents know how to deploy to cloud VMs:

```bash
# Install to all agents (Claude Code, Cursor, Copilot, Augment, etc.)
# Use SSH URL to avoid password prompts:
npx ai-agent-skills install git@github.com:jeremyplichta/cloud-agent.git

# Or install to a specific agent only
npx ai-agent-skills install git@github.com:jeremyplichta/cloud-agent.git --agent claude
```

> **Note:** Using the SSH URL (`git@github.com:...`) avoids username/password prompts if you have SSH keys configured with GitHub.

This uses the [universal skills installer](https://github.com/skillcreatorai/Ai-Agent-Skills) that works with Claude Code, Cursor, VS Code Copilot, Augment/Auggie, Gemini CLI, and more.

### Install the `ca` Command

Install the `ca` command to run Cloud Agent from anywhere:

```bash
# Clone the repo
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent

# Install the ca command
./install.sh
```

This adds the `ca` function to your `.zshrc` (or `.bashrc`). Then restart your terminal or run:

```bash
source ~/.zshrc
```

Now you can use `ca` from any directory:

```bash
ca --help
ca git@github.com:org/repo.git
```

To uninstall:

```bash
./uninstall.sh
```

## Prerequisites

- **Google Cloud SDK (`gcloud`)** installed, authenticated, and configured with a project:
  ```bash
  # Install: https://cloud.google.com/sdk/docs/install
  gcloud auth login
  gcloud config set project YOUR_PROJECT_ID
  ```
- **Terraform** installed:
  ```bash
  # macOS
  brew install terraform
  # Linux: https://developer.hashicorp.com/terraform/install
  ```
- Your chosen **agent CLI** installed and logged in locally:
  - **Auggie**: `npm install -g @augmentcode/auggie` then `auggie login`
  - **Claude Code**: `npm install -g @anthropic-ai/claude-code` then run `claude` to login
- **GitHub authentication** (SSH key or PAT - see below)

## Quick Start

### Option A: SSH Key (Recommended for Enterprise)

SSH keys work with enterprise GitHub orgs where fine-grained PATs aren't available.

```bash
# 1. Generate a dedicated key (no passphrase)
ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent" -N ""

# 2. Add to GitHub using gh CLI
gh ssh-key add ~/.ssh/cloud-agent.pub --title "cloud-agent"

# 3. Login to your agent locally
auggie login          # For Auggie
# or run 'claude' and complete login for Claude Code

# 4. Deploy with SSH key (defaults to Auggie)
SSH_KEY=~/.ssh/cloud-agent ./deploy.sh git@github.com:your-org/your-repo.git

# Or deploy with Claude Code
SSH_KEY=~/.ssh/cloud-agent ./deploy.sh --agent claude git@github.com:your-org/your-repo.git
```

**Cleanup:** Remove the key when done:
```bash
gh ssh-key list                  # Find the key ID
gh ssh-key delete <key-id>       # Delete from GitHub
rm ~/.ssh/cloud-agent*          # Delete local files
```

### Option B: GitHub PAT (For Personal Repos)

Fine-grained PATs work for repos in your personal GitHub account.

1. Go to: https://github.com/settings/tokens?type=beta
2. Generate token with: Contents (Read/Write), Metadata (Read)
3. Save it:
   ```bash
   echo "github_pat_xxxx" > ~/.github-cloud-agent-token
   chmod 600 ~/.github-cloud-agent-token
   ```
4. Deploy:
   ```bash
   auggie login
   GITHUB_TOKEN_FILE=~/.github-cloud-agent-token ./deploy.sh https://github.com/youruser/yourrepo.git
   ```

### 4. SSH and Start Working

```bash
# Easy way (auto-attaches to tmux):
ca --ssh

# Or manually:
gcloud compute ssh <your-vm-name> --zone=us-central1-a

# On the VM:
cd /workspace/yourrepo
tmux new -s auggie
auggie
```

**Note:** VM name is `{username}-cloud-agent` (e.g., `john.doe-cloud-agent`)

### 5. Agent Can Push Changes

The agent can commit and push directly to GitHub:
```bash
git checkout -b feature/ai-changes
git add . && git commit -m "Changes from cloud-agent"
git push -u origin feature/ai-changes
```

## Adding More Repos to Existing VM

```bash
# SSH key
SSH_KEY=~/.ssh/cloud-agent ./deploy.sh --skip-vm git@github.com:org/another-repo.git

# Or with PAT
GITHUB_TOKEN_FILE=~/.github-cloud-agent-token ./deploy.sh --skip-vm https://github.com/user/repo.git
```

## Usage Reference

```
Usage: ca [OPTIONS] [REPO_URL...]
       ./deploy.sh [OPTIONS] [REPO_URL...]

If no REPO_URL is provided and you're in a git repo, uses the 'origin' remote.

Arguments:
  REPO_URL    GitHub repo URL(s) to clone
              SSH:   git@github.com:org/repo.git
              HTTPS: https://github.com/org/repo.git

Options:
  --agent NAME      Agent to use: auggie (default), claude
  --create-vm       Force VM creation even if it exists
  --skip-vm         Skip VM creation, only deploy repos
  --skip-creds      Skip credential transfer
  --skip-deletion VALUE
                    Set skip_deletion label (default: yes)
                    Use "no" or "false" to allow automatic deletion
  --permissions LIST
                    Comma-separated permissions for VM service account
                    By default, VM has no service account (no GCP API access)
                    Options: admin, compute, gke, storage, network, bigquery,
                             bq, iam, logging, pubsub, sql, secrets, dns, run, functions
  --list            List cloud-agent VMs and their status
  --start           Start a stopped cloud-agent VM
  --stop            Stop (but don't delete) the cloud-agent VM
  --terminate       Terminate (delete) the cloud-agent VM
  --ssh             SSH into the VM and attach to tmux session
  -h, --help        Show help

Environment Variables:
  AGENT             Agent to use (same as --agent)
  SSH_KEY           Path to SSH private key (for enterprise)
  GITHUB_TOKEN      GitHub PAT for cloning/pushing (for personal)
  GITHUB_TOKEN_FILE Path to file containing GitHub PAT
  ZONE              GCP zone (default: us-central1-a)
  MACHINE_TYPE      VM machine type (default: n2-standard-4)
  CLUSTER_NAME      Optional GKE cluster name
  SKIP_DELETION     Set skip_deletion label (default: yes)
  PERMISSIONS       Comma-separated VM permissions (default: none)
```

### VM Management

```bash
ca                  # Deploy current repo (auto-detects origin)
ca --list           # List all cloud-agent VMs
ca --ssh            # SSH and attach to tmux session
ca --stop           # Stop VM (preserves data)
ca --start          # Start a stopped VM
ca --terminate      # Delete VM (with confirmation)

# With GCP permissions (creates a service account)
ca --permissions admin git@github.com:org/repo.git          # Full admin access
ca --permissions compute,gke,storage git@github.com:org/repo.git  # Specific permissions
```

## Tmux Cheat Sheet

```bash
tmux new -s auggie      # Create new session
Ctrl+b, then d          # Detach (keep running)
tmux attach -t auggie   # Reattach
tmux ls                 # List sessions
```

## What Gets Installed on the VM

- Node.js 22 + your chosen agent CLI
- Git (with your GitHub credentials)
- kubectl, gcloud SDK
- tmux, vim, jq, python3

## Security Notes

- **VM Permissions:** By default, VMs have **no service account** and cannot access GCP APIs. Use `--permissions` only when needed.
- **GitHub PAT:** Use fine-grained tokens scoped to specific repos only
- **Agent Credentials:** Stored securely in agent-specific locations
- **Credentials:** Never committed to git (see `.gitignore`)

## Cleanup

```bash
# Terminate (delete) the VM
ca --terminate

# Or stop it to save costs but keep data
ca --stop

# Or use terraform directly
cd ~/.cloud-agent && terraform destroy -auto-approve
```

## Cost

- **VM cost:** ~$0.19/hour (n2-standard-4)
- **Recommendation:** Use `ca --stop` when not actively using, `ca --terminate` when done

---

## Adding New Agent Hooks

Cloud Agent uses a hook system to support different AI coding agents. Each agent has a hook file in the `hooks/` directory that handles credential detection and transfer.

### Hook File Structure

Create a new file `hooks/<agent-name>.sh`:

```bash
#!/bin/bash
# Agent Hook: Your Agent Name
# This hook handles credential transfer for Your Agent

# Required variables
HOOK_NAME="agent-name"                    # Short name (used in --agent flag)
HOOK_DISPLAY_NAME="Your Agent Name"       # Display name for logs
HOOK_CLI_COMMAND="agent-cli"              # CLI command name
HOOK_INSTALL_COMMAND="npm install -g your-agent"  # Install instructions

# Check if the agent CLI is available locally
hook_check_local() {
    command -v "$HOOK_CLI_COMMAND" &> /dev/null
}

# Check if the agent is logged in locally
hook_check_logged_in() {
    # Return 0 if logged in, 1 if not
    # Example: check for credential file or run a command
    [ -f ~/.your-agent/credentials.json ]
}

# Get the credential token/data to transfer
hook_get_token() {
    # Output the credential data (will be passed to hook_transfer_credentials)
    cat ~/.your-agent/credentials.json
}

# Transfer credentials to the remote VM
# Arguments: $1 = zone, $2 = token/credential data
hook_transfer_credentials() {
    local zone="$1"
    local token="$2"

    gcloud compute ssh cloud-agent --zone="$zone" --command="
        mkdir -p ~/.your-agent
        echo '$token' > ~/.your-agent/credentials.json
        chmod 600 ~/.your-agent/credentials.json
        echo '✅ Your Agent credentials configured'
    " 2>/dev/null
}

# Get the command to run the agent on the VM
hook_agent_command() {
    echo "$HOOK_CLI_COMMAND"
}

# Get login instructions for the user
hook_login_instructions() {
    echo "Run '$HOOK_CLI_COMMAND login' locally first."
}
```

### Required Functions

| Function | Purpose |
|----------|---------|
| `hook_check_local` | Returns 0 if CLI is installed locally |
| `hook_check_logged_in` | Returns 0 if user is logged in |
| `hook_get_token` | Outputs credential data to transfer |
| `hook_transfer_credentials` | Transfers credentials to VM |
| `hook_agent_command` | Returns the command to run the agent |
| `hook_login_instructions` | Returns login help message |

### Testing Your Hook

```bash
# Test with your new agent
./deploy.sh --agent your-agent git@github.com:org/repo.git

# Or using environment variable
AGENT=your-agent ./deploy.sh git@github.com:org/repo.git
```

### Contributing

1. Create your hook file in `hooks/`
2. Test it works with `--agent your-agent`
3. Update the "Supported Agents" table in this README
4. Submit a PR!

---

## 🐕 Happy Hacking!

