#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"

log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Get the correct CIDR suffix for an IP address
# IPv4 uses /32 for a single host, IPv6 uses /128
get_cidr_suffix() {
    local ip="$1"
    if [[ "$ip" == *:* ]]; then
        echo "/128"
    else
        echo "/32"
    fi
}

# Detect public IPv4 address for firewall rules
# GCP firewall rules don't allow mixing IPv4 and IPv6, and VMs are typically IPv4-only
# So we prioritize IPv4, but fall back to IPv6 if that's all the user has
# Returns the IP with CIDR notation, logs to stderr
detect_public_ips() {
    local ip=""
    local version=""

    # Try to get IPv4 address first (most important - GCP VMs are usually IPv4-only)
    ip=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -4 -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")
    if [ -n "$ip" ]; then
        echo "[$(date +'%H:%M:%S')] ✓ Your IPv4 address: $ip" >&2
        echo "${ip}/32"
        return 0
    fi

    # Fall back to IPv6 only if no IPv4 is available
    ip=$(curl -6 -s --connect-timeout 5 ifconfig.me 2>/dev/null || curl -6 -s --connect-timeout 5 icanhazip.com 2>/dev/null || echo "")
    if [ -n "$ip" ]; then
        echo "[$(date +'%H:%M:%S')] ⚠️  No IPv4 address found, using IPv6: $ip" >&2
        echo "[$(date +'%H:%M:%S')] ⚠️  Note: GCP VMs are typically IPv4-only. You may need to use a VPN or different network." >&2
        echo "${ip}/128"
        return 0
    fi

    echo "[$(date +'%H:%M:%S')] ❌ ERROR: Could not detect any public IP address." >&2
    return 1
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
  --username NAME   Override the derived username/owner (e.g., jeremy_plichta_redis_com)
                    By default, derived from \$USER and \$COMPANY env vars
  --list            List cloud-agent VMs and their status
  --start           Start a stopped cloud-agent VM
  --stop            Stop (but don't delete) the cloud-agent VM
  --terminate       Terminate (delete) the cloud-agent VM
  --ssh             SSH into the VM and attach to tmux session
  --scp SRC DST     Copy files to/from VM using 'vm:' prefix for remote paths
                    Examples: ca --scp ./file.txt vm:/workspace/
                              ca --scp vm:/workspace/file.txt ./
  --tf              Re-apply terraform with current variables (useful for updating
                    firewall rules, SSH keys, or other infrastructure changes)
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
  COMPANY           Company domain to append to username (e.g., redis.com)
                    Results in owner like: firstname_lastname_redis_com
  USERNAME          Override derived username/owner (same as --username)

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

# Derive owner from $USER, $COMPANY, and optional override
# Usage: get_owner [override]
# Returns: owner in format firstname_lastname or firstname_lastname_company_com
get_owner() {
    local override="${1:-${USERNAME:-}}"

    # If override is provided, use it directly (just normalize)
    if [ -n "$override" ]; then
        echo "$override" | tr '[:upper:]' '[:lower:]' | tr '.-' '_'
        return
    fi

    local owner
    if [[ "$USER" == *.* ]]; then
        # User has firstname.lastname format
        owner=$(echo "$USER" | tr '.' '_')
    else
        owner="$USER"
    fi

    # Append company if COMPANY env var is set
    if [ -n "${COMPANY:-}" ]; then
        # Convert company domain to underscore format (redis.com -> redis_com)
        local company_suffix=$(echo "$COMPANY" | tr '[:upper:]' '[:lower:]' | tr '.-' '_')
        owner="${owner}_${company_suffix}"
    fi

    # Normalize to lowercase
    echo "$owner" | tr '[:upper:]' '[:lower:]'
}

# Get SSH username - same as owner but with hyphens instead of underscores
# (Linux usernames work better with hyphens)
# Returns: firstname-lastname or firstname-lastname-company-com
get_ssh_username() {
    # Get the owner format and convert underscores to hyphens
    get_owner | tr '_' '-'
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
            # Get VM IP from terraform state or gcloud
            local vm_ip=""
            if [ -f "$SCRIPT_DIR/terraform.tfstate" ]; then
                vm_ip=$(cd "$SCRIPT_DIR" && terraform output -raw cloud_agent_ip 2>/dev/null || true)
            fi
            if [ -z "$vm_ip" ]; then
                vm_ip=$(gcloud compute instances describe "$vm_name" --zone="$zone" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true)
            fi
            if [ -z "$vm_ip" ]; then
                log "❌ Could not determine VM IP address"
                exit 1
            fi

            # Determine SSH key and username
            local ssh_key=""
            if [ -n "$SSH_KEY" ]; then
                ssh_key="$SSH_KEY"
            elif [ -f "$HOME/.ssh/cloud-auggie" ]; then
                ssh_key="$HOME/.ssh/cloud-auggie"
            elif [ -f "$HOME/.ssh/cloud-agent" ]; then
                ssh_key="$HOME/.ssh/cloud-agent"
            elif [ -f "$HOME/.ssh/id_ed25519" ]; then
                ssh_key="$HOME/.ssh/id_ed25519"
            elif [ -f "$HOME/.ssh/id_rsa" ]; then
                ssh_key="$HOME/.ssh/id_rsa"
            fi

            # Derive SSH username (same logic as terraform config)
            local ssh_user=$(get_ssh_username)

            # Warn if COMPANY is not set (common source of SSH issues)
            if [ -z "${COMPANY:-}" ]; then
                log "⚠️  WARNING: COMPANY env var not set"
                log "   SSH username: $ssh_user"
                log "   If this doesn't match your VM's configured user, set: export COMPANY=your.domain"
            fi

            log "Connecting to $vm_name ($vm_ip) as $ssh_user..."
            log "Using SSH key: $ssh_key"

            # Use direct SSH with explicit key (bypasses gcloud's key management)
            ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new \
                "$ssh_user@$vm_ip" -t "tmux attach-session 2>/dev/null || tmux new-session"
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

            # Get VM IP from terraform state or gcloud
            local vm_ip=""
            if [ -f "$SCRIPT_DIR/terraform.tfstate" ]; then
                vm_ip=$(cd "$SCRIPT_DIR" && terraform output -raw cloud_agent_ip 2>/dev/null || true)
            fi
            if [ -z "$vm_ip" ]; then
                vm_ip=$(gcloud compute instances describe "$vm_name" --zone="$zone" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true)
            fi
            if [ -z "$vm_ip" ]; then
                log "❌ Could not determine VM IP address"
                exit 1
            fi

            # Determine SSH key
            local ssh_key=""
            if [ -n "$SSH_KEY" ]; then
                ssh_key="$SSH_KEY"
            elif [ -f "$HOME/.ssh/cloud-auggie" ]; then
                ssh_key="$HOME/.ssh/cloud-auggie"
            elif [ -f "$HOME/.ssh/cloud-agent" ]; then
                ssh_key="$HOME/.ssh/cloud-agent"
            elif [ -f "$HOME/.ssh/id_ed25519" ]; then
                ssh_key="$HOME/.ssh/id_ed25519"
            elif [ -f "$HOME/.ssh/id_rsa" ]; then
                ssh_key="$HOME/.ssh/id_rsa"
            fi

            # Derive SSH username
            local ssh_user=$(get_ssh_username)

            # Warn if COMPANY is not set
            if [ -z "${COMPANY:-}" ]; then
                log "⚠️  WARNING: COMPANY env var not set"
                log "   SSH username: $ssh_user"
                log "   If this doesn't match your VM's configured user, set: export COMPANY=your.domain"
            fi

            # Replace 'vm:' prefix with user@ip:
            src="${src//vm:/$ssh_user@$vm_ip:}"
            dst="${dst//vm:/$ssh_user@$vm_ip:}"

            log "Copying files..."
            scp -i "$ssh_key" -o StrictHostKeyChecking=accept-new -r "$src" "$dst"
            log "✅ Copy complete"
            exit 0
            ;;
        tf)
            # Re-apply terraform with current variables
            log "Re-applying terraform configuration..."

            # Check for terraform state
            if [ ! -f "$SCRIPT_DIR/terraform.tfstate" ]; then
                log "❌ ERROR: No terraform state found. Create VM first with: ca <repo>"
                exit 1
            fi

            # Get GCP project ID
            local project_id=$(gcloud config get-value project 2>/dev/null)
            if [ -z "$project_id" ]; then
                log "❌ ERROR: No GCP project configured. Run: gcloud config set project PROJECT_ID"
                exit 1
            fi

            # Configuration
            local region="${REGION:-us-central1}"
            local cluster_zone="${CLUSTER_ZONE:-$zone}"
            local machine_type="${MACHINE_TYPE:-n2-standard-4}"
            local cluster_name="${CLUSTER_NAME:-}"
            local skip_deletion="${SKIP_DELETION:-yes}"
            local permissions="${PERMISSIONS:-}"
            local additional_ip="${ADDITIONAL_IP:-}"

            # Derive owner using helper function
            local owner=$(get_owner)

            # Convert comma-separated permissions to Terraform list format
            local permissions_tf
            if [ -n "$permissions" ]; then
                permissions_tf=$(echo "$permissions" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
            else
                permissions_tf="[]"
            fi

            # Get current public IPs for firewall rules (both IPv4 and IPv6)
            log "Detecting your public IP addresses..."
            local allowed_ips=$(detect_public_ips)
            if [ -z "$allowed_ips" ]; then
                exit 1
            fi

            # Add any additional IP
            if [ -n "$additional_ip" ]; then
                if [[ ! "$additional_ip" =~ / ]]; then
                    local additional_cidr_suffix=$(get_cidr_suffix "$additional_ip")
                    additional_ip="${additional_ip}${additional_cidr_suffix}"
                fi
                allowed_ips="${allowed_ips},${additional_ip}"
                log "✓ Additional whitelisted IP: $additional_ip"
            fi
            local allowed_ips_tf=$(echo "$allowed_ips" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
            log "✓ Firewall will allow SSH from: $allowed_ips"

            # Detect SSH key for SSH hardening
            local ssh_key_for_vm=""
            if [ -z "$SSH_KEY" ]; then
                if [ -f "$HOME/.ssh/cloud-auggie" ]; then
                    ssh_key_for_vm="$HOME/.ssh/cloud-auggie"
                elif [ -f "$HOME/.ssh/cloud-agent" ]; then
                    ssh_key_for_vm="$HOME/.ssh/cloud-agent"
                elif [ -f "$HOME/.ssh/id_ed25519" ]; then
                    ssh_key_for_vm="$HOME/.ssh/id_ed25519"
                elif [ -f "$HOME/.ssh/id_rsa" ]; then
                    ssh_key_for_vm="$HOME/.ssh/id_rsa"
                fi
            else
                ssh_key_for_vm="$SSH_KEY"
            fi

            # Get SSH public key content and username
            local ssh_username=""
            local ssh_public_key=""
            if [ -n "$ssh_key_for_vm" ] && [ -f "${ssh_key_for_vm}.pub" ]; then
                ssh_public_key=$(cat "${ssh_key_for_vm}.pub")
                ssh_username=$(get_ssh_username)
                log "✓ SSH will be secured for user: $ssh_username"
                log "✓ Using public key from: ${ssh_key_for_vm}.pub"
            else
                log "⚠️  No SSH public key found. SSH will not be hardened to a specific user."
            fi

            # Write terraform.tfvars
            log ""
            log "Updating terraform.tfvars..."
            cat > "$SCRIPT_DIR/terraform.tfvars" << EOF
project_id     = "$project_id"
region         = "$region"
zone           = "$zone"
machine_type   = "$machine_type"
cluster_name   = "$cluster_name"
cluster_zone   = "$cluster_zone"
vm_name        = "$vm_name"
owner          = "$owner"
skip_deletion  = "$skip_deletion"
permissions    = $permissions_tf
allowed_ips    = $allowed_ips_tf
ssh_username   = "$ssh_username"
ssh_public_key = "$ssh_public_key"
EOF

            log ""
            log "Applying Terraform..."
            cd "$SCRIPT_DIR"
            terraform apply -auto-approve

            log ""
            log "✅ Terraform apply complete!"
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
        --username)
            USERNAME="$2"
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
        --tf)
            handle_vm_command "tf"
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

# Derive VM name and owner
VM_NAME=$(get_vm_name)
OWNER=$(get_owner)

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

    # Get current public IPs for firewall rules (both IPv4 and IPv6)
    # GCP VMs are typically IPv4-only, so IPv4 is most important
    log "Detecting your public IP addresses..."
    ALLOWED_IPS=$(detect_public_ips)
    if [ -z "$ALLOWED_IPS" ]; then
        log "   This is required to secure the firewall rules."
        log "   Please check your internet connection and try again."
        exit 1
    fi

    # Add any additional IP
    if [ -n "$ADDITIONAL_IP" ]; then
        # Add CIDR suffix if not already in CIDR notation
        if [[ ! "$ADDITIONAL_IP" =~ / ]]; then
            ADDITIONAL_CIDR_SUFFIX=$(get_cidr_suffix "$ADDITIONAL_IP")
            ADDITIONAL_IP="${ADDITIONAL_IP}${ADDITIONAL_CIDR_SUFFIX}"
        fi
        ALLOWED_IPS="${ALLOWED_IPS},${ADDITIONAL_IP}"
        log "✓ Additional whitelisted IP: $ADDITIONAL_IP"
    fi
    # Convert to Terraform list format: ["1.2.3.4/32", "5.6.7.8/32"]
    ALLOWED_IPS_TF=$(echo "$ALLOWED_IPS" | sed 's/,/", "/g' | sed 's/^/["/' | sed 's/$/"]/')
    log "✓ Firewall will allow SSH from: $ALLOWED_IPS"

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
        SSH_USERNAME=$(get_ssh_username)
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

    # Get VM IP for direct SSH (we use direct SSH instead of gcloud ssh because
    # we've disabled project-level SSH keys for security)
    VM_IP=$(cd "$SCRIPT_DIR" && terraform output -raw cloud_agent_ip 2>/dev/null || true)
    if [ -z "$VM_IP" ]; then
        VM_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true)
    fi
    if [ -z "$VM_IP" ]; then
        log "❌ Could not determine VM IP address"
        exit 1
    fi

    # Get SSH username (must match what was configured in terraform)
    CRED_SSH_USER=$(get_ssh_username)
    log "Using SSH: $CRED_SSH_USER@$VM_IP"

    # Helper function for running SSH commands on the VM
    vm_ssh() {
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
            "$CRED_SSH_USER@$VM_IP" "$@"
    }

    # Helper function for SCP to the VM
    vm_scp() {
        scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$@"
    }

    # SSH key (recommended for enterprise orgs)
    if [ -n "$SSH_KEY" ]; then
        if [ -f "$SSH_KEY" ]; then
            log "Transferring GitHub SSH key..."
            # First, create ~/.ssh directory on the VM
            vm_ssh "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

            # Transfer the private key (for git operations)
            if ! vm_scp "$SSH_KEY" "$CRED_SSH_USER@$VM_IP:~/.ssh/id_ed25519"; then
                log "❌ Failed to transfer SSH private key"
                exit 1
            fi

            # Transfer the public key if it exists
            if [ -f "${SSH_KEY}.pub" ]; then
                if ! vm_scp "${SSH_KEY}.pub" "$CRED_SSH_USER@$VM_IP:~/.ssh/id_ed25519.pub"; then
                    log "⚠️  Failed to transfer SSH public key"
                fi
            fi

            # Configure SSH on the VM
            vm_ssh "
                chmod 600 ~/.ssh/id_ed25519
                chmod 644 ~/.ssh/id_ed25519.pub 2>/dev/null || true
                # Add GitHub to known_hosts to avoid prompt
                ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
                git config --global user.email 'cloud-agent@localhost'
                git config --global user.name 'Cloud Agent'
                echo '✅ SSH key configured for git'
            "
            log "✅ GitHub SSH key transferred"
        else
            log "❌ SSH key not found: $SSH_KEY"
            exit 1
        fi
    # GitHub PAT (for personal repos / non-enterprise)
    elif [ -n "$GITHUB_TOKEN" ]; then
        log "Transferring GitHub credentials (PAT)..."
        vm_ssh "
            git config --global credential.helper store
            echo 'https://oauth2:$GITHUB_TOKEN@github.com' > ~/.git-credentials
            chmod 600 ~/.git-credentials
            git config --global user.email 'cloud-agent@localhost'
            git config --global user.name 'Cloud Agent'
            echo '✅ GitHub credentials configured'
        "
        log "✅ GitHub PAT transferred"
    else
        log "⚠️  No SSH key found and no GITHUB_TOKEN set."
        log "   For enterprise: SSH_KEY=~/.ssh/cloud-agent ./deploy.sh git@github.com:org/repo.git"
        log "   For personal:   GITHUB_TOKEN=xxx ./deploy.sh https://github.com/user/repo.git"
        log "   Or create a key: ssh-keygen -t ed25519 -f ~/.ssh/cloud-agent -N ''"
    fi

    # Transfer ALL agent credentials (not just the selected one)
    # This allows switching agents on the VM without re-deploying
    log ""
    log "Transferring AI agent credentials..."

    # Augment credentials
    if [ -f "$HOME/.augment/session.json" ]; then
        log "  Transferring Augment credentials..."
        TEMP_AUGMENT=$(mktemp)
        cat "$HOME/.augment/session.json" > "$TEMP_AUGMENT"
        if vm_scp "$TEMP_AUGMENT" "$CRED_SSH_USER@$VM_IP:~/augment-session-temp.json"; then
            vm_ssh "mkdir -p ~/.augment && mv ~/augment-session-temp.json ~/.augment/session.json && chmod 600 ~/.augment/session.json"
            log "  ✅ Augment credentials transferred"
        fi
        rm -f "$TEMP_AUGMENT"
    else
        log "  ⚠️  No Augment credentials found (~/.augment/session.json)"
        log "     Run 'auggie login' locally to configure"
    fi

    # Claude Code credentials
    if [ -f "$HOME/.claude.json" ]; then
        log "  Transferring Claude Code credentials..."
        TEMP_CLAUDE=$(mktemp)
        cat "$HOME/.claude.json" > "$TEMP_CLAUDE"
        if vm_scp "$TEMP_CLAUDE" "$CRED_SSH_USER@$VM_IP:~/.claude.json"; then
            vm_ssh "chmod 600 ~/.claude.json && mkdir -p ~/.claude"
            log "  ✅ Claude Code credentials transferred"
        fi
        rm -f "$TEMP_CLAUDE"
    else
        log "  ⚠️  No Claude Code credentials found (~/.claude.json)"
        log "     Run 'claude' locally to configure"
    fi

    # Codex credentials
    if [ -f "$HOME/.codex/config.toml" ]; then
        log "  Transferring Codex credentials..."
        TEMP_CODEX=$(mktemp)
        cat "$HOME/.codex/config.toml" > "$TEMP_CODEX"
        if vm_scp "$TEMP_CODEX" "$CRED_SSH_USER@$VM_IP:~/codex-config-temp.toml"; then
            vm_ssh "mkdir -p ~/.codex && mv ~/codex-config-temp.toml ~/.codex/config.toml && chmod 600 ~/.codex/config.toml"
            log "  ✅ Codex credentials transferred"
        fi
        rm -f "$TEMP_CODEX"
    else
        log "  ⚠️  No Codex credentials found (~/.codex/config.toml)"
        log "     Run 'codex' locally to configure"
    fi
fi

# Clone repos
if [ ${#REPOS[@]} -gt 0 ]; then
    log ""
    log "Cloning repositories to VM..."

    # Get VM IP if not already set (may have been set in credential transfer)
    if [ -z "${VM_IP:-}" ]; then
        VM_IP=$(cd "$SCRIPT_DIR" && terraform output -raw cloud_agent_ip 2>/dev/null || true)
        if [ -z "$VM_IP" ]; then
            VM_IP=$(gcloud compute instances describe "$VM_NAME" --zone="$ZONE" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || true)
        fi
    fi

    # Get SSH username if not already set
    if [ -z "${CRED_SSH_USER:-}" ]; then
        CRED_SSH_USER=$(get_ssh_username)
    fi

    # Auto-detect SSH key if not set
    if [ -z "${SSH_KEY:-}" ]; then
        for key_path in "$HOME/.ssh/cloud-auggie" "$HOME/.ssh/cloud-agent" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
            if [ -f "$key_path" ]; then
                SSH_KEY="$key_path"
                break
            fi
        done
    fi

    # Helper function for running SSH commands on the VM (redefine if not in creds block)
    vm_ssh() {
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
            "$CRED_SSH_USER@$VM_IP" "$@"
    }

    # Ensure /workspace is writable (in case startup script hasn't run or VM was created before this fix)
    vm_ssh "sudo chmod 777 /workspace 2>/dev/null || true" 2>/dev/null

    for repo in "${REPOS[@]}"; do
        repo_name=$(basename "$repo" .git)
        log "  Cloning $repo_name..."

        vm_ssh "
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
# Get VM IP if not already set
if [ -z "${VM_IP:-}" ]; then
    VM_IP=$(cd "$SCRIPT_DIR" && terraform output -raw cloud_agent_ip 2>/dev/null || true)
fi
if [ -z "${CRED_SSH_USER:-}" ]; then
    CRED_SSH_USER=$(get_ssh_username)
fi
if [ -z "${SSH_KEY:-}" ]; then
    for key_path in "$HOME/.ssh/cloud-auggie" "$HOME/.ssh/cloud-agent" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        if [ -f "$key_path" ]; then
            SSH_KEY="$key_path"
            break
        fi
    done
fi
if [ -n "${VM_IP:-}" ] && [ -n "${SSH_KEY:-}" ]; then
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$CRED_SSH_USER@$VM_IP" "ls -la /workspace/" 2>/dev/null
fi

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
log "  ssh -i ~/.ssh/cloud-auggie $CRED_SSH_USER@$VM_IP"
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

