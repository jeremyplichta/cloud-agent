# Command Reference

Cloud Agent provides a simple CLI for managing GCP VMs and AI coding agents.

## Quick Reference

| Command | Description |
|---------|-------------|
| `ca [REPOS...]` | Deploy repos to a new or existing VM |
| `ca list` | List all Cloud Agent VMs |
| `ca ssh` | SSH into the VM (with tmux) |
| `ca start` | Start a stopped VM |
| `ca stop` | Stop a running VM |
| `ca terminate` | Delete the VM |
| `ca scp` | Copy files to/from VM |
| `ca tf` | Re-apply Terraform |

## Global Options

```
-h, --help       Print help
-V, --version    Print version
```

## Deploy Options

When deploying (`ca [REPOS...]`):

```
--agent <NAME>        Agent to use: auggie, claude (default: auggie)
--skip-vm             Skip VM creation, add repos to existing VM
--permissions <LIST>  GCP permissions: compute, gke, storage
--ip <ADDRESS>        Additional IP to whitelist for SSH
--machine-type <TYPE> GCP machine type (default: e2-standard-4)
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_KEY` | Path to SSH private key | `~/.ssh/id_ed25519` |
| `COMPANY` | Company domain for username | (auto-detect) |
| `GCP_PROJECT` | GCP project ID | (from gcloud config) |
| `GCP_ZONE` | GCP zone | `us-central1-a` |
| `GCP_REGION` | GCP region | `us-central1` |

## Examples

```bash
# Basic deployment
ca git@github.com:org/repo.git

# Multiple repos
ca git@github.com:org/repo1.git git@github.com:org/repo2.git

# With Claude agent and GCP permissions
ca --agent claude --permissions compute,gke git@github.com:org/repo.git

# Add repo to existing VM
ca --skip-vm git@github.com:org/new-repo.git

# Use specific SSH key
SSH_KEY=~/.ssh/work ca git@github.com:company/project.git
```

## Detailed Documentation

- [Deploy Command](deploy.md)
- [VM Management](vm-management.md)
- [SSH & File Transfer](ssh-files.md)

