variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "application" {
  description = "The application name"
  type        = string
  default     = "academyaxis"
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "The GCP billing account ID"
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "alert_email_address" {
  description = "Email address for budget alerts"
  type        = string
  default     = "devops@academyaxis.io"
}

variable "create_budget" {
  description = "Whether to create the budget (avoid duplicates)"
  type        = bool
  default     = true
}