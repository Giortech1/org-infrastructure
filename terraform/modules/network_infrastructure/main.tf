# terraform/modules/network_infrastructure/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

locals {
  service_name = "${var.application}-${var.environment}"
  domain       = var.domain
  full_domain  = var.environment == "prod" ? "${var.application}.${local.domain}" : "${var.environment}.${var.application}.${local.domain}"
}

# Enable required APIs
resource "google_project_service" "networking_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "dns.googleapis.com",
    "certificatemanager.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Check if Cloud Run service exists (optional - removed problematic data source)
# This data source was causing the error, so we'll make the NEG creation conditional instead