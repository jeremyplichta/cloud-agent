#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [REPO_URL...]

Deploy repos to Cloud Auggie VM. Creates VM if it doesn't exist.

Arguments:
  REPO_URL    GitHub repo URL(s) to clone
              SSH:   git@github.com:org/repo.git
              HTTPS: https://github.com/org/repo.git

Options:
  --create-vm       Force VM creation even if it exists
  --skip-vm         Skip VM creation, only deploy repos (VM must exist)
  --skip-creds      Skip credential transfer
  -h, --help        Show this help message

Environment Variables:
  SSH_KEY           Path to SSH private key for GitHub (recommended for enterprise)
                    Example: SSH_KEY=~/.ssh/cloud-auggie
  GITHUB_TOKEN      GitHub PAT for HTTPS cloning (for personal repos)
  GITHUB_TOKEN_FILE Path to file containing GitHub PAT
  AUGMENT_TOKEN     Augment session token (or uses 'auggie tokens print')
  ZONE              GCP zone (default: us-central1-a)
  MACHINE_TYPE      VM machine type (default: n2-standard-4)
  CLUSTER_NAME      Optional GKE cluster name for kubectl config

Examples:
  # Using SSH key (recommended for enterprise)
  SSH_KEY=~/.ssh/cloud-auggie $0 git@github.com:enterprise-org/repo.git

  # Generate a dedicated key for cloud-auggie
  ssh-keygen -t ed25519 -f ~/.ssh/cloud-auggie -C "cloud-auggie"
  # Add ~/.ssh/cloud-auggie.pub to GitHub: Settings > SSH Keys

  # Using GitHub PAT (for personal repos)
  GITHUB_TOKEN_FILE=~/.github-token $0 https://github.com/user/repo.git

  # Deploy additional repo to existing VM
  SSH_KEY=~/.ssh/cloud-auggie $0 --skip-vm git@github.com:org/another-repo.git

  # Deploy multiple repos
  SSH_KEY=~/.ssh/cloud-auggie $0 git@github.com:org/repo1.git git@github.com:org/repo2.git
EOF
    exit 0
}

# Parse arguments
CREATE_VM="auto"
SKIP_CREDS=false
REPOS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --create-vm)
            CREATE_VM="yes"
            shift
            ;;
        --skip-vm)
            CREATE_VM="no"
            shift
            ;;
        --skip-creds)
            SKIP_CREDS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            log "❌ Unknown option: $1"
            usage
            ;;
        *)
            REPOS+=("$1")
            shift
            ;;
    esac
done

log "╔══════════════════════════════════════════════════════════════╗"
log "║  🐕 CLOUD AUGGIE DEPLOYMENT                                  ║"
log "╚══════════════════════════════════════════════════════════════╝"

# Get GCP project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    log "❌ ERROR: No GCP project configured. Run: gcloud config set project PROJECT_ID"
    exit 1
fi
log "Using GCP project: $PROJECT_ID"

# Configuration
ZONE="${ZONE:-us-central1-a}"
REGION="${REGION:-us-central1}"
CLUSTER_ZONE="${CLUSTER_ZONE:-$ZONE}"
MACHINE_TYPE="${MACHINE_TYPE:-n2-standard-4}"
CLUSTER_NAME="${CLUSTER_NAME:-}"

# Load GitHub token
if [ -n "$GITHUB_TOKEN_FILE" ] && [ -f "$GITHUB_TOKEN_FILE" ]; then
    GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
fi

# Check if VM exists
VM_EXISTS=$(gcloud compute instances list --filter="name=cloud-auggie" --format="value(name)" 2>/dev/null || true)

if [ "$CREATE_VM" = "auto" ]; then
    if [ -n "$VM_EXISTS" ]; then
        CREATE_VM="no"
        log "✓ Cloud Auggie VM already exists, will deploy to existing VM"
    else
        CREATE_VM="yes"
        log "✓ Cloud Auggie VM not found, will create it"
    fi
elif [ "$CREATE_VM" = "no" ] && [ -z "$VM_EXISTS" ]; then
    log "❌ ERROR: VM doesn't exist and --skip-vm was specified"
    exit 1
fi

# Create VM if needed
if [ "$CREATE_VM" = "yes" ]; then
    log ""
    log "Creating terraform.tfvars..."
    cat > "$SCRIPT_DIR/terraform.tfvars" << EOF
project_id   = "$PROJECT_ID"
region       = "$REGION"
zone         = "$ZONE"
machine_type = "$MACHINE_TYPE"
cluster_name = "${CLUSTER_NAME:-}"
cluster_zone = "$CLUSTER_ZONE"
EOF

    log ""
    log "Initializing Terraform..."
    cd "$SCRIPT_DIR"
    terraform init -input=false

    log ""
    log "Applying Terraform (creating cloud-auggie VM)..."
    terraform apply -auto-approve

    VM_IP=$(terraform output -raw cloud_auggie_ip)
    log ""
    log "✅ Cloud Auggie VM created!"
    log "   External IP: $VM_IP"

    log ""
    log "Waiting 90s for VM to boot and run startup script..."
    sleep 90
