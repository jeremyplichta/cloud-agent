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
  description = "GCP zone for cloud-auggie VM"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "Machine type for cloud-auggie VM"
  type        = string
  default     = "n2-standard-4"
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

