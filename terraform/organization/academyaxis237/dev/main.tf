terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "academyaxis237/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Workload Identity for GitHub Actions
module "workload_identity" {
  source = "../../../modules/workload_identity"
  
  project_id             = var.project_id
  github_org             = "giortech1"
  github_repo            = "org-infrastructure"
  create_identity_pool   = var.create_identity_pool
  create_service_account = var.create_service_account
}

# Cost controls and monitoring
module "cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id          = var.project_id
  application         = "academyaxis237"
  environment         = var.environment
  region              = var.region
  billing_account_id  = var.billing_account_id
  budget_amount       = var.budget_amount
  alert_email_address = var.alert_email_address
  create_budget       = var.create_budget
}

# Basic storage bucket for testing
resource "google_storage_bucket" "storage" {
  name          = "${var.project_id}-bucket"
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true
}
