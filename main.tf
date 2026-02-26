terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# =============================================================================
# NETWORKING - Dedicated VPC per user for isolation
# =============================================================================

# VPC Network - dedicated to this user's cloud-agent
resource "google_compute_network" "cloud_agent" {
  name                    = "${var.vm_name}-network"
  auto_create_subnetworks = false
  description             = "Dedicated network for ${var.vm_name} cloud-agent VM"
}

# Subnet for the cloud-agent VM
resource "google_compute_subnetwork" "cloud_agent" {
  name          = "${var.vm_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.cloud_agent.id
  description   = "Subnet for ${var.vm_name} cloud-agent VM"
}

# Firewall rule - Allow SSH from specified IPs only
resource "google_compute_firewall" "cloud_agent_ssh" {
  name    = "${var.vm_name}-allow-ssh"
  network = google_compute_network.cloud_agent.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Only allow connections from specified IPs
  source_ranges = var.allowed_ips
  description   = "Allow SSH access to ${var.vm_name} from whitelisted IPs"
}

# Firewall rule - Allow all egress (for package downloads, git, etc.)
resource "google_compute_firewall" "cloud_agent_egress" {
  name      = "${var.vm_name}-allow-egress"
  network   = google_compute_network.cloud_agent.id
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  description        = "Allow all outbound traffic from ${var.vm_name}"
}

# =============================================================================
# IAM - Service account and permissions (optional)
# =============================================================================

# Local variables for permission mapping
locals {
  # Map of permission shortcuts to GCP IAM roles
  permission_roles = {
    compute  = "roles/compute.admin"
    gke      = "roles/container.admin"
    storage  = "roles/storage.admin"
    network  = "roles/compute.networkAdmin"
    bigquery = "roles/bigquery.admin"
    bq       = "roles/bigquery.admin"
    iam      = "roles/iam.serviceAccountUser"
    logging  = "roles/logging.admin"
    pubsub   = "roles/pubsub.admin"
    sql      = "roles/cloudsql.admin"
    secrets  = "roles/secretmanager.admin"
    dns      = "roles/dns.admin"
    run      = "roles/run.admin"
    functions = "roles/cloudfunctions.admin"
  }

  # Admin permission grants all common admin roles
  admin_roles = [
    "roles/compute.admin",
    "roles/container.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser"
  ]

  # Determine if we need a service account (permissions is not empty)
  has_permissions = length(var.permissions) > 0

  # Calculate the actual roles to grant
  # If "admin" is in the list, use admin_roles; otherwise map each permission to its role
  is_admin = contains(var.permissions, "admin")

  requested_roles = local.is_admin ? local.admin_roles : [
    for perm in var.permissions : local.permission_roles[perm]
    if contains(keys(local.permission_roles), perm)
  ]

  # Deduplicate roles (in case of aliases like bq/bigquery)
  unique_roles = distinct(local.requested_roles)
}

# Service account for cloud-agent VM (only created when permissions are specified)
resource "google_service_account" "cloud_agent" {
  count        = local.has_permissions ? 1 : 0
  account_id   = "${var.vm_name}-sa"
  display_name = "Cloud Agent Service Account (${var.vm_name})"
  description  = "Service account for ${var.vm_name} VM to manage GCP resources"
}

# Grant IAM roles based on permissions variable
resource "google_project_iam_member" "cloud_agent_roles" {
  for_each = local.has_permissions ? toset(local.unique_roles) : []
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.cloud_agent[0].email}"
}

# =============================================================================
# COMPUTE - Cloud Agent VM instance
# =============================================================================

resource "google_compute_instance" "cloud_agent" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-standard"
    }
  }

  # Use the dedicated VPC network and subnet
  network_interface {
    network    = google_compute_network.cloud_agent.id
    subnetwork = google_compute_subnetwork.cloud_agent.id
    access_config {
      # Ephemeral external IP for SSH access and outbound internet
    }
  }

  # Only attach service account when permissions are specified
  dynamic "service_account" {
    for_each = local.has_permissions ? [1] : []
    content {
      email  = google_service_account.cloud_agent[0].email
      scopes = ["cloud-platform"]
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    project_id     = var.project_id
    cluster_name   = var.cluster_name
    cluster_zone   = var.cluster_zone
    ssh_username   = var.ssh_username
    ssh_public_key = var.ssh_public_key
  })

  # SSH Security: Block all project-level and OS Login SSH access
  # Only allow the explicitly configured SSH key for the specified user
  metadata = {
    block-project-ssh-keys = "true"   # Block project-level SSH keys
    enable-oslogin         = "FALSE"  # Disable OS Login (IAM-based SSH)
    # Add our SSH key to instance metadata so guest agent configures it
    # Format: username:ssh-key-content
    ssh-keys               = var.ssh_username != "" && var.ssh_public_key != "" ? "${var.ssh_username}:${var.ssh_public_key}" : null
  }

  tags = ["cloud-agent", var.vm_name]

  labels = {
    purpose       = "cloud-agent"
    owner         = var.owner
    skip_deletion = var.skip_deletion
  }

  # Ensure network is created before VM
  depends_on = [
    google_compute_network.cloud_agent,
    google_compute_subnetwork.cloud_agent,
    google_compute_firewall.cloud_agent_ssh,
    google_compute_firewall.cloud_agent_egress
  ]
}

output "cloud_agent_ip" {
  value       = google_compute_instance.cloud_agent.network_interface[0].access_config[0].nat_ip
  description = "External IP of cloud-agent VM"
}

output "cloud_agent_internal_ip" {
  value       = google_compute_instance.cloud_agent.network_interface[0].network_ip
  description = "Internal IP of cloud-agent VM"
}

output "ssh_command" {
  value       = "gcloud compute ssh ${var.vm_name} --zone=${var.zone}"
  description = "Command to SSH into cloud-agent VM"
}

output "vm_name" {
  value       = var.vm_name
  description = "Name of the cloud-agent VM"
}

output "service_account_email" {
  value       = local.has_permissions ? google_service_account.cloud_agent[0].email : null
  description = "Service account email for cloud-agent (null if no permissions specified)"
}

output "network_name" {
  value       = google_compute_network.cloud_agent.name
  description = "Name of the dedicated VPC network for this cloud-agent"
}

output "subnet_name" {
  value       = google_compute_subnetwork.cloud_agent.name
  description = "Name of the subnet for this cloud-agent"
}
