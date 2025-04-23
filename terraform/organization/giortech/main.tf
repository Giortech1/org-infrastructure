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
    "billingbudgets.googleapis.com", # Added Billing Budgets API
  ])
  service            = each.value
  disable_on_destroy = false
}

# Workload Identity configuration
module "workload_identity" {
  source = "./modules/workload_identity"

  project_id  = var.project_id
  github_org  = "giortech1"
  github_repo = "org-infrastructure"

  # Pass the variables for conditional creation
  create_identity_pool   = var.create_identity_pool
  create_service_account = var.create_service_account

  # This will make it depend on the APIs being enabled
  depends_on = [google_project_service.services]
}

# Cloud Run service with placeholder image
resource "google_cloud_run_service" "giortech_service" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = "giortech-${var.environment}"
  location = var.region

  template {
    spec {
      containers {
        # Use a publicly available placeholder image
        image = var.container_image
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
resource "google_cloud_run_service_iam_member" "service_access" {
  count    = var.deploy_cloud_run ? 1 : 0
  location = google_cloud_run_service.giortech_service[0].location
  service  = google_cloud_run_service.giortech_service[0].name
  role     = "roles/run.invoker"
  
  # Use the service account instead of allUsers
  member   = "serviceAccount:${module.workload_identity.service_account_email}"
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

# Budget alert with conditional creation
resource "google_billing_budget" "project_budget" {
  count           = var.create_budget ? 1 : 0
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

  depends_on = [google_project_service.services]
}

# Outputs
output "service_url" {
  value = var.deploy_cloud_run ? google_cloud_run_service.giortech_service[0].status[0].url : "No Cloud Run service deployed"
}

output "bucket_name" {
  value = google_storage_bucket.static_assets.name
}

output "workload_identity_provider" {
  value       = module.workload_identity.workload_identity_provider
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "service_account_email" {
  value       = module.workload_identity.service_account_email
  description = "Service Account email for GitHub Actions"
}