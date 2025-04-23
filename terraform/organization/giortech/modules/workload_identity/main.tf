# modules/workload_identity/main.tf

# Enable necessary APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com"
  ])
  project = var.project_id
  service = each.key
  
  disable_on_destroy = false
}

# Create the Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  count = var.create_identity_pool ? 1 : 0
  
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
  
  depends_on = [google_project_service.required_apis]
}

# Create the Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count = var.create_identity_pool ? 1 : 0
  
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Provider"
  description                        = "OIDC identity pool provider for GitHub Actions"
  
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "assertion.repository_owner == \"${var.github_org}\" && assertion.repository == \"${var.github_org}/${var.github_repo}\""
}

# Create the Service Account
resource "google_service_account" "github_actions_sa" {
  count = var.create_service_account ? 1 : 0
  
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "GitHub Actions Service Account"
  description  = "Service account used by GitHub Actions workflows"
}

# Assign roles to the Service Account
resource "google_project_iam_member" "service_account_roles" {
  for_each = var.create_service_account ? toset(var.service_account_roles) : toset([])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions_sa[0].email}"
}

# Allow Service Account to be impersonated by GitHub Actions
resource "google_service_account_iam_binding" "workload_identity_binding" {
  count = var.create_service_account && var.create_identity_pool ? 1 : 0
  
  service_account_id = google_service_account.github_actions_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "principalSet://iam.googleapis.com/projects/${var.project_id}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id}/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}