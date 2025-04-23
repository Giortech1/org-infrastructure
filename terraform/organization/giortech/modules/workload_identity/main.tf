## modules/workload_identity/main.tf
# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github_pool" {
  count                     = var.create_identity_pool ? 1 : 0
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
  
  # This prevents errors if the resource already exists
  lifecycle {
    ignore_changes = [
      workload_identity_pool_id,
    ]
  }
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count                               = var.create_identity_pool ? 1 : 0
  project                             = var.project_id
  workload_identity_pool_id           = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id  = "github-provider"
  display_name                        = "GitHub Provider"
  
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  
  attribute_condition = "assertion.repository_owner == '${var.github_org}'"
  
  lifecycle {
    ignore_changes = [
      workload_identity_pool_provider_id,
    ]
  }
}

# Service Account
resource "google_service_account" "github_actions_sa" {
  count        = var.create_service_account ? 1 : 0
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
  
  lifecycle {
    ignore_changes = [
      account_id,
    ]
  }
}

# IAM Binding
resource "google_service_account_iam_binding" "workload_identity_binding" {
  count              = var.create_identity_pool && var.create_service_account ? 1 : 0
  service_account_id = google_service_account.github_actions_sa[0].name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "principalSet://iam.googleapis.com/projects/${var.project_id}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
  
  depends_on = [
    google_iam_workload_identity_pool.github_pool,
    google_service_account.github_actions_sa
  ]
}

# Role Bindings
resource "google_project_iam_binding" "cloud_run_admin" {
  count   = var.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/run.admin"
  
  members = [
    "serviceAccount:${google_service_account.github_actions_sa[0].email}"
  ]
}

resource "google_project_iam_binding" "storage_admin" {
  count   = var.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/storage.admin"
  
  members = [
    "serviceAccount:${google_service_account.github_actions_sa[0].email}"
  ]
}

resource "google_project_iam_binding" "service_account_user" {
  count   = var.create_service_account ? 1 : 0
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  
  members = [
    "serviceAccount:${google_service_account.github_actions_sa[0].email}"
  ]
}
