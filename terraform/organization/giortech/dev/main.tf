# Dev environment configuration
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Include the parent module
module "giortech" {
  source = "../"
  
  # Pass the variables specific to dev environment
  project_id         = "giortech-dev-project"
  environment        = "dev"
  region             = "us-central1"
  billing_account_id = "0141E4-398D5E-91A063"
  budget_amount      = 50
  
  # Additional variables to handle existing resources
  create_identity_pool = false
  create_service_account = false
  deploy_cloud_run = false
  create_budget = false
}

# Output the Workload Identity Provider and Service Account
output "workload_identity_provider" {
  value       = module.giortech_dev.workload_identity_provider
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "service_account_email" {
  value       = module.giortech_dev.service_account_email
  description = "Service Account email for GitHub Actions"
}