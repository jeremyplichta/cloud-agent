# AI Coding Agents

Cloud Agent supports multiple AI coding agents that can work on your repositories remotely.

## Supported Agents

| Agent | Command | Description |
|-------|---------|-------------|
| [Auggie](auggie.md) | `--agent auggie` | Augment Code's AI coding assistant (default) |
| [Claude Code](claude.md) | `--agent claude` | Anthropic's Claude for coding |

## How It Works

1. **Local Check**: Cloud Agent verifies you have the agent CLI installed locally
2. **Auth Check**: Verifies you're logged in to the agent
3. **Credential Transfer**: Copies your credentials to the VM
4. **Agent Setup**: Installs the agent CLI on the VM
5. **Ready**: Agent is ready to use on the VM

## Choosing an Agent

### Auggie (Default)

Best for:

- General coding tasks
- Codebase understanding
- Refactoring and improvements

```bash
ca git@github.com:org/repo.git
# or explicitly:
ca --agent auggie git@github.com:org/repo.git
```

### Claude Code

Best for:

- Complex reasoning tasks
- Code review and analysis
- Documentation generation

```bash
ca --agent claude git@github.com:org/repo.git
```

## Starting the Agent on VM

After SSHing into your VM:

```bash
# SSH into VM
ca ssh

# Navigate to your repo
cd /workspace/your-repo

# Start the agent
auggie  # or 'claude' for Claude Code
```

## Agent Credentials

Cloud Agent transfers your local agent credentials to the VM:

| Agent | Local Path | VM Path |
|-------|------------|---------|
| Auggie | `~/.augment/` | `~/.augment/` |
| Claude | `~/.claude/` | `~/.claude/` |

!!! note "Login Required"
    You must be logged in locally before deploying. Run `auggie login` or `claude login` first.

## Running Long Tasks

AI agents can take hours for complex tasks. Here's the workflow:

1. **Deploy and SSH**:
   ```bash
   ca git@github.com:org/repo.git
   ca ssh
   ```

2. **Start the task**:
   ```bash
   cd /workspace/repo
   auggie "Refactor the entire codebase to use TypeScript"
   ```

3. **Detach from tmux**: Press `Ctrl+B` then `D`

4. **Close your laptop** - the agent keeps running!

5. **Check back later**:
   ```bash
   ca ssh
   # Reattaches to your tmux session
   ```

## Adding New Agents

Want to add support for another AI coding agent?

See [Adding New Agents](adding-agents.md) for a guide on implementing support for additional agents.

