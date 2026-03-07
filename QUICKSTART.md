# Quick Start Guide

Get up and running with cloud-agent in 5 minutes!

## Prerequisites

- ✅ Rust installed ([rustup.rs](https://rustup.rs/))
- ✅ Google Cloud SDK (`gcloud`)
- ✅ Terraform
- ✅ SSH key for GitHub

## Step 1: Build Cloud Agent

```bash
# Clone the repository
git clone git@github.com:jeremyplichta/cloud-agent.git
cd cloud-agent

# Build and install
./build.sh
```

Or manually:

```bash
cargo build --release
cp target/release/ca ~/.local/bin/ca
```

## Step 2: Configure GCP

```bash
# Login to GCP
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

## Step 3: Set Up SSH Key

If you don't have an SSH key for GitHub:

```bash
# Generate a new key
ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent"

# Add the public key to GitHub
cat ~/.ssh/cloud-agent.pub
# Copy this and add it to: https://github.com/settings/keys
```

## Step 4: Deploy Your First Repo

```bash
# Deploy a repository
SSH_KEY=~/.ssh/cloud-agent ca git@github.com:yourorg/yourrepo.git
```

This will:
1. ✅ Create a GCP VM
2. ✅ Configure firewall rules
3. ✅ Transfer your SSH keys
4. ✅ Transfer agent credentials
5. ✅ Clone your repository
6. ✅ Set up tmux

## Step 5: Connect and Work

```bash
# SSH into the VM
ca ssh

# On the VM, navigate to your repo
cd /workspace/yourrepo

# Start your AI agent
auggie  # or claude, or codex
```

## Common Commands

```bash
# List VMs
ca list

# Stop VM (save costs)
ca stop

# Start VM
ca start

# Copy files
ca scp ./file.txt vm:/workspace/
ca scp vm:/workspace/output.txt ./

# Terminate VM (delete)
ca terminate
```

## Environment Variables

Set these for convenience:

```bash
# Add to ~/.bashrc or ~/.zshrc
export SSH_KEY=~/.ssh/cloud-agent
export COMPANY=yourcompany.com  # Optional: for username derivation
export AGENT=auggie              # Default agent (auggie, claude, codex)
```

Then you can just run:

```bash
ca git@github.com:org/repo.git
```

## Troubleshooting

### "cargo: command not found"

Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### "gcloud: command not found"

Install Google Cloud SDK:
```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

### "No GCP project configured"

```bash
gcloud config set project YOUR_PROJECT_ID
```

### "SSH connection failed"

Make sure your SSH key is added to GitHub:
```bash
cat ~/.ssh/cloud-agent.pub
# Add this to: https://github.com/settings/keys
```

### "Could not detect public IP"

Check your internet connection. The tool needs to detect your IP for firewall rules.

## Next Steps

- Read the [full README](README-RUST.md)
- Check out [usage examples](examples/basic_usage.md)
- Learn about [migration from bash](MIGRATION.md)
- Read the [contributing guide](CONTRIBUTING.md)

## Getting Help

- 📖 Documentation: See README-RUST.md
- 🐛 Issues: https://github.com/jeremyplichta/cloud-agent/issues
- 💬 Questions: Open a GitHub discussion

## Tips

1. **Save costs**: Stop your VM when not in use with `ca stop`
2. **Multiple repos**: Deploy multiple repos at once
3. **Different agents**: Try different agents with `--agent`
4. **Custom machine types**: Use `--machine-type` for bigger/smaller VMs
5. **Permissions**: Grant GCP permissions with `--permissions`

Happy coding! 🦀

