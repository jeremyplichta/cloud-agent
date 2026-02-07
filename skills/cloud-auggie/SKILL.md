---
name: cloud-auggie
description: Deploy your current work to a cloud VM so an AI agent can continue working while you're away. Use this skill when the user needs to close their laptop (flight, meeting, etc.) but wants work to continue on a GCP VM.
---

# Cloud Auggie - Handoff to Cloud VM

Use this skill when the user needs to:
- Close their laptop but wants AI work to continue
- Hand off a long-running task to a cloud instance
- Continue a coding session from another machine

## Prerequisites Check

Before deploying, verify these prerequisites are met:

### 1. Check if `ca` command is installed

```bash
which ca || type ca
```

If `ca` is NOT found, install it:

```bash
# Clone cloud-auggie repo to a standard location
git clone git@github.com:jeremyplichta/cloud-auggie.git ~/.cloud-auggie

# Run the installer
cd ~/.cloud-auggie && ./install.sh

# Source the shell config to make ca available immediately
source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null
```

### 2. Check GCP credentials

```bash
gcloud auth list
```

If not authenticated, run:
```bash
gcloud auth login
```

### 3. Check SSH key for GitHub

```bash
ls ~/.ssh/cloud-auggie 2>/dev/null || ls ~/.ssh/id_ed25519 2>/dev/null
```

If no SSH key exists for cloud-auggie, create one:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/cloud-auggie -C "cloud-auggie" -N ""
gh ssh-key add ~/.ssh/cloud-auggie.pub --title "cloud-auggie"
```

## Handoff Workflow

### Step 1: Prepare the Code

First, ensure all work is committed and pushed:

```bash
# Check current git status
git status

# If there are uncommitted changes, commit them
git add -A
git commit -m "WIP: Handoff to cloud-auggie"

# Ensure we're on a branch (not main/master)
git branch --show-current

# If on main, create a new branch
git checkout -b cloud-auggie-handoff-$(date +%Y%m%d-%H%M%S)

# Push the branch to remote
git push -u origin $(git branch --show-current)
```

### Step 2: Get Repository URL

Get the SSH URL for the current repository:

```bash
git remote get-url origin
```

This should return something like `git@github.com:org/repo.git`

### Step 3: Deploy to Cloud VM

Run the `ca` command to deploy:

```bash
# Basic deployment (uses default SSH key at ~/.ssh/cloud-auggie)
ca git@github.com:org/repo.git

# Or with explicit SSH key
SSH_KEY=~/.ssh/your-key ca git@github.com:org/repo.git

# Optional: specify zone or machine type
ZONE=us-central1-a MACHINE_TYPE=n1-standard-4 ca git@github.com:org/repo.git
```

The deployment will:
- Create a GCP VM named `cloud-auggie`
- Transfer SSH keys and credentials
- Clone the repository at the current branch
- Start an Augment AI session in tmux

### Step 4: Provide Handoff Instructions

After deployment, give the user these commands to reconnect:

```bash
# SSH to the instance
gcloud compute ssh cloud-auggie --zone=us-central1-a

# Once connected, attach to the tmux session
cd /workspace/<repo-name>
tmux attach -t auggie
```

### Step 5: Cleanup (when done)

When the user is finished with the cloud instance:

```bash
# Destroy the VM and cleanup
ca --destroy
```

## Example Conversation Flow

**User**: "I need to catch a flight in 30 minutes but this refactoring isn't done"

**Agent Response**:
1. Commit current changes with descriptive message
2. Create/switch to a feature branch if on main
3. Push to remote
4. Run: `ca git@github.com:org/repo.git`
5. Provide reconnection instructions
6. Remind user to run `ca --destroy` when done

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_KEY` | Path to SSH private key | `~/.ssh/cloud-auggie` |
| `ZONE` | GCP zone for the VM | `us-central1-a` |
| `MACHINE_TYPE` | GCP machine type | `n1-standard-2` |
| `GITHUB_TOKEN` | GitHub PAT (or use `GITHUB_TOKEN_FILE`) | - |

## Notes

- The cloud VM clones the repo at the **current branch** you pushed
- Work done on the VM needs to be committed and pushed back
- The tmux session is named `auggie` - use `tmux attach -t auggie` to reconnect
- Default VM location is `us-central1-a` - adjust `ZONE` if needed for latency

