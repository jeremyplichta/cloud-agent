# Cloud Agent 🐕☁️

**Deploy GCP VMs for AI coding agents - run long tasks while you're away**

Cloud Agent lets you spin up a Google Cloud VM, deploy your repositories, and run AI coding agents remotely. Perfect for tasks that take hours - start your task, close your laptop, and check back later.

## What is Cloud Agent?

Cloud Agent is a CLI tool that:

- 🚀 **Creates GCP VMs** optimized for AI coding agents
- 📦 **Clones your repositories** to the cloud VM
- 🔐 **Transfers credentials** (SSH keys, agent auth) securely
- 🤖 **Runs AI agents** like Auggie or Claude Code remotely
- 💻 **Provides easy SSH access** with automatic tmux sessions

## Why Use Cloud Agent?

### Run Long Tasks Without Your Laptop

AI coding agents can take hours to complete complex tasks. With Cloud Agent:

1. Deploy your repo to a cloud VM
2. Start the agent in tmux
3. Detach and close your laptop
4. Check back later for results

### Full GCP Access

Your cloud agent VM has access to GCP resources:

- Compute Engine instances
- GKE clusters
- Cloud Storage
- BigQuery, Pub/Sub, and more

### Secure by Default

- SSH key-based authentication only
- Firewall rules whitelist your IP
- Credentials transferred securely via SCP

## Supported Agents

| Agent | Status | Description |
|-------|--------|-------------|
| [Auggie](https://www.augmentcode.com/) | ✅ Supported | Augment Code's AI coding assistant |
| [Claude Code](https://claude.ai/code) | ✅ Supported | Anthropic's Claude for coding |

## Quick Example

```bash
# Deploy current repo with default agent (Auggie)
ca

# Deploy specific repo with Claude
ca --agent claude git@github.com:org/repo.git

# SSH into your VM
ca ssh

# List your VMs
ca list
```

## Next Steps

- [Install Cloud Agent](getting-started/installation.md)
- [Quick Start Guide](getting-started/quick-start.md)
- [Command Reference](commands/index.md)

