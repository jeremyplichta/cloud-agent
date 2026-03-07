# Claude Code

[Claude Code](https://claude.ai/code) is Anthropic's AI coding assistant.

## Prerequisites

### Install Claude Code CLI

```bash
npm install -g @anthropic/claude-code
```

### Login

```bash
claude login
```

This creates credentials at `~/.claude/` which Cloud Agent transfers to the VM.

## Usage

Deploy with Claude Code:

```bash
ca --agent claude git@github.com:org/repo.git
```

## On the VM

After SSHing into your VM:

```bash
cd /workspace/your-repo
claude
```

### Common Commands

```bash
# Interactive mode
claude

# Single task
claude "Review this codebase and suggest improvements"

# With specific focus
claude "Write comprehensive tests for the auth module"
```

## Credentials

| Location | Path |
|----------|------|
| Local | `~/.claude/` |
| VM | `~/.claude/` |

## Best Practices

### Long-Running Tasks

Claude excels at complex, long-running tasks:

```bash
# Start a big task
claude "Migrate this Express app to Fastify, updating all routes and middleware"

# Detach from tmux
# Press Ctrl+B then D

# Check back later
ca ssh
```

### Code Review

```bash
claude "Review the changes in the last 5 commits and provide feedback"
```

### Documentation

```bash
claude "Generate comprehensive API documentation for all endpoints"
```

## Troubleshooting

### "Claude not logged in"

```bash
# Login locally
claude login

# Then redeploy
ca --agent claude git@github.com:org/repo.git
```

### "Claude CLI not found" on VM

```bash
# SSH into VM
ca ssh

# Install manually
npm install -g @anthropic/claude-code
```

### Session Expired

Claude sessions may expire. Re-login on the VM:

```bash
ca ssh
claude login
```

Or re-deploy to transfer fresh credentials:

```bash
ca --agent claude --skip-vm
```

