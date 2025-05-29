variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "github_org" {
  description = "The GitHub organization name"
  type        = string
  default     = "Giortech1"
}

variable "github_repo" {
  description = "The GitHub repository name"
  type        = string
  default     = "org-infrastructure"
}

variable "create_identity_pool" {
  description = "Whether to create the workload identity pool"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create the service account"
  type        = bool
  default     = true
}