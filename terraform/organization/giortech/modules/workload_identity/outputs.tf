# modules/workload_identity/outputs.tf

output "workload_identity_provider" {
  value = var.create_identity_pool ? (
    "projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id}/providers/${google_iam_workload_identity_pool_provider.github_provider[0].workload_identity_pool_provider_id}"
  ) : (
    "projects/${var.project_id}/locations/global/workloadIdentityPools/${var.pool_id}/providers/${var.provider_id}"
  )
  description = "Workload Identity Provider resource name"
}

output "service_account_email" {
  value = var.create_service_account ? (
    google_service_account.github_actions_sa[0].email
  ) : (
    "${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
  )
  description = "Service account email"
}

# Outputs
#output "workload_identity_provider" {
#  value = var.create_identity_pool ? "projects/${var.project_id}/locations/global/workloadIdentityPools/github-pool/providers/github-provider" : "Not created"
#}

#output "service_account_email" {
#  value = var.create_service_account ? google_service_account.github_actions_sa[0].email : "Not created"
#}