# Cloud Auggie 🐕☁️

**Remote GCP VM for running Augment AI on long-running tasks**

## What is Cloud Auggie?

Cloud Auggie is a GCP VM that lets you:
- Run Augment remotely and close your laptop
- Clone multiple git repos and work on them in the cloud
- Let the agent commit and push changes back to GitHub
- Access GCP resources (compute, GKE, storage) from the cloud

Perfect for tasks that take hours - deploy Cloud Auggie, start your task in tmux, detach, and check back later.

## Installation

### Install the Agent Skill (Recommended)

Install the Cloud Auggie skill so AI agents know how to deploy to cloud VMs:

```bash
# Install to all agents (Claude Code, Cursor, Copilot, Augment, etc.)
# Use SSH URL to avoid password prompts:
npx ai-agent-skills install git@github.com:jeremyplichta/cloud-auggie.git

# Or install to a specific agent only
npx ai-agent-skills install git@github.com:jeremyplichta/cloud-auggie.git --agent claude
```

> **Note:** Using the SSH URL (`git@github.com:...`) avoids username/password prompts if you have SSH keys configured with GitHub.

This uses the [universal skills installer](https://github.com/skillcreatorai/Ai-Agent-Skills) that works with Claude Code, Cursor, VS Code Copilot, Augment/Auggie, Gemini CLI, and more.

### Install the `ca` Command

Install the `ca` command to run Cloud Auggie from anywhere:

```bash
# Clone the repo
git clone git@github.com:jeremyplichta/cloud-auggie.git
cd cloud-auggie

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

- Google Cloud SDK (`gcloud`) installed and configured
- Terraform installed
- Auggie CLI installed locally (`npm install -g @augmentcode/auggie`)
- GitHub authentication (SSH key or PAT - see below)

## Quick Start

### Option A: SSH Key (Recommended for Enterprise)

SSH keys work with enterprise GitHub orgs where fine-grained PATs aren't available.

```bash
# 1. Generate a dedicated key (no passphrase)
ssh-keygen -t ed25519 -f ~/.ssh/cloud-auggie -C "cloud-auggie" -N ""

# 2. Add to GitHub using gh CLI
gh ssh-key add ~/.ssh/cloud-auggie.pub --title "cloud-auggie"

# 3. Login to Augment
auggie login

# 4. Deploy with SSH key
SSH_KEY=~/.ssh/cloud-auggie ./deploy.sh git@github.com:your-org/your-repo.git
```

**Cleanup:** Remove the key when done:
```bash
gh ssh-key list                  # Find the key ID
gh ssh-key delete <key-id>       # Delete from GitHub
rm ~/.ssh/cloud-auggie*          # Delete local files
```

### Option B: GitHub PAT (For Personal Repos)

Fine-grained PATs work for repos in your personal GitHub account.

1. Go to: https://github.com/settings/tokens?type=beta
2. Generate token with: Contents (Read/Write), Metadata (Read)
3. Save it:
   ```bash
   echo "github_pat_xxxx" > ~/.github-cloud-auggie-token
   chmod 600 ~/.github-cloud-auggie-token
   ```
4. Deploy:
   ```bash
   auggie login
   GITHUB_TOKEN_FILE=~/.github-cloud-auggie-token ./deploy.sh https://github.com/youruser/yourrepo.git
   ```

### 4. SSH and Start Working

```bash
gcloud compute ssh cloud-auggie --zone=us-central1-a

# On the VM:
cd /workspace/yourrepo
tmux new -s auggie
auggie
```

### 5. Agent Can Push Changes

The agent can commit and push directly to GitHub:
```bash
git checkout -b feature/ai-changes
git add . && git commit -m "Changes from cloud-auggie"
git push -u origin feature/ai-changes
```

## Adding More Repos to Existing VM

```bash
# SSH key
SSH_KEY=~/.ssh/cloud-auggie ./deploy.sh --skip-vm git@github.com:org/another-repo.git

# Or with PAT
GITHUB_TOKEN_FILE=~/.github-cloud-auggie-token ./deploy.sh --skip-vm https://github.com/user/repo.git
```

## Usage Reference

```
Usage: ca [OPTIONS] [REPO_URL...]
       ./deploy.sh [OPTIONS] [REPO_URL...]

Arguments:
  REPO_URL    GitHub repo URL(s) to clone
              SSH:   git@github.com:org/repo.git
              HTTPS: https://github.com/org/repo.git

Options:
  --create-vm       Force VM creation even if it exists
  --skip-vm         Skip VM creation, only deploy repos
  --skip-creds      Skip credential transfer
  -h, --help        Show help

Environment Variables:
  SSH_KEY           Path to SSH private key (for enterprise)
  GITHUB_TOKEN      GitHub PAT for cloning/pushing (for personal)
  GITHUB_TOKEN_FILE Path to file containing GitHub PAT
  ZONE              GCP zone (default: us-central1-a)
  MACHINE_TYPE      VM machine type (default: n2-standard-4)
  CLUSTER_NAME      Optional GKE cluster name
```

## Tmux Cheat Sheet

```bash
tmux new -s auggie      # Create new session
Ctrl+b, then d          # Detach (keep running)
tmux attach -t auggie   # Reattach
tmux ls                 # List sessions
```

## What Gets Installed on the VM

- Node.js 22 + Auggie CLI
- Git (with your GitHub credentials)
- kubectl, gcloud SDK
- tmux, vim, jq, python3

## Security Notes

- **GitHub PAT:** Use fine-grained tokens scoped to specific repos only
- **Augment Token:** Stored securely in `~/.augment-token`
- **Credentials:** Never committed to git (see `.gitignore`)

## Cleanup

```bash
terraform destroy -auto-approve
```

## Cost

- **VM cost:** ~$0.19/hour (n2-standard-4)
- **Recommendation:** Destroy when not actively using

## 🐕 Happy Hacking!

