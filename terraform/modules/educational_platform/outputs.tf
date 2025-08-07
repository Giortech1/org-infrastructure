#output "firestore_database_name" {
#  description = "Name of the existing Firestore database"
#  value       = data.google_firestore_database.existing.name
#}

output "educational_content_bucket" {
  description = "Name of the educational content bucket"
  value       = google_storage_bucket.educational_content.name
}

output "educational_config_secret" {
  description = "Name of the educational configuration secret"
  value       = google_secret_manager_secret.educational_config.secret_id
}