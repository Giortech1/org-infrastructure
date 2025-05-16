# Create Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  count = var.create_identity_pool ? 1 : 0
  
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
  project                   = var.project_id
}

# Create Workload Identity Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count = var.create_identity_pool ? 1 : 0
  
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  project                            = var.project_id
  
  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.actor"        = "assertion.actor"
    "attribute.repository"   = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_org}'"
}

# Create Service Account for GitHub Actions
resource "google_service_account" "github_actions_sa" {
  count = var.create_service_account ? 1 : 0
  
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
  project      = var.project_id
  description  = "Service account for GitHub Actions"
}

# Allow GitHub Actions to use this Service Account
resource "google_service_account_iam_binding" "workload_identity_binding" {
  count = var.create_service_account && var.create_identity_pool ? 1 : 0
  
  service_account_id = google_service_account.github_actions_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "principalSet://iam.googleapis.com/projects/${data.google_project.project.number}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}

# Data source to get project number
data "google_project" "project" {
  project_id = var.project_id
}