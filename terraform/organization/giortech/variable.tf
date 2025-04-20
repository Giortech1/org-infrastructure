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