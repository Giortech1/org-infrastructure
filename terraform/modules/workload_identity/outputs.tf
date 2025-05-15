output "workload_identity_provider" {
<<<<<<< HEAD
  value       = "projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
=======
  value       = var.create_identity_pool ? "projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-pool/providers/github-provider" : ""
>>>>>>> 9b078fa0caa1de363db7cd29524e2ddb28b8afb4
  description = "Workload Identity Provider resource name for GitHub Actions"
}

output "service_account_email" {
<<<<<<< HEAD
  value       = var.create_service_account ? google_service_account.github_actions_sa[0].email : "github-actions-sa@${var.project_id}.iam.gserviceaccount.com"
  description = "Service Account email for GitHub Actions"
}
=======
  value       = var.create_service_account ? google_service_account.github_actions_sa[0].email : ""
  description = "Service Account email for GitHub Actions"
}
>>>>>>> 9b078fa0caa1de363db7cd29524e2ddb28b8afb4
