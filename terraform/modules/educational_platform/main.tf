terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Use existing Firestore database (don't create)
#data "google_firestore_database" "existing" {
#  project  = var.project_id
#  database = "(default)"
#}

# Educational content storage
resource "google_storage_bucket" "educational_content" {
  name          = "${var.project_id}-educational-content"
  project       = var.project_id
  location      = "US"
  force_destroy = var.environment != "prod"
  
  uniform_bucket_level_access = true
}

# Educational platform configuration secret
resource "google_secret_manager_secret" "educational_config" {
  secret_id = "educational-platform-config"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "educational_config_version" {
  secret = google_secret_manager_secret.educational_config.id
  secret_data = jsonencode({
    platform            = "academyaxis-educational"
    region              = var.educational_region
    supported_languages = var.supported_languages
    grading_system     = var.grading_system
    features = {
      multi_tenant         = true
      school_isolation    = true
      cross_school_parents = true
    }
  })
}