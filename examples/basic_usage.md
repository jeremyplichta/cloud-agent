# Cloud Agent - Basic Usage Examples

This guide shows common usage patterns for cloud-agent.

## Quick Start

### Deploy Current Repository

If you're in a git repository, cloud-agent will auto-detect it:

```bash
cd /path/to/your/repo
ca
```

This will:
1. Create a VM (if it doesn't exist)
2. Transfer your SSH keys and agent credentials
3. Clone the current repository to `/workspace/`
4. Print instructions for connecting

### Deploy Specific Repository

```bash
ca git@github.com:myorg/myrepo.git
```

### Deploy Multiple Repositories

```bash
ca git@github.com:org/repo1.git git@github.com:org/repo2.git git@github.com:org/repo3.git
```

## Working with Different Agents

### Auggie (Default)

```bash
ca git@github.com:org/repo.git
```

### Claude Code

```bash
ca --agent claude git@github.com:org/repo.git
```

### Codex

```bash
ca --agent codex git@github.com:org/repo.git
```

## SSH Access

### Interactive Session with Tmux

```bash
ca ssh
```

This automatically:
- Connects to your VM
- Attaches to an existing tmux session (or creates one)

### Manual SSH

```bash
# Get VM IP first
ca list

# Then SSH manually
ssh -i ~/.ssh/cloud-agent user@VM_IP
```

## File Transfer

### Upload Files to VM

```bash
# Upload a single file
ca scp ./local-file.txt vm:/workspace/

# Upload a directory
ca scp ./local-dir/ vm:/workspace/
```

### Download Files from VM

```bash
# Download a file
ca scp vm:/workspace/output.txt ./

# Download a directory
ca scp vm:/workspace/results/ ./
```

## VM Management

### List All VMs

```bash
ca list
```

Output:
```
NAME                    ZONE           STATUS   OWNER              SKIP_DELETION  EXTERNAL_IP
john-doe-cloud-agent    us-central1-a  RUNNING  john_doe_redis_com yes            34.123.45.67
```

### Stop VM (Save Costs)

```bash
ca stop
```

The VM is stopped but not deleted. You can start it again later.

### Start Stopped VM

```bash
ca start
```

### Terminate VM (Delete)

```bash
ca terminate
```

⚠️ This permanently deletes the VM and all data on it.

## Advanced Usage

### Custom Machine Type

```bash
# Use a larger VM
ca --machine-type n2-standard-8 git@github.com:org/repo.git

# Use a smaller VM (cheaper)
ca --machine-type e2-medium git@github.com:org/repo.git
```

### GCP Permissions

Grant the VM access to GCP services:

```bash
# Full admin access
ca --permissions admin git@github.com:org/repo.git

# Specific permissions
ca --permissions compute,gke,storage git@github.com:org/repo.git
```

Available permissions:
- `admin` - Full project admin
- `compute` - Compute Engine
- `gke` - Google Kubernetes Engine
- `storage` - Cloud Storage
- `network` - Networking
- `bigquery` or `bq` - BigQuery
- `iam` - IAM
- `logging` - Cloud Logging
- `pubsub` - Pub/Sub
- `sql` - Cloud SQL
- `secrets` - Secret Manager
- `dns` - Cloud DNS
- `run` - Cloud Run
- `functions` - Cloud Functions

### Whitelist Additional IPs

By default, only your current IP can SSH to the VM. To add more:

```bash
# Add your office IP
ca --ip 203.0.113.0 git@github.com:org/repo.git

# Add multiple IPs (use environment variable)
ADDITIONAL_IP=203.0.113.0 ca git@github.com:org/repo.git
```

### Update Firewall Rules

If your IP changes, update the firewall:

```bash
ca tf
```

This re-applies Terraform with your current IP.

## Workflow Examples

### Daily Development

```bash
# Morning: Start VM
ca start

# Connect and work
ca ssh
cd /workspace/myrepo
auggie

# Evening: Stop VM to save costs
ca stop
```

### One-Time Task

```bash
# Deploy and work
ca git@github.com:org/repo.git
ca ssh

# When done, terminate to clean up
ca terminate
```

### Multiple Projects

```bash
# Deploy all your projects
ca git@github.com:org/project1.git \
   git@github.com:org/project2.git \
   git@github.com:org/project3.git

# SSH and switch between them
ca ssh
cd /workspace/project1  # Work on project 1
cd /workspace/project2  # Switch to project 2
```

