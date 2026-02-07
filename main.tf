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

# Service account for cloud-agent VM with full permissions
resource "google_service_account" "cloud_agent" {
  account_id   = "cloud-agent-sa"
  display_name = "Cloud Agent Service Account"
  description  = "Service account for cloud-agent VM to manage GCP resources"
}

# Grant necessary IAM roles
resource "google_project_iam_member" "cloud_agent_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.cloud_agent.email}"
}

resource "google_project_iam_member" "cloud_agent_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cloud_agent.email}"
}

resource "google_project_iam_member" "cloud_agent_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_agent.email}"
}

resource "google_project_iam_member" "cloud_agent_iam_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_agent.email}"
}

# Cloud Agent VM instance
resource "google_compute_instance" "cloud_agent" {
  name         = "cloud-agent"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP
    }
  }

  service_account {
    email  = google_service_account.cloud_agent.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    project_id   = var.project_id
    cluster_name = var.cluster_name
    cluster_zone = var.cluster_zone
  })

  tags = ["cloud-agent"]

  labels = {
    purpose = "cloud-agent"
  }
}

# Firewall rule to allow SSH
resource "google_compute_firewall" "cloud_agent_ssh" {
  name    = "cloud-agent-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["cloud-agent"]
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
  value       = "gcloud compute ssh cloud-agent --zone=${var.zone}"
  description = "Command to SSH into cloud-agent VM"
}

output "service_account_email" {
  value       = google_service_account.cloud_agent.email
  description = "Service account email for cloud-agent"
}

