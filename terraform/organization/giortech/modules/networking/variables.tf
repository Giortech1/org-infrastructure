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
}

variable "domain_name" {
  description = "The domain name for the service"
  type        = string
  default     = ""
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  type        = string
}