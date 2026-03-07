# SSH & File Transfer

Connect to your VM and transfer files.

## SSH into VM

```bash
ca ssh
```

This:

1. Connects via SSH to your Cloud Agent VM
2. Automatically attaches to (or creates) a tmux session
3. Drops you into the `/workspace` directory

### Tmux Basics

Cloud Agent uses tmux so your work persists if you disconnect.

| Action | Keys |
|--------|------|
| Detach (leave running) | `Ctrl+B` then `D` |
| New window | `Ctrl+B` then `C` |
| Next window | `Ctrl+B` then `N` |
| Previous window | `Ctrl+B` then `P` |
| Split horizontal | `Ctrl+B` then `"` |
| Split vertical | `Ctrl+B` then `%` |
| Switch pane | `Ctrl+B` then arrow key |

### Direct SSH

You can also SSH directly:

```bash
# Get VM IP
ca list

# SSH manually
ssh -i ~/.ssh/cloud-agent user@35.192.0.42
```

## File Transfer

Copy files between your local machine and the VM.

### Copy to VM

```bash
# Single file
ca scp ./local-file.txt vm:/workspace/

# Directory
ca scp -r ./local-dir vm:/workspace/

# To specific path
ca scp ./config.json vm:/home/user/.config/
```

### Copy from VM

```bash
# Single file
ca scp vm:/workspace/output.txt ./

# Directory
ca scp -r vm:/workspace/results ./local-results

# Specific file
ca scp vm:/home/user/.bashrc ./bashrc-backup
```

### Direct SCP

Using standard `scp`:

```bash
# Get VM IP
ca list

# Copy to VM
scp -i ~/.ssh/cloud-agent ./file.txt user@35.192.0.42:/workspace/

# Copy from VM
scp -i ~/.ssh/cloud-agent user@35.192.0.42:/workspace/file.txt ./
```

## Workspace Layout

On the VM, repositories are cloned to `/workspace/`:

```
/workspace/
├── repo1/
│   ├── src/
│   └── ...
├── repo2/
│   ├── src/
│   └── ...
└── ...
```

## Credentials on VM

Your credentials are stored in the standard locations:

| Credential | VM Path |
|------------|---------|
| SSH key | `~/.ssh/id_ed25519` |
| Auggie | `~/.augment/` |
| Claude | `~/.claude/` |
| Git config | `~/.gitconfig` |

## Troubleshooting

### Connection Refused

1. Check VM is running: `ca list`
2. Start if stopped: `ca start`
3. Wait for startup (1-2 minutes)

### Permission Denied

1. Check SSH key path: `ls ~/.ssh/`
2. Verify key is added to GitHub
3. Re-deploy with correct key: `SSH_KEY=~/.ssh/mykey ca`

### Tmux Session Issues

```bash
# List sessions
ssh user@VM_IP tmux list-sessions

# Kill stuck session
ssh user@VM_IP tmux kill-server

# Reconnect
ca ssh
```

