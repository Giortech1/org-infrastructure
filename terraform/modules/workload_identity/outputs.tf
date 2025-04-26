output "workload_identity_provider" {
  value       = "projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "service_account_email" {
  value       = var.create_service_account ? google_service_account.github_actions_sa[0].email : "github-actions-sa@${var.project_id}.iam.gserviceaccount.com"
  description = "Service Account email for GitHub Actions"
}