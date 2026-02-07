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

# Service account for cloud-auggie VM with full permissions
resource "google_service_account" "cloud_auggie" {
  account_id   = "cloud-auggie-sa"
  display_name = "Cloud Auggie Service Account"
  description  = "Service account for cloud-auggie VM to manage GCP resources"
}

# Grant necessary IAM roles
resource "google_project_iam_member" "cloud_auggie_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.cloud_auggie.email}"
}

resource "google_project_iam_member" "cloud_auggie_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cloud_auggie.email}"
}

resource "google_project_iam_member" "cloud_auggie_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_auggie.email}"
}

resource "google_project_iam_member" "cloud_auggie_iam_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_auggie.email}"
}

# Cloud Auggie VM instance
resource "google_compute_instance" "cloud_auggie" {
  name         = "cloud-auggie"
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
    email  = google_service_account.cloud_auggie.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup-script.sh", {
    project_id   = var.project_id
    cluster_name = var.cluster_name
    cluster_zone = var.cluster_zone
  })

  tags = ["cloud-auggie"]

  labels = {
    purpose = "cloud-auggie"
  }
}

# Firewall rule to allow SSH
resource "google_compute_firewall" "cloud_auggie_ssh" {
  name    = "cloud-auggie-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["cloud-auggie"]
}

output "cloud_auggie_ip" {
  value       = google_compute_instance.cloud_auggie.network_interface[0].access_config[0].nat_ip
  description = "External IP of cloud-auggie VM"
}

output "cloud_auggie_internal_ip" {
  value       = google_compute_instance.cloud_auggie.network_interface[0].network_ip
  description = "Internal IP of cloud-auggie VM"
}

output "ssh_command" {
  value       = "gcloud compute ssh cloud-auggie --zone=${var.zone}"
  description = "Command to SSH into cloud-auggie VM"
}

output "service_account_email" {
  value       = google_service_account.cloud_auggie.email
  description = "Service account email for cloud-auggie"
}

