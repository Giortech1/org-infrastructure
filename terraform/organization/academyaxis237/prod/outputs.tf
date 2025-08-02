output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "project_number" {
  description = "The GCP project number"
  value       = "684266177356"
}

output "workload_identity_provider" {
  description = "Workload Identity Provider"
  value       = module.workload_identity.workload_identity_provider
}

output "service_account_email" {
  description = "Service Account email"
  value       = module.workload_identity.service_account_email
}

output "budget_id" {
  description = "Budget ID"
  value       = module.cost_controls.budget_id
}

output "cost_dashboards" {
  description = "Cost monitoring dashboards"
  value       = module.cost_controls.dashboards
}

output "bucket_name" {
  description = "Storage bucket name"
  value       = google_storage_bucket.storage.name
}
