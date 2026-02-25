#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# List available agent hooks
list_agents() {
    local agents=()
    for hook in "$HOOKS_DIR"/*.sh; do
        if [ -f "$hook" ]; then
            agents+=("$(basename "$hook" .sh)")
        fi
    done
    echo "${agents[*]}"
}

# Load an agent hook
load_agent_hook() {
    local agent="$1"
    local hook_file="$HOOKS_DIR/${agent}.sh"

    if [ ! -f "$hook_file" ]; then
        log "❌ ERROR: Unknown agent '$agent'"
        log "   Available agents: $(list_agents)"
        exit 1
    fi

    source "$hook_file"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [REPO_URL...]

Deploy repos to Cloud Agent VM. Creates VM if it doesn't exist.
If no REPO_URL is provided and you're in a git repo, uses the 'origin' remote.

Arguments:
  REPO_URL    GitHub repo URL(s) to clone
              SSH:   git@github.com:org/repo.git
              HTTPS: https://github.com/org/repo.git

Options:
  --agent NAME      Agent to use (default: auggie)
                    Available: $(list_agents)
  --create-vm       Force VM creation even if it exists
  --skip-vm         Skip VM creation, only deploy repos (VM must exist)
  --skip-creds      Skip credential transfer
  --skip-deletion VALUE
                    Set skip_deletion label (default: yes)
                    Use "no" or "false" to allow automatic deletion
  --permissions LIST
                    Comma-separated permissions for VM service account
                    By default, VM has no service account (no GCP API access)
                    Options: admin, compute, gke, storage, network, bigquery,
                             bq, iam, logging, pubsub, sql, secrets, dns, run, functions
                    Example: --permissions compute,gke,storage
  --ip ADDRESS      Additional IP address to whitelist for SSH access
                    By default, only your current public IP is allowed
                    Use this to add another IP (e.g., for accessing from a different location)
  --list            List cloud-agent VMs and their status
  --start           Start a stopped cloud-agent VM
  --stop            Stop (but don't delete) the cloud-agent VM
  --terminate       Terminate (delete) the cloud-agent VM
  --ssh             SSH into the VM and attach to tmux session
  --scp SRC DST     Copy files to/from VM using 'vm:' prefix for remote paths
                    Examples: ca --scp ./file.txt vm:/workspace/
                              ca --scp vm:/workspace/file.txt ./
  -h, --help        Show this help message

Environment Variables:
  AGENT             Agent to use (same as --agent)
  SSH_KEY           Path to SSH private key for GitHub (recommended for enterprise)
                    Example: SSH_KEY=~/.ssh/cloud-agent
  GITHUB_TOKEN      GitHub PAT for HTTPS cloning (for personal repos)
  GITHUB_TOKEN_FILE Path to file containing GitHub PAT
  ZONE              GCP zone (default: us-central1-a)
  MACHINE_TYPE      VM machine type (default: n2-standard-4)
  CLUSTER_NAME      Optional GKE cluster name for kubectl config
  SKIP_DELETION     Set skip_deletion label (default: yes)
  PERMISSIONS       Comma-separated permissions for VM service account
  ADDITIONAL_IP     Additional IP to whitelist for SSH access (same as --ip)

Examples:
  # Deploy current repo (auto-detects origin remote)
  $0

  # Deploy with Auggie (default)
  SSH_KEY=~/.ssh/cloud-agent $0 git@github.com:org/repo.git

  # Deploy with Claude Code
  AGENT=claude SSH_KEY=~/.ssh/cloud-agent $0 git@github.com:org/repo.git
  # Or: $0 --agent claude git@github.com:org/repo.git

  # Generate a dedicated key for cloud-agent
  ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -C "cloud-agent"
  # Add ~/.ssh/cloud-agent.pub to GitHub: Settings > SSH Keys

  # Using GitHub PAT (for personal repos)
  GITHUB_TOKEN_FILE=~/.github-token $0 https://github.com/user/repo.git

  # Deploy additional repo to existing VM
  SSH_KEY=~/.ssh/cloud-agent $0 --skip-vm git@github.com:org/another-repo.git

  # Deploy multiple repos
  SSH_KEY=~/.ssh/cloud-agent $0 git@github.com:org/repo1.git git@github.com:org/repo2.git

  # VM management
  $0 --list           # List VMs
  $0 --ssh            # SSH and attach to tmux
  $0 --stop           # Stop VM
  $0 --start          # Start VM
  $0 --terminate      # Delete VM

  # With GCP permissions (creates a service account)
  $0 --permissions admin git@github.com:org/repo.git          # Full admin
  $0 --permissions compute,gke,storage git@github.com:org/repo.git  # Specific permissions

  # Whitelist additional IP for SSH access
  $0 --ip 192.168.1.100 git@github.com:org/repo.git  # Allow your IP + another IP
EOF
    exit 0
}

# Get VM name based on $USER
get_vm_name() {
    local vm_name
    if [[ "$USER" == *.* ]]; then
        vm_name="${USER}-cloud-agent"
    else
        # Can't auto-derive, use a default pattern
        vm_name="${USER}-cloud-agent"
    fi
    # Normalize VM name (GCP requires lowercase, no dots or underscores)
    echo "$vm_name" | tr '[:upper:]' '[:lower:]' | tr '_.' '-'
}

# VM management commands (don't need full initialization)
handle_vm_command() {
    local cmd="$1"
    local zone="${ZONE:-us-central1-a}"
    local vm_name=$(get_vm_name)

    case "$cmd" in
        list)
            log "Listing cloud-agent VMs..."
            gcloud compute instances list \
                --filter="labels.purpose=cloud-agent" \
                --format="table(name,zone,status,labels.owner,labels.skip_deletion,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"
            exit 0
            ;;
        start)
            log "Starting VM: $vm_name..."
            gcloud compute instances start "$vm_name" --zone="$zone"
            log "✅ VM started"
            exit 0
            ;;
        stop)
            log "Stopping VM: $vm_name..."
            gcloud compute instances stop "$vm_name" --zone="$zone"
            log "✅ VM stopped"
            exit 0
            ;;
        terminate)
            log "⚠️  Terminating VM and cleaning up resources..."
            read -p "Are you sure? [y/N] " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                cd "$SCRIPT_DIR"
                if [ -f "terraform.tfstate" ]; then
                    terraform destroy -auto-approve
                    log "✅ All resources destroyed"
                else
                    log "No terraform state found, using gcloud to delete VM..."
                    gcloud compute instances delete "$vm_name" --zone="$zone" --quiet
                    log "✅ VM terminated"
                fi
            else
                log "Cancelled"
            fi
            exit 0
            ;;
        ssh)
            log "Connecting to $vm_name and attaching to tmux..."
            # Try to attach to existing session, or create new one
            gcloud compute ssh "$vm_name" --zone="$zone" -- -t "tmux attach-session 2>/dev/null || tmux new-session"
            exit 0
            ;;
        scp)
            local src="$2"
            local dst="$3"
            if [ -z "$src" ] || [ -z "$dst" ]; then
                log "❌ Usage: ca --scp <src> <dst>"
                log "   Use 'vm:' prefix for remote paths"
                log "   Examples:"
                log "     ca --scp ./local-file.txt vm:/workspace/  # Upload to VM"
                log "     ca --scp vm:/workspace/file.txt ./        # Download from VM"
                exit 1
            fi
            # Replace 'vm:' prefix with actual VM name
            src="${src//vm:/$vm_name:}"
            dst="${dst//vm:/$vm_name:}"
            log "Copying files..."
            gcloud compute scp --zone="$zone" --recurse "$src" "$dst"
            log "✅ Copy complete"
            exit 0
            ;;
    esac
}

# Parse arguments
CREATE_VM="auto"
SKIP_CREDS=false
REPOS=()
AGENT="${AGENT:-auggie}"  # Default to auggie
SKIP_DELETION="${SKIP_DELETION:-yes}"  # Default to yes
PERMISSIONS="${PERMISSIONS:-}"  # Default to empty (no service account)
ADDITIONAL_IP="${ADDITIONAL_IP:-}"  # Additional IP to whitelist for SSH access
VM_COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent)
            AGENT="$2"
            shift 2
            ;;
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
        --skip-deletion)
            SKIP_DELETION="$2"
            # Normalize "false" to "no"
            if [ "$SKIP_DELETION" = "false" ]; then
                SKIP_DELETION="no"
            fi
            shift 2
            ;;
        --permissions)
            PERMISSIONS="$2"
            shift 2
            ;;
        --ip)
            ADDITIONAL_IP="$2"
            shift 2
            ;;
        --list)
            handle_vm_command "list"
            ;;
        --start)
            handle_vm_command "start"
            ;;
        --stop)
            handle_vm_command "stop"
            ;;
        --terminate)
            handle_vm_command "terminate"
            ;;
        --ssh)
            handle_vm_command "ssh"
            ;;
        --scp)
            handle_vm_command "scp" "$2" "$3"
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

# If no repos specified, try to detect from current git directory
if [ ${#REPOS[@]} -eq 0 ]; then
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        ORIGIN_URL=$(git remote get-url origin 2>/dev/null || true)
        if [ -n "$ORIGIN_URL" ]; then
            log "Auto-detected repo from current directory: $ORIGIN_URL"
            REPOS+=("$ORIGIN_URL")
        fi
    fi
fi

# Load the agent hook
load_agent_hook "$AGENT"

log "╔══════════════════════════════════════════════════════════════╗"
log "║  🐕 CLOUD AGENT DEPLOYMENT                                  ║"
log "╚══════════════════════════════════════════════════════════════╝"
log "Agent: $HOOK_DISPLAY_NAME"

# Check agent prerequisites
if ! hook_check_local; then
    log "❌ ERROR: $HOOK_DISPLAY_NAME CLI not found locally."
    log "   Install it with: $HOOK_INSTALL_COMMAND"
    exit 1
fi

if ! hook_check_logged_in; then
    log "❌ ERROR: Not logged in to $HOOK_DISPLAY_NAME."
    log "   $(hook_login_instructions)"
    exit 1
fi

log "✓ $HOOK_DISPLAY_NAME CLI found and logged in"

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

# Derive VM name and owner from $USER
# Expected format: firstname.lastname
if [[ "$USER" == *.* ]]; then
    # User has firstname.lastname format
    OWNER=$(echo "$USER" | tr '.' '_')
    VM_NAME="${USER}-cloud-agent"
else
    # Prompt for first and last name
    log "⚠️  Cannot determine owner from \$USER ($USER)"
    log "   Expected format: firstname.lastname"
    read -p "Enter your first name: " FIRST_NAME
    read -p "Enter your last name: " LAST_NAME
    if [ -z "$FIRST_NAME" ] || [ -z "$LAST_NAME" ]; then
        log "❌ ERROR: First and last name are required"
        exit 1
    fi
    OWNER="${FIRST_NAME}_${LAST_NAME}"
    VM_NAME="${FIRST_NAME}.${LAST_NAME}-cloud-agent"
fi

# Normalize VM name (GCP requires lowercase, no dots or underscores)
VM_NAME=$(echo "$VM_NAME" | tr '[:upper:]' '[:lower:]' | tr '_.' '-')
OWNER=$(echo "$OWNER" | tr '[:upper:]' '[:lower:]')

log "VM name: $VM_NAME"
log "Owner: $OWNER"
log "Skip deletion: $SKIP_DELETION"
if [ -n "$PERMISSIONS" ]; then
    log "Permissions: $PERMISSIONS"
else
    log "Permissions: none (no service account)"
fi

# Load GitHub token
if [ -n "$GITHUB_TOKEN_FILE" ] && [ -f "$GITHUB_TOKEN_FILE" ]; then
    GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
fi

# Check if VM exists (fast check via terraform state first, then fallback to gcloud)
VM_EXISTS=""
if [ -f "$SCRIPT_DIR/terraform.tfstate" ]; then
    # Check terraform state for existing VM with matching name
    TF_VM_NAME=$(cd "$SCRIPT_DIR" && terraform output -raw vm_name 2>/dev/null || true)
    if [ "$TF_VM_NAME" = "$VM_NAME" ]; then
        VM_EXISTS="$VM_NAME"
        log "✓ Found VM in terraform state: $VM_NAME"
    fi
fi

# If not in terraform state, check gcloud (slower but catches VMs created outside terraform)
if [ -z "$VM_EXISTS" ]; then
    VM_EXISTS=$(gcloud compute instances list --filter="name=$VM_NAME" --format="value(name)" 2>/dev/null || true)
fi

if [ "$CREATE_VM" = "auto" ]; then
    if [ -n "$VM_EXISTS" ]; then
        CREATE_VM="no"
        log "✓ Cloud Agent VM already exists, will deploy to existing VM"
    else
        CREATE_VM="yes"
        log "✓ Cloud Agent VM not found, will create it"
    fi
elif [ "$CREATE_VM" = "no" ] && [ -z "$VM_EXISTS" ]; then
    log "❌ ERROR: VM doesn't exist and --skip-vm was specified"
    exit 1
fi

# Create VM if needed
if [ "$CREATE_VM" = "yes" ]; then
    log ""
    log "Creating terraform.tfvars..."

    # Convert comma-separated permissions to Terraform list format
    if [ -n "$PERMISSIONS" ]; then
        # Convert "compute,gke,storage" to ["compute", "gke", "storage"]
        PERMISSIONS_TF=$(echo "$PERMISSIONS" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    else
        PERMISSIONS_TF="[]"
    fi

    # Get current public IP for firewall rules (required - no fallback to 0.0.0.0/0)
    log "Detecting your public IP address..."
    MY_PUBLIC_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")
    if [ -z "$MY_PUBLIC_IP" ]; then
        log "❌ ERROR: Could not detect your public IP address."
        log "   This is required to secure the firewall rules."
        log "   Please check your internet connection and try again."
        exit 1
    fi
    log "✓ Your public IP: $MY_PUBLIC_IP"

    # Build allowed_ips list (always in CIDR notation)
    ALLOWED_IPS="${MY_PUBLIC_IP}/32"
    if [ -n "$ADDITIONAL_IP" ]; then
        # Add /32 if not already in CIDR notation
        if [[ ! "$ADDITIONAL_IP" =~ / ]]; then
            ADDITIONAL_IP="${ADDITIONAL_IP}/32"
        fi
        ALLOWED_IPS="${ALLOWED_IPS},${ADDITIONAL_IP}"
        log "✓ Additional whitelisted IP: $ADDITIONAL_IP"
    fi
    # Convert to Terraform list format: ["1.2.3.4/32", "5.6.7.8/32"]
    ALLOWED_IPS_TF=$(echo "$ALLOWED_IPS" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    log "✓ Firewall will only allow SSH from: $ALLOWED_IPS"

    # Detect SSH key for SSH hardening (prioritize cloud-auggie > cloud-agent > id_ed25519 > id_rsa)
    SSH_KEY_FOR_VM=""
    if [ -z "$SSH_KEY" ]; then
        if [ -f "$HOME/.ssh/cloud-auggie" ]; then
            SSH_KEY_FOR_VM="$HOME/.ssh/cloud-auggie"
        elif [ -f "$HOME/.ssh/cloud-agent" ]; then
            SSH_KEY_FOR_VM="$HOME/.ssh/cloud-agent"
        elif [ -f "$HOME/.ssh/id_ed25519" ]; then
            SSH_KEY_FOR_VM="$HOME/.ssh/id_ed25519"
        elif [ -f "$HOME/.ssh/id_rsa" ]; then
            SSH_KEY_FOR_VM="$HOME/.ssh/id_rsa"
        fi
    else
        SSH_KEY_FOR_VM="$SSH_KEY"
    fi

    # Get SSH public key content and username for SSH hardening
    SSH_USERNAME=""
    SSH_PUBLIC_KEY=""
    if [ -n "$SSH_KEY_FOR_VM" ] && [ -f "${SSH_KEY_FOR_VM}.pub" ]; then
        SSH_PUBLIC_KEY=$(cat "${SSH_KEY_FOR_VM}.pub")
        # Derive username from local $USER (cloud-agent style)
        SSH_USERNAME=$(echo "$USER" | tr '.' '-' | tr '[:upper:]' '[:lower:]')
        log "✓ SSH will be secured for user: $SSH_USERNAME"
        log "✓ Using public key from: ${SSH_KEY_FOR_VM}.pub"
    else
        log "⚠️  No SSH public key found. SSH will not be hardened to a specific user."
    fi

    cat > "$SCRIPT_DIR/terraform.tfvars" << EOF
project_id     = "$PROJECT_ID"
region         = "$REGION"
zone           = "$ZONE"
machine_type   = "$MACHINE_TYPE"
cluster_name   = "${CLUSTER_NAME:-}"
cluster_zone   = "$CLUSTER_ZONE"
vm_name        = "$VM_NAME"
owner          = "$OWNER"
skip_deletion  = "$SKIP_DELETION"
permissions    = $PERMISSIONS_TF
allowed_ips    = $ALLOWED_IPS_TF
ssh_username   = "$SSH_USERNAME"
ssh_public_key = "$SSH_PUBLIC_KEY"
EOF

    log ""
    log "Initializing Terraform..."
    cd "$SCRIPT_DIR"
    terraform init -input=false

    log ""
    log "Applying Terraform (creating $VM_NAME VM)..."
    terraform apply -auto-approve

    VM_IP=$(terraform output -raw cloud_agent_ip)
    log ""
    log "✅ Cloud Agent VM created!"
    log "   Name: $VM_NAME"
    log "   External IP: $VM_IP"

    log ""
    log "Waiting 90s for VM to boot and run startup script..."
    sleep 90
fi

# Transfer credentials (only once, skip if already configured)
if [ "$SKIP_CREDS" = false ]; then
    log ""
    log "Configuring credentials on VM..."

    # Auto-detect SSH key if not explicitly set
    # Priority: cloud-auggie > cloud-agent > id_ed25519 > id_rsa
    if [ -z "$SSH_KEY" ]; then
        if [ -f "$HOME/.ssh/cloud-auggie" ]; then
            SSH_KEY="$HOME/.ssh/cloud-auggie"
            log "Auto-detected SSH key: $SSH_KEY"
        elif [ -f "$HOME/.ssh/cloud-agent" ]; then
            SSH_KEY="$HOME/.ssh/cloud-agent"
            log "Auto-detected SSH key: $SSH_KEY"
        elif [ -f "$HOME/.ssh/id_ed25519" ]; then
            SSH_KEY="$HOME/.ssh/id_ed25519"
            log "Auto-detected SSH key: $SSH_KEY"
        elif [ -f "$HOME/.ssh/id_rsa" ]; then
            SSH_KEY="$HOME/.ssh/id_rsa"
            log "Auto-detected SSH key: $SSH_KEY"
        fi
    fi

    # SSH key (recommended for enterprise orgs)
    if [ -n "$SSH_KEY" ]; then
        if [ -f "$SSH_KEY" ]; then
            log "Transferring SSH key..."
            # First, create ~/.ssh directory on the VM
            gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="mkdir -p ~/.ssh && chmod 700 ~/.ssh" 2>/dev/null

            # Transfer the private key
            if ! gcloud compute scp "$SSH_KEY" "$VM_NAME":~/.ssh/id_ed25519 --zone="$ZONE"; then
                log "❌ Failed to transfer SSH private key"
                exit 1
            fi

            # Transfer the public key if it exists
            if [ -f "${SSH_KEY}.pub" ]; then
                if ! gcloud compute scp "${SSH_KEY}.pub" "$VM_NAME":~/.ssh/id_ed25519.pub --zone="$ZONE"; then
                    log "⚠️  Failed to transfer SSH public key"
                fi
            fi

            # Configure SSH on the VM
            gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
                chmod 600 ~/.ssh/id_ed25519
                chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
                # Add public key to authorized_keys for direct SSH access
                if [ -f ~/.ssh/id_ed25519.pub ]; then
                    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
                    chmod 600 ~/.ssh/authorized_keys
                    echo '✅ Public key added to authorized_keys'
                fi
                # Add GitHub to known_hosts to avoid prompt
                ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
                git config --global user.email 'cloud-agent@localhost'
                git config --global user.name 'Cloud Agent'
                echo '✅ SSH key configured'
            "
            log "✅ SSH key transferred"
        else
            log "❌ SSH key not found: $SSH_KEY"
            exit 1
        fi
    # GitHub PAT (for personal repos / non-enterprise)
    elif [ -n "$GITHUB_TOKEN" ]; then
        log "Transferring GitHub credentials (PAT)..."
        gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
            git config --global credential.helper store
            echo 'https://oauth2:$GITHUB_TOKEN@github.com' > ~/.git-credentials
            chmod 600 ~/.git-credentials
            git config --global user.email 'cloud-agent@localhost'
            git config --global user.name 'Cloud Agent'
            echo '✅ GitHub credentials configured'
        " 2>/dev/null
        log "✅ GitHub PAT transferred"
    else
        log "⚠️  No SSH key found and no GITHUB_TOKEN set."
        log "   For enterprise: SSH_KEY=~/.ssh/cloud-agent ./deploy.sh git@github.com:org/repo.git"
        log "   For personal:   GITHUB_TOKEN=xxx ./deploy.sh https://github.com/user/repo.git"
        log "   Or create a key: ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -N ''"
    fi

    # Agent credentials (using hook)
    log "Transferring $HOOK_DISPLAY_NAME credentials..."
    AGENT_TOKEN=$(hook_get_token)

    if [ -n "$AGENT_TOKEN" ]; then
        hook_transfer_credentials "$ZONE" "$AGENT_TOKEN" "$VM_NAME"
        log "✅ $HOOK_DISPLAY_NAME credentials transferred"
    else
        log "⚠️  No $HOOK_DISPLAY_NAME credentials found."
        log "   $(hook_login_instructions)"
    fi
fi

# Clone repos
if [ ${#REPOS[@]} -gt 0 ]; then
    log ""
    log "Cloning repositories to VM..."

    # Ensure /workspace is writable (in case startup script hasn't run or VM was created before this fix)
    gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="sudo chmod 777 /workspace 2>/dev/null || true" 2>/dev/null

    for repo in "${REPOS[@]}"; do
        repo_name=$(basename "$repo" .git)
        log "  Cloning $repo_name..."

        gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
            cd /workspace
            if [ -d '$repo_name' ]; then
                echo '  ⚠️  $repo_name already exists, pulling latest...'
                cd '$repo_name' && git pull
            else
                git clone '$repo' '$repo_name'
                echo '  ✅ Cloned $repo_name'
            fi
        "
    done

    log "✅ All repositories cloned"
else
    log ""
    log "ℹ️  No repos specified. Use: $0 https://github.com/user/repo.git"
fi

# List workspace contents
log ""
log "Workspace contents:"
gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="ls -la /workspace/" 2>/dev/null

AGENT_CMD=$(hook_agent_command)

log ""
log "╔══════════════════════════════════════════════════════════════╗"
log "║  🐕 CLOUD AGENT READY!                                      ║"
log "╚══════════════════════════════════════════════════════════════╝"
log ""
log "Connect to VM (with tmux):"
log "  ca --ssh"
log ""
log "Or manually SSH:"
log "  gcloud compute ssh $VM_NAME --zone=$ZONE"
log ""
log "Start working:"
log "  cd /workspace/<repo-name>"
log "  $AGENT_CMD"
log ""
log "Agent can commit and push:"
log "  git checkout -b feature/my-changes"
log "  git add . && git commit -m 'Changes from cloud-agent'"
log "  git push -u origin feature/my-changes"
log ""
log "VM management:"
log "  ca --list       # List VMs"
log "  ca --stop       # Stop VM"
log "  ca --start      # Start VM"
log "  ca --terminate  # Delete VM"
log ""
log "🐕 GOOD LUCK!"

