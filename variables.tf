variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for cloud-agent VM"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Machine type for cloud-agent VM"
  type        = string
  default     = "n2-standard-4"
}

variable "vm_name" {
  description = "Name of the cloud-agent VM (typically {user}-cloud-agent)"
  type        = string
}

variable "owner" {
  description = "Owner of the VM in firstname_lastname format"
  type        = string
}

variable "skip_deletion" {
  description = "Whether to skip automatic deletion of the VM (yes/no)"
  type        = string
  default     = "yes"
}

variable "cluster_name" {
  description = "Name of the GKE cluster to configure kubectl for (optional)"
  type        = string
  default     = ""
}

variable "cluster_zone" {
  description = "Zone of the GKE cluster (only used if cluster_name is set)"
  type        = string
  default     = "us-central1-a"
}

