# Deploy Command

The deploy command creates a GCP VM and sets it up for AI coding agents.

## Usage

```bash
ca [OPTIONS] [REPOS...]
```

## Arguments

### REPOS

One or more Git repository URLs to clone on the VM.

```bash
# Single repo
ca git@github.com:org/repo.git

# Multiple repos
ca git@github.com:org/repo1.git git@github.com:org/repo2.git

# No repos (just create VM)
ca
```

If no repos are specified and you're in a git repository, Cloud Agent will use the current repo's origin.

## Options

### `--agent <NAME>`

Choose the AI coding agent to configure.

| Agent | Value | Description |
|-------|-------|-------------|
| Auggie | `auggie` | Augment Code's AI assistant (default) |
| Claude Code | `claude` | Anthropic's Claude for coding |

```bash
ca --agent claude git@github.com:org/repo.git
```

### `--skip-vm`

Skip VM creation and use the existing VM. Useful for adding more repositories.

```bash
# First deployment
ca git@github.com:org/repo1.git

# Add another repo later
ca --skip-vm git@github.com:org/repo2.git
```

### `--permissions <LIST>`

Grant GCP service account permissions. Comma-separated list.

| Permission | Description |
|------------|-------------|
| `compute` | Compute Engine access |
| `gke` | GKE cluster access |
| `storage` | Cloud Storage access |

```bash
ca --permissions compute,gke,storage git@github.com:org/repo.git
```

### `--ip <ADDRESS>`

Whitelist an additional IP address for SSH access.

```bash
ca --ip 192.168.1.100 git@github.com:org/repo.git
```

### `--machine-type <TYPE>`

Specify the GCP machine type.

```bash
ca --machine-type n2-standard-8 git@github.com:org/repo.git
```

Common machine types:

| Type | vCPUs | Memory | Use Case |
|------|-------|--------|----------|
| `e2-standard-2` | 2 | 8 GB | Light tasks |
| `e2-standard-4` | 4 | 16 GB | Default |
| `e2-standard-8` | 8 | 32 GB | Heavy tasks |
| `n2-standard-4` | 4 | 16 GB | CPU-intensive |

## What Happens During Deploy

1. **IP Detection**: Detects your public IP for firewall rules
2. **VM Creation**: Terraform creates the GCP VM
3. **SSH Setup**: Configures SSH access with your key
4. **Repo Cloning**: Clones repositories to `/workspace/`
5. **Credential Transfer**: Copies agent credentials to VM
6. **Agent Setup**: Installs and configures the AI agent

## Examples

```bash
# Deploy with all options
SSH_KEY=~/.ssh/work \
  ca --agent claude \
     --permissions compute,gke \
     --machine-type n2-standard-8 \
     git@github.com:company/project.git
```

