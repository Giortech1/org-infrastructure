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