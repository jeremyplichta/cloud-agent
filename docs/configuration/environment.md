# Environment Variables

Cloud Agent can be configured via environment variables.

## SSH Configuration

### `SSH_KEY`

Path to the SSH private key for GitHub access.

```bash
SSH_KEY=~/.ssh/work ca git@github.com:company/repo.git
```

**Default**: `~/.ssh/id_ed25519` or `~/.ssh/id_rsa`

!!! note
    The corresponding public key (`.pub`) must be added to your GitHub account.

## GCP Configuration

### `GCP_PROJECT`

Google Cloud project ID.

```bash
GCP_PROJECT=my-project ca git@github.com:org/repo.git
```

**Default**: Uses `gcloud config get project`

### `GCP_ZONE`

GCP zone for the VM.

```bash
GCP_ZONE=us-west1-b ca git@github.com:org/repo.git
```

**Default**: `us-central1-a`

### `GCP_REGION`

GCP region (derived from zone if not set).

```bash
GCP_REGION=us-west1 ca git@github.com:org/repo.git
```

**Default**: Derived from `GCP_ZONE`

## User Configuration

### `COMPANY`

Company domain for username derivation.

```bash
COMPANY=redis.com ca git@github.com:org/repo.git
```

This affects the VM name: `cloud-agent-jsmith-redis_com`

**Default**: Auto-detected from email

### `USER`

Override the username for the VM.

```bash
USER=john ca git@github.com:org/repo.git
```

**Default**: Auto-detected from `gcloud config get account`

## All Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSH_KEY` | SSH private key path | `~/.ssh/id_ed25519` |
| `GCP_PROJECT` | GCP project ID | From gcloud config |
| `GCP_ZONE` | GCP zone | `us-central1-a` |
| `GCP_REGION` | GCP region | From zone |
| `COMPANY` | Company domain | Auto-detect |
| `USER` | Username override | From gcloud |

## Example: Full Configuration

```bash
SSH_KEY=~/.ssh/company \
GCP_PROJECT=my-project-123 \
GCP_ZONE=europe-west1-b \
COMPANY=example.com \
ca --agent claude \
   --permissions compute,gke \
   git@github.com:company/project.git
```

## Persistent Configuration

For persistent configuration, add to your shell profile:

```bash
# ~/.zshrc or ~/.bashrc
export SSH_KEY=~/.ssh/work
export GCP_PROJECT=my-default-project
export COMPANY=mycompany.com
```

