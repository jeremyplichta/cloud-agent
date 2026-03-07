# Auggie (Augment Code)

[Auggie](https://www.augmentcode.com/) is Augment Code's AI coding assistant.

## Prerequisites

### Install Auggie CLI

```bash
npm install -g @anthropic/augment-cli
```

### Login

```bash
auggie login
```

This creates credentials at `~/.augment/` which Cloud Agent transfers to the VM.

## Usage

Deploy with Auggie (default agent):

```bash
ca git@github.com:org/repo.git
```

Or explicitly:

```bash
ca --agent auggie git@github.com:org/repo.git
```

## On the VM

After SSHing into your VM:

```bash
cd /workspace/your-repo
auggie
```

### Common Commands

```bash
# Interactive mode
auggie

# Single task
auggie "Fix the failing tests"

# With context
auggie "Implement the feature described in SPEC.md"
```

## Credentials

| Location | Path |
|----------|------|
| Local | `~/.augment/` |
| VM | `~/.augment/` |

## Troubleshooting

### "Auggie not logged in"

```bash
# Login locally
auggie login

# Then redeploy
ca git@github.com:org/repo.git
```

### "Auggie CLI not found" on VM

The VM startup script should install Auggie. If not:

```bash
# SSH into VM
ca ssh

# Install manually
npm install -g @anthropic/augment-cli
```

### Credentials not working on VM

```bash
# Re-transfer credentials
ca --skip-vm  # Re-runs credential transfer
```

