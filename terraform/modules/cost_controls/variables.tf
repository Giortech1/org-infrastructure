variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "env" {
  description = "The environment name (e.g., dev, prod)"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "billing_account_id" {
  description = "The billing account ID"
  type        = string
}

variable "budget_amount" {
  description = "The budget amount in USD"
  type        = number
}

variable "alert_email_address" {
  description = "The email address to send budget alerts"
  type        = string
}

variable "create_budget" {
  description = "Whether to create the budget"
  type        = bool
  default     = true
}
