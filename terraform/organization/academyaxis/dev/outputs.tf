# Outputs (your existing outputs + educational outputs)
output "project_id" {
  value       = var.project_id
  description = "The GCP project ID"
}

output "bucket_name" {
  value       = google_storage_bucket.storage.name
  description = "Storage bucket name"
}

# Educational Platform Outputs (from module)
output "educational_content_bucket" {
  value       = module.educational_platform.educational_content_bucket
  description = "Educational content bucket name"
}

output "educational_config_secret" {
  value       = module.educational_platform.educational_config_secret
  description = "Educational configuration secret name"
}