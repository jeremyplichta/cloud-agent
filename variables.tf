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

variable "permissions" {
  description = "List of permission shortcuts to grant to the VM's service account. Empty means no service account (default). Options: admin, compute, gke, storage, network, bigquery/bq, iam, logging, pubsub, sql, secrets, dns, run, functions"
  type        = list(string)
  default     = []
}

variable "allowed_ips" {
  description = "List of IP addresses allowed to connect to the VM via SSH. Each IP should be in CIDR notation (e.g., '1.2.3.4/32'). Terraform will replace any existing firewall rules with these. Required - cannot be empty."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ips) > 0
    error_message = "allowed_ips cannot be empty. At least one IP address must be specified for SSH access."
  }
}

variable "ssh_username" {
  description = "Username allowed to SSH into the VM. If set, SSH will be restricted to only allow this user."
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Public SSH key for the allowed user. If set along with ssh_username, only key-based auth from this user is allowed."
  type        = string
  default     = ""
}

