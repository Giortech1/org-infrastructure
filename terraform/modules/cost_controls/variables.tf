# terraform/modules/cost_controls/variables.tf
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "application" {
  description = "Application name (giortech, waspwallet, academyaxis)"
  type        = string
  validation {
    condition     = contains(["giortech", "waspwallet", "academyaxis"], var.application)
    error_message = "Application must be one of: giortech, waspwallet, academyaxis."
  }
}

variable "environment" {
  description = "Environment (dev, uat, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "billing_account_id" {
  description = "The GCP billing account ID"
  type        = string
}

variable "budget_amount" {
  description = "Budget amount in USD"
  type        = number
  validation {
    condition     = var.budget_amount > 0 && var.budget_amount <= 300
    error_message = "Budget amount must be between 1 and 300 USD."
  }
}

variable "alert_email_address" {
  description = "Email address for budget and monitoring alerts"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email_address))
    error_message = "Please provide a valid email address."
  }
}

variable "create_budget" {
  description = "Whether to create budget (set to false if budget already exists)"
  type        = bool
  default     = true
}

variable "enable_cost_optimization" {
  description = "Whether to enable automatic cost optimization features"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs (overrides environment default)"
  type        = number
  default     = null
}

variable "enable_alerts" {
  description = "Whether to enable monitoring alerts"
  type        = bool
  default     = true
}