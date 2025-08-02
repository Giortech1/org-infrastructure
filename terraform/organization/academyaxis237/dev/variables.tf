variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "academyaxis-237-dev-project"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment (dev, uat, prod)"
  type        = string
  default     = "dev"
}

variable "billing_account_id" {
  description = "Billing account ID"
  type        = string
  default     = "0156AD-1517D4-139949"  # AcademyAxis-237 billing account
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 50
}

variable "alert_email_address" {
  description = "Email address for alerts"
  type        = string
  default     = "admin@giortech.com"
}

variable "create_identity_pool" {
  description = "Whether to create the workload identity pool"
  type        = bool
  default     = false
}

variable "create_service_account" {
  description = "Whether to create the service account"
  type        = bool
  default     = false
}

variable "create_budget" {
  description = "Whether to create budget"
  type        = bool
  default     = true
}
