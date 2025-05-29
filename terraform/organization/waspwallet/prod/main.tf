terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "waspwallet/prod"
  }
}

provider "google" {
  project = "waspwallet-prod-project"
  region  = "us-central1"
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
  
  project = "waspwallet-prod-project"
  service = each.value
  disable_on_destroy = false
}

# Storage bucket for basic infrastructure
resource "google_storage_bucket" "storage" {
  name          = "waspwallet-prod-project-bucket"
  location      = "us-central1"
  force_destroy = false  # Production should not auto-delete
  uniform_bucket_level_access = true
  
  # Production-specific lifecycle rules
  lifecycle_rule {
    condition {
      age = 365  # Keep for 1 year
    }
    action {
      type = "Delete"
    }
  }
  
  # Production versioning
  versioning {
    enabled = true
  }
  
  depends_on = [google_project_service.required_apis]
}

# Outputs
output "project_id" {
  value       = "waspwallet-prod-project"
  description = "The GCP project ID"
}

output "bucket_name" {
  value       = google_storage_bucket.storage.name
  description = "Storage bucket name"
}