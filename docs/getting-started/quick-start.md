# Quick Start

Get your first Cloud Agent VM running in 5 minutes.

## 1. Deploy a Repository

From inside a git repository:

```bash
# Deploy the current repo (auto-detects git origin)
ca
```

Or specify a repository:

```bash
# Deploy a specific repo
SSH_KEY=~/.ssh/cloud-agent ca git@github.com:your-org/your-repo.git
```

!!! note "First Run"
    The first deployment takes a few minutes as Terraform provisions the VM and installs dependencies.

## 2. SSH into Your VM

```bash
# Connect and auto-attach to tmux
ca ssh
```

You'll be dropped into a tmux session on your VM.

## 3. Start the AI Agent

```bash
# Navigate to your repo
cd /workspace/your-repo

# Start the agent
auggie  # or 'claude' for Claude Code
```

## 4. Detach and Go

Press `Ctrl+B` then `D` to detach from tmux. Your agent keeps running!

Later, reconnect with:

```bash
ca ssh
```

## Common Workflows

### Deploy Multiple Repos

```bash
ca git@github.com:org/repo1.git git@github.com:org/repo2.git
```

### Use a Different Agent

```bash
ca --agent claude git@github.com:org/repo.git
```

### Add a Repo to Existing VM

```bash
ca --skip-vm git@github.com:org/another-repo.git
```

### Check VM Status

```bash
ca list
```

### Stop Your VM (Save Costs)

```bash
ca stop
```

### Resume Later

```bash
ca start
ca ssh
```

### Clean Up

```bash
ca terminate
```

## Example Session

```bash
$ ca git@github.com:myorg/myapp.git
🔍 Detecting public IP...
✅ Your IP: 203.0.113.42

🚀 Creating VM cloud-agent-jsmith...
✅ VM created successfully

📦 Cloning repositories...
✅ Cloned myapp

🔐 Transferring credentials...
✅ SSH key transferred
✅ Auggie credentials transferred

🎉 Ready! Connect with: ca ssh

$ ca ssh
# Now on the VM in tmux
$ cd /workspace/myapp
$ auggie "Fix all the TODO comments in this project"
```

## Next Steps

- [Command reference](../commands/index.md)
- [Configure GCP access](../configuration/gcp-setup.md)
- [Add custom agents](../agents/adding-agents.md)

