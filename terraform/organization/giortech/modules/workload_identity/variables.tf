# modules/workload_identity/variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "pool_id" {
  description = "The Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "provider_id" {
  description = "The Workload Identity Provider ID"
  type        = string
  default     = "github-provider"
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "giortech1"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "org-infrastructure" 
}

variable "service_account_id" {
  description = "The ID of the service account to create"
  type        = string
  default     = "github-actions-sa"
}

variable "service_account_roles" {
  description = "The roles to assign to the service account"
  type        = list(string)
  default     = [
    "roles/run.admin",
    "roles/storage.admin",
    "roles/iam.serviceAccountUser",
    "roles/compute.loadBalancerAdmin",
    "roles/dns.admin",
    "roles/certificatemanager.admin"
  ]
}

variable "create_identity_pool" {
  description = "Whether to create the workload identity pool and provider"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create the service account"
  type        = bool
  default     = true
}