# terraform/modules/network_infrastructure/variables.tf
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
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
  validation {
    condition     = contains(["giortech", "waspwallet", "academyaxis"], var.application)
    error_message = "Application must be one of: giortech, waspwallet, academyaxis."
  }
}

variable "domain" {
  description = "The domain name"
  type        = string
  default     = "academyaxis.io"
}

variable "enable_cdn" {
  description = "Whether to enable Cloud CDN for static content caching"
  type        = bool
  default     = false
}

variable "enable_cloud_armor" {
  description = "Whether to enable Cloud Armor for WAF protection"
  type        = bool
  default     = false
}

variable "cdn_cache_ttl" {
  description = "TTL for CDN cache in seconds"
  type        = number
  default     = 3600
}

variable "dns_ttl" {
  description = "TTL for DNS records in seconds"
  type        = number
  default     = 300
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name to connect to the load balancer"
  type        = string
}

variable "enable_monitoring" {
  description = "Whether to enable Cloud Monitoring"
  type        = bool
  default     = true
}

variable "skip_neg" {
  description = "Whether to skip creating the NEG (useful if Cloud Run service doesn't exist yet)"
  type        = bool
  default     = false
}

# Monitoring and cost control variables
variable "alert_email_address" {
  description = "Email address for alert notifications"
  type        = string
  default     = "alerts@giortech.com"
}

variable "create_budget_alert" {
  description = "Whether to create budget alert policies"
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

variable "billing_account_id" {
  description = "Billing account ID"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = var.environment == "prod" ? 30 : (var.environment == "uat" ? 14 : 7)
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable more detailed monitoring metrics"
  type        = bool
  default     = var.environment == "prod"
}

variable "http_latency_threshold" {
  description = "Threshold for HTTP latency alerts in milliseconds"
  type        = number
  default     = 2000  # 2 seconds
}

variable "error_rate_threshold" {
  description = "Threshold for error rate alerts (as a decimal)"
  type        = number
  default     = 0.05  # 5%
}