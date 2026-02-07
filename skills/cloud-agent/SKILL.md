---
name: cloud-agent
description: Deploy your current work to a cloud VM so an AI agent can continue working while you're away. Use this skill when the user needs to close their laptop (flight, meeting, etc.) but wants work to continue on a GCP VM.
---

# Cloud Agent - Handoff to Cloud VM

Use this skill when the user needs to:
- Close their laptop but wants AI work to continue
- Hand off a long-running task to a cloud instance
- Continue a coding session from another machine

## Supported Agents

Cloud Agent supports multiple AI coding agents. You MUST determine which agent you are and use the correct `--agent` flag:

| Agent | Hook Name | How to Detect |
|-------|-----------|---------------|
| Auggie (Augment CLI) | `auggie` | You are running as `auggie` CLI |
| Claude Code | `claude` | You are running as `claude` CLI or Claude Code |

**IMPORTANT**: If you are not one of the supported agents listed above, STOP and inform the user that their agent is not yet supported. Direct them to the README for instructions on adding a new agent hook.

## Prerequisites Check

Before deploying, verify these prerequisites are met:

### 1. Determine which agent you are

First, identify yourself:
- If you are **Auggie** (Augment CLI agent): use `--agent auggie` (or omit, it's the default)
- If you are **Claude Code**: use `--agent claude`

### 2. Check if `ca` command is installed

```bash
which ca || type ca
```

If `ca` is NOT found, install it:

```bash
# Clone cloud-agent repo to a standard location
git clone git@github.com:jeremyplichta/cloud-agent.git ~/.cloud-agent

# Run the installer
cd ~/.cloud-agent && ./install.sh

# Source the shell config to make ca available immediately
source ~/.zshrc 2>/dev/null || source ~/.bashrc 2>/dev/null
```

### 3. Check that your agent hook exists

```bash
ls ~/.cloud-agent/hooks/
```

Verify your agent's hook file exists (e.g., `auggie.sh` or `claude.sh`). If not, the agent is not supported.

### 4. Check Terraform is installed

```bash
which terraform && terraform version
```

If Terraform is NOT found, install it:
- **macOS**: `brew install terraform`
- **Linux**: See https://developer.hashicorp.com/terraform/install

### 5. Check GCP credentials

```bash
gcloud auth list
```

If not authenticated, run:
```bash
gcloud auth login
```

### 6. Check SSH key for GitHub

```bash
ls ~/.ssh/cloud-agent 2>/dev/null || ls ~/.ssh/id_ed25519 2>/dev/null
```

If no SSH key exists for cloud-agent, create one:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent" -N ""
gh ssh-key add ~/.ssh/cloud-agent.pub --title "cloud-agent"
```

## Handoff Workflow

### Step 1: Prepare the Code

First, ensure all work is committed and pushed:

```bash
# Check current git status
git status

# If there are uncommitted changes, commit them
git add -A
git commit -m "WIP: Handoff to cloud-agent"

# Ensure we're on a branch (not main/master)
git branch --show-current

# If on main, create a new branch
git checkout -b cloud-agent-handoff-$(date +%Y%m%d-%H%M%S)

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

Run the `ca` command to deploy. **You MUST pass the correct `--agent` flag for your agent type:**

```bash
# For Auggie (default, can omit --agent)
ca --agent auggie git@github.com:org/repo.git

# For Claude Code
ca --agent claude git@github.com:org/repo.git

# With explicit SSH key
SSH_KEY=~/.ssh/your-key ca --agent <your-agent> git@github.com:org/repo.git

# Optional: specify zone or machine type
ZONE=us-central1-a MACHINE_TYPE=n1-standard-4 ca --agent <your-agent> git@github.com:org/repo.git
```

**Replace `<your-agent>` with your agent hook name: `auggie` or `claude`**

The deployment will:
- Create a GCP VM named `cloud-agent`
- Transfer SSH keys and your agent's credentials
- Clone the repository at the current branch
- Install your agent CLI on the VM

### Step 4: Provide Handoff Instructions

After deployment, give the user these commands to reconnect:

```bash
# SSH to the instance
gcloud compute ssh cloud-agent --zone=us-central1-a

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

**Agent Response** (example for Claude Code agent):
1. Verify you are a supported agent (Claude Code → use `--agent claude`)
2. Commit current changes with descriptive message
3. Create/switch to a feature branch if on main
4. Push to remote
5. Run: `ca --agent claude git@github.com:org/repo.git`
6. Provide reconnection instructions
7. Remind user to run `ca --destroy` when done

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AGENT` | Agent hook to use | `auggie` |
| `SSH_KEY` | Path to SSH private key | `~/.ssh/cloud-agent` |
| `ZONE` | GCP zone for the VM | `us-central1-a` |
| `MACHINE_TYPE` | GCP machine type | `n2-standard-4` |
| `GITHUB_TOKEN` | GitHub PAT (or use `GITHUB_TOKEN_FILE`) | - |

## Notes

- **You MUST use the correct `--agent` flag for your agent type**
- The cloud VM clones the repo at the **current branch** you pushed
- Work done on the VM needs to be committed and pushed back
- The tmux session is named `auggie` - use `tmux attach -t auggie` to reconnect
- Default VM location is `us-central1-a` - adjust `ZONE` if needed for latency
- If your agent is not supported, inform the user and direct them to add a new hook

