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
#resource "google_project_service" "networking_apis" {
#  for_each = toset([
#    "compute.googleapis.com",
#    "dns.googleapis.com",
#    "certificatemanager.googleapis.com",
#    "monitoring.googleapis.com"
#  ])
#  project            = var.project_id
#  service            = each.value
#  disable_on_destroy = false
#}

# Create a dependency check for Cloud Run service
data "google_cloud_run_service" "app_service" {
  name     = var.cloud_run_service_name
  location = var.region
  project  = var.project_id

  # This allows the module to continue even if the service doesn't exist yet
  depends_on = [google_project_service.networking_apis]
}