variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "academyaxis-dev-project"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
  default     = "dev"
}

variable "application" {
  description = "The application name"
  type        = string
  default     = "academyaxis"
}

# Educational platform variables (to match what we added in main.tf)
variable "educational_region" {
  description = "Educational region for compliance and customization"
  type        = string
  default     = "global"
}

variable "supported_languages" {
  description = "Supported languages for the educational platform"
  type        = list(string)
  default     = ["en-US"]
}

variable "grading_system" {
  description = "Grading system used"
  type        = string
  default     = "flexible"
}

variable "academic_year_start" {
  description = "Academic year start month (1-12)"
  type        = number
  default     = 9
}

variable "school_hours_start" {
  description = "School day start hour (0-23)"
  type        = number
  default     = 8
}

variable "school_hours_end" {
  description = "School day end hour (0-23)"
  type        = number
  default     = 16
}

variable "payment_providers" {
  description = "Payment providers for school fees"
  type        = list(string)
  default     = ["stripe"]
}

variable "sms_provider" {
  description = "SMS provider for school communications"
  type        = string
  default     = "twilio"
}

variable "school_onboarding_key" {
  description = "Secret key for automated school onboarding"
  type        = string
  default     = "dev-educational-key-2024"
  sensitive   = true
}