# GCP Setup

Detailed guide for setting up Google Cloud Platform for Cloud Agent.

## Prerequisites

1. A GCP account with billing enabled
2. A GCP project
3. Google Cloud SDK installed

## Initial Setup

### 1. Install Google Cloud SDK

=== "macOS"

    ```bash
    brew install google-cloud-sdk
    ```

=== "Linux"

    ```bash
    curl https://sdk.cloud.google.com | bash
    exec -l $SHELL
    ```

### 2. Authenticate

```bash
gcloud auth login
```

This opens a browser for OAuth authentication.

### 3. Create or Select Project

```bash
# List existing projects
gcloud projects list

# Set existing project
gcloud config set project YOUR_PROJECT_ID

# Or create new project
gcloud projects create cloud-agent-project
gcloud config set project cloud-agent-project
```

### 4. Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
```

### 5. Set Default Region/Zone

```bash
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

## Service Account (Optional)

For advanced setups, create a service account:

```bash
# Create service account
gcloud iam service-accounts create cloud-agent \
  --display-name="Cloud Agent"

# Grant Compute Admin role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:cloud-agent@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"
```

## VM Permissions

The `--permissions` flag grants GCP access to your VM:

### Compute Engine

```bash
ca --permissions compute git@github.com:org/repo.git
```

Allows:
- List/create/manage Compute Engine instances
- Access to instance metadata
- Network operations

### GKE (Kubernetes)

```bash
ca --permissions gke git@github.com:org/repo.git
```

Allows:
- List/access GKE clusters
- kubectl operations
- Container Registry access

### Cloud Storage

```bash
ca --permissions storage git@github.com:org/repo.git
```

Allows:
- Read/write to Cloud Storage buckets
- gsutil operations

### Multiple Permissions

```bash
ca --permissions compute,gke,storage git@github.com:org/repo.git
```

## Firewall Rules

Cloud Agent automatically creates firewall rules to:

1. Allow SSH (port 22) from your IP only
2. Block all other inbound traffic

To whitelist additional IPs:

```bash
ca --ip 192.168.1.100 git@github.com:org/repo.git
```

## Cost Management

### VM Costs

| Machine Type | vCPUs | RAM | ~Monthly Cost |
|--------------|-------|-----|---------------|
| e2-standard-2 | 2 | 8 GB | ~$50 |
| e2-standard-4 | 4 | 16 GB | ~$100 |
| e2-standard-8 | 8 | 32 GB | ~$200 |

### Cost Saving Tips

1. **Stop when not using**: `ca stop`
2. **Use smaller machine types** for simple tasks
3. **Terminate when done**: `ca terminate`
4. **Set up billing alerts** in GCP Console

## Troubleshooting

### "Permission Denied" Errors

```bash
# Re-authenticate
gcloud auth login

# Verify project access
gcloud projects describe YOUR_PROJECT_ID
```

### "API Not Enabled"

```bash
gcloud services enable compute.googleapis.com
```

### "Quota Exceeded"

Request quota increase in GCP Console or use a different region.