fi

# Transfer credentials (only once, skip if already configured)
if [ "$SKIP_CREDS" = false ]; then
    log ""
    log "Configuring credentials on VM..."

    # SSH key (recommended for enterprise orgs)
    if [ -n "$SSH_KEY" ]; then
        if [ -f "$SSH_KEY" ]; then
            log "Transferring SSH key..."
            gcloud compute scp "$SSH_KEY" cloud-auggie:~/.ssh/id_ed25519 --zone="$ZONE" 2>/dev/null
            if [ -f "${SSH_KEY}.pub" ]; then
                gcloud compute scp "${SSH_KEY}.pub" cloud-auggie:~/.ssh/id_ed25519.pub --zone="$ZONE" 2>/dev/null
            fi
            gcloud compute ssh cloud-auggie --zone="$ZONE" --command="
                chmod 600 ~/.ssh/id_ed25519
                chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
                # Add GitHub to known_hosts to avoid prompt
                ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
                git config --global user.email 'cloud-auggie@localhost'
                git config --global user.name 'Cloud Auggie'
                echo '✅ SSH key configured'
            " 2>/dev/null
            log "✅ SSH key transferred"
        else
            log "❌ SSH key not found: $SSH_KEY"
            exit 1
        fi
    # GitHub PAT (for personal repos / non-enterprise)
    elif [ -n "$GITHUB_TOKEN" ]; then
        log "Transferring GitHub credentials (PAT)..."
        gcloud compute ssh cloud-auggie --zone="$ZONE" --command="
            git config --global credential.helper store
            echo 'https://oauth2:$GITHUB_TOKEN@github.com' > ~/.git-credentials
            chmod 600 ~/.git-credentials
            git config --global user.email 'cloud-auggie@localhost'
            git config --global user.name 'Cloud Auggie'
            echo '✅ GitHub credentials configured'
        " 2>/dev/null
        log "✅ GitHub PAT transferred"
    else
        log "⚠️  No SSH_KEY or GITHUB_TOKEN set."
        log "   For enterprise: SSH_KEY=~/.ssh/cloud-auggie ./deploy.sh git@github.com:org/repo.git"
        log "   For personal:   GITHUB_TOKEN=xxx ./deploy.sh https://github.com/user/repo.git"
    fi

    # Augment credentials
    if [ -n "$AUGMENT_TOKEN" ]; then
        # Use provided token
        :
    elif command -v auggie &> /dev/null; then
        AUGMENT_TOKEN=$(auggie tokens print 2>/dev/null || true)
    fi

    if [ -n "$AUGMENT_TOKEN" ]; then
        log "Transferring Augment credentials..."
        gcloud compute ssh cloud-auggie --zone="$ZONE" --command="
            echo '$AUGMENT_TOKEN' > ~/.augment-token
            chmod 600 ~/.augment-token
            if ! grep -q 'AUGMENT_SESSION_AUTH' ~/.bashrc; then
                echo 'export AUGMENT_SESSION_AUTH=\"\$(cat ~/.augment-token)\"' >> ~/.bashrc
            fi
            echo '✅ Augment credentials configured'
        " 2>/dev/null
        log "✅ Augment credentials transferred"
    else
        log "⚠️  No Augment token found. Run 'auggie login' locally first."
    fi
fi

# Clone repos
if [ ${#REPOS[@]} -gt 0 ]; then
    log ""
    log "Cloning repositories to VM..."

    for repo in "${REPOS[@]}"; do
        repo_name=$(basename "$repo" .git)
        log "  Cloning $repo_name..."

        gcloud compute ssh cloud-auggie --zone="$ZONE" --command="
            cd /workspace
            if [ -d '$repo_name' ]; then
                echo '  ⚠️  $repo_name already exists, pulling latest...'
                cd '$repo_name' && git pull
            else
                git clone '$repo' '$repo_name'
                echo '  ✅ Cloned $repo_name'
            fi
        " 2>/dev/null
    done

    log "✅ All repositories cloned"
else
    log ""
    log "ℹ️  No repos specified. Use: $0 https://github.com/user/repo.git"
fi

# List workspace contents
log ""
log "Workspace contents:"
gcloud compute ssh cloud-auggie --zone="$ZONE" --command="ls -la /workspace/" 2>/dev/null

log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║  🐕 CLOUD AUGGIE READY!                                      ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""
log "SSH into cloud-auggie:"
log "  gcloud compute ssh cloud-auggie --zone=$ZONE"
log ""
log "Start working:"
log "  cd /workspace/<repo-name>"
log "  tmux new -s auggie"
log "  auggie"
log ""
log "Agent can commit and push:"
log "  git checkout -b feature/my-changes"
log "  git add . && git commit -m 'Changes from cloud-auggie'"
log "  git push -u origin feature/my-changes"
log ""
log "To destroy cloud-auggie when done:"
log "  cd $SCRIPT_DIR && terraform destroy -auto-approve"
log ""
log "🐕 GOOD LUCK!"

