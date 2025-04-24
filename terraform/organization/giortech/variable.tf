variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
}

variable "billing_account_id" {
  description = "The GCP billing account ID"
  type        = string
}

variable "budget_amount" {
  description = "Budget amount in USD for this environment"
  type        = number
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

variable "deploy_cloud_run" {
  description = "Whether to deploy Cloud Run service"
  type        = bool
  default     = true
}

variable "create_budget" {
  description = "Whether to create budget"
  type        = bool
  default     = true
}

# New variable for container image
variable "container_image" {
  description = "The container image to use for Cloud Run"
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0" # Default to a working sample image
}