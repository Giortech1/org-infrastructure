# terraform/modules/educational_platform/variables.tf
# Educational Platform Variables (Bitrix24-inspired multi-tenancy)

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "firestore_region" {
  description = "The Firestore region"
  type        = string
  default     = "us-central"
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "Environment must be one of: dev, uat, prod."
  }
}

variable "application" {
  description = "The application name"
  type        = string
  default     = "academyaxis"
}

# Educational-specific variables
variable "educational_region" {
  description = "Educational region for compliance and customization"
  type        = string
  default     = "global"
  validation {
    condition     = contains(["global", "africa", "cameroon", "usa", "europe"], var.educational_region)
    error_message = "Educational region must be one of: global, africa, cameroon, usa, europe."
  }
}

variable "supported_languages" {
  description = "Supported languages for the educational platform"
  type        = list(string)
  default     = ["en-US"]
}

variable "default_language" {
  description = "Default language for the educational platform"
  type        = string
  default     = "en-US"
}

variable "grading_system" {
  description = "Grading system used (flexible, 4_point, 100_point, 20_point)"
  type        = string
  default     = "flexible"
  validation {
    condition     = contains(["flexible", "4_point", "100_point", "20_point"], var.grading_system)
    error_message = "Grading system must be one of: flexible, 4_point, 100_point, 20_point."
  }
}

# Academic schedule variables (for Bitrix24-style scheduling)
variable "academic_year_start" {
  description = "Academic year start month (1-12)"
  type        = number
  default     = 9  # September
  validation {
    condition     = var.academic_year_start >= 1 && var.academic_year_start <= 12
    error_message = "Academic year start must be between 1 and 12."
  }
}

variable "school_hours_start" {
  description = "School day start hour (0-23)"
  type        = number
  default     = 8
  validation {
    condition     = var.school_hours_start >= 0 && var.school_hours_start <= 23
    error_message = "School hours start must be between 0 and 23."
  }
}

variable "school_hours_end" {
  description = "School day end hour (0-23)"
  type        = number
  default     = 16
  validation {
    condition     = var.school_hours_end >= 0 && var.school_hours_end <= 23
    error_message = "School hours end must be between 0 and 23."
  }
}

variable "school_timezone" {
  description = "School timezone for scheduling"
  type        = string
  default     = "America/New_York"
}

# Scaling factors (Bitrix24-inspired auto-scaling)
variable "holiday_scaling_factor" {
  description = "Scaling factor during holidays (0.0-1.0)"
  type        = number
  default     = 0.1
  validation {
    condition     = var.holiday_scaling_factor >= 0.0 && var.holiday_scaling_factor <= 1.0
    error_message = "Holiday scaling factor must be between 0.0 and 1.0."
  }
}

variable "exam_period_scaling_factor" {
  description = "Scaling factor during exam periods (1.0-3.0)"
  type        = number
  default     = 1.5
  validation {
    condition     = var.exam_period_scaling_factor >= 1.0 && var.exam_period_scaling_factor <= 3.0
    error_message = "Exam period scaling factor must be between 1.0 and 3.0."
  }
}

# Regional service providers (educational communication)
variable "payment_providers" {
  description = "Payment providers for school fees (region-specific)"
  type        = list(string)
  default     = ["stripe"]
}

variable "sms_provider" {
  description = "SMS provider for school communications"
  type        = string
  default     = "twilio"
  validation {
    condition     = contains(["twilio", "africa_talking", "messagebird"], var.sms_provider)
    error_message = "SMS provider must be one of: twilio, africa_talking, messagebird."
  }
}

variable "email_provider" {
  description = "Email provider for school communications"
  type        = string
  default     = "sendgrid"
  validation {
    condition     = contains(["sendgrid", "mailgun", "ses"], var.email_provider)
    error_message = "Email provider must be one of: sendgrid, mailgun, ses."
  }
}

# Security and compliance
variable "school_onboarding_key" {
  description = "Secret key for automated school onboarding"
  type        = string
  sensitive   = true
}

# Monitoring and alerting
variable "error_rate_threshold" {
  description = "Error rate threshold for educational alerts"
  type        = number
  default     = 0.05  # 5%
}

variable "notification_channels" {
  description = "Notification channels for educational alerts"
  type        = list(string)
  default     = []
}

# Budget controls
variable "create_budget" {
  description = "Whether to create educational budget alerts"
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "Monthly budget for educational platform (USD)"
  type        = number
  default     = 100
}

variable "billing_account_id" {
  description = "Billing account ID for educational budget"
  type        = string
  default     = ""
}

variable "budget_pubsub_topic" {
  description = "Pub/Sub topic for educational budget alerts"
  type        = string
  default     = ""
}

# Multi-tenant configuration
variable "enable_school_isolation" {
  description = "Enable complete school data isolation"
  type        = bool
  default     = true
}

variable "enable_cross_school_parents" {
  description = "Enable cross-school parent functionality"
  type        = bool
  default     = true
}

variable "max_schools_per_district" {
  description = "Maximum schools per district"
  type        = number
  default     = 50
}

variable "enable_district_management" {
  description = "Enable district-level management features"
  type        = bool
  default     = false
}

# Performance optimization
variable "enable_educational_caching" {
  description = "Enable educational content caching"
  type        = bool
  default     = true
}

variable "cache_curriculum_content" {
  description = "Cache curriculum content globally"
  type        = bool
  default     = true
}

# Educational compliance features
variable "enable_ferpa_compliance" {
  description = "Enable FERPA compliance features (US)"
  type        = bool
  default     = false
}

variable "enable_gdpr_compliance" {
  description = "Enable GDPR compliance features (EU)"
  type        = bool
  default     = false
}

variable "student_data_retention_years" {
  description = "Student data retention period in years"
  type        = number
  default     = 7
  validation {
    condition     = var.student_data_retention_years >= 1 && var.student_data_retention_years <= 10
    error_message = "Student data retention must be between 1 and 10 years."
  }
}