terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state" 
    prefix = "giortech"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable necessary APIs
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "dns.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# Cloud Run service
resource "google_cloud_run_service" "giortech_service" {
  name     = "giortech-${var.environment}"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/giortech:latest"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }
        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [google_project_service.services]
}

# Allow public access to the service
resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_service.giortech_service.location
  service  = google_cloud_run_service.giortech_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Storage bucket for static assets
resource "google_storage_bucket" "static_assets" {
  name          = "giortech-${var.environment}-static"
  location      = var.region
  force_destroy = var.environment != "prod"

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Budget alert
resource "google_billing_budget" "project_budget" {
  billing_account = var.billing_account_id
  display_name    = "giortech-${var.environment}-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.75
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}

# Outputs
output "service_url" {
  value = google_cloud_run_service.giortech_service.status[0].url
}

output "bucket_name" {
  value = google_storage_bucket.static_assets.name
}

