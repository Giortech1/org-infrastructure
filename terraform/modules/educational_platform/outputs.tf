terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.5"
    }
  }
}
# terraform/modules/educational_platform/outputs.tf
# Educational Platform Module Outputs

output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = google_firestore_database.educational_database.name
}

output "educational_content_bucket" {
  description = "Name of the educational content bucket"
  value       = google_storage_bucket.educational_content.name
}

output "educational_audit_bucket" {
  description = "Name of the educational audit logs bucket"
  value       = google_storage_bucket.educational_audit_logs.name
}

output "educational_config_secret" {
  description = "Name of the educational configuration secret"
  value       = google_secret_manager_secret.educational_config.secret_id
}

output "school_onboarding_secret" {
  description = "Name of the school onboarding secret"
  value       = google_secret_manager_secret.school_onboarding_key.secret_id
}

output "educational_dashboard_id" {
  description = "ID of the educational monitoring dashboard"
  value       = google_monitoring_dashboard.educational_dashboard.id
}

output "educational_budget_name" {
  description = "Name of the educational budget"
  value       = var.create_budget ? google_billing_budget.educational_budget[0].display_name : null
}
