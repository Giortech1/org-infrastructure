terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "giortech/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs first
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "billingbudgets.googleapis.com",
    "certificatemanager.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  disable_on_destroy = false
}

# Random suffix for bucket name to avoid conflicts
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Storage bucket for basic infrastructure with unique name
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-bucket-${random_id.bucket_suffix.hex}"
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
  
  depends_on = [google_project_service.required_apis]
}

# Outputs
output "project_id" {
  value       = var.project_id
  description = "The GCP project ID"
}

output "bucket_name" {
  value       = google_storage_bucket.storage.name
  description = "Storage bucket name"
}