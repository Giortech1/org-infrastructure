# terraform/organization/academyaxis/prod/main.tf
# Corrected to use proper workload_identity module variables

# All your existing variables (unchanged)
variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
}

variable "billing_account_id" {
  description = "The GCP billing account ID"
  type        = string
}

variable "budget_amount" {
  description = "Budget amount in USD for this environment"
  type        = number
}

variable "create_identity_pool" {
  description = "Whether to create the workload identity pool"
  type        = bool
  default     = true
}

variable "create_service_account" {
  description = "Whether to create the service account"
  type        = bool
  default     = true
}

variable "deploy_cloud_run" {
  description = "Whether to deploy Cloud Run service"
  type        = bool
  default     = true
}

variable "create_budget" {
  description = "Whether to create budget"
  type        = bool
  default     = true
}

variable "container_image" {
  description = "The container image to use for Cloud Run"
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
}

# NEW: Educational Platform Variables (with conservative defaults)
variable "enable_educational_platform" {
  description = "Whether to enable the educational platform features"
  type        = bool
  default     = false
}

variable "educational_region" {
  description = "Educational region for compliance and customization"
  type        = string
  default     = "global"
}

variable "educational_budget_amount" {
  description = "Budget allocation for educational platform (subset of total budget)"
  type        = number
  default     = 35
}

# Granular educational platform controls
variable "educational_create_firestore" {
  description = "Whether to create educational Firestore database"
  type        = bool
  default     = false
}

variable "educational_create_storage" {
  description = "Whether to create educational storage buckets"
  type        = bool
  default     = false
}

variable "educational_create_secrets" {
  description = "Whether to create educational secrets"
  type        = bool
  default     = false
}

variable "educational_create_monitoring" {
  description = "Whether to create educational monitoring"
  type        = bool
  default     = false
}

variable "educational_create_scheduler" {
  description = "Whether to create educational schedulers"
  type        = bool
  default     = false
}

# Terraform configuration - Fixed to match your existing modules
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "academyaxis/prod"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs only when educational platform is enabled
resource "google_project_service" "educational_apis" {
  for_each = var.enable_educational_platform ? toset([
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "scheduler.googleapis.com"
  ]) : toset([])
  
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# FIXED: Your existing workload_identity module with correct variables
module "workload_identity" {
  count = var.create_identity_pool || var.create_service_account ? 1 : 0
  source = "../../../modules/workload_identity"
  
  project_id             = var.project_id
  github_org            = "Giortech1"                    # FIXED: Use github_org instead of github_repository
  github_repo           = "academyaxis-app"             # FIXED: Use github_repo instead of service_account_id
  create_identity_pool  = var.create_identity_pool
  create_service_account = var.create_service_account
}

# FIXED: Updated module references to match your existing structure
module "network_infrastructure" {
  count = var.deploy_cloud_run ? 1 : 0
  source = "../../../modules/network_infrastructure"
  
  project_id                = var.project_id
  region                   = var.region
  environment              = var.environment
  application              = "academyaxis"
  domain                   = "academyaxis.io"
  enable_cdn               = true
  enable_cloud_armor       = true
  cloud_run_service_name   = "academyaxis-prod"
  enable_monitoring        = true
  billing_account_id       = var.billing_account_id
  budget_amount            = var.budget_amount - var.educational_budget_amount
  alert_email_address      = "alerts@giortech.com"
  skip_neg                 = !var.deploy_cloud_run
}

module "cost_controls" {
  count = var.create_budget ? 1 : 0
  source = "../../../modules/cost_controls"
  
  project_id         = var.project_id
  application        = "academyaxis"
  environment        = var.environment
  billing_account_id = var.billing_account_id
  budget_amount      = var.budget_amount - var.educational_budget_amount
  
  alert_email_address = "alerts@giortech.com"
  create_budget      = var.create_budget
}

# Educational Firestore (separate resource for granular control)
resource "google_firestore_database" "educational_database" {
  count                           = var.educational_create_firestore && var.enable_educational_platform ? 1 : 0
  project                         = var.project_id
  name                           = "(default)"
  location_id                    = "us-central"
  type                           = "FIRESTORE_NATIVE"
  concurrency_mode               = "OPTIMISTIC"
  app_engine_integration_mode    = "DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_ENABLED"
  delete_protection_state        = "DELETE_PROTECTION_ENABLED"

  depends_on = [google_project_service.educational_apis]
}

# Educational Storage (separate resources for granular control)
resource "google_storage_bucket" "educational_content" {
  count                       = var.educational_create_storage && var.enable_educational_platform ? 1 : 0
  name                        = "${var.project_id}-educational-content"
  location                    = var.region
  force_destroy              = false  # Production safety
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 2555  # 7 years for educational records
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true  # Enable versioning in production
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_storage_bucket" "educational_audit_logs" {
  count                       = var.educational_create_storage && var.enable_educational_platform ? 1 : 0
  name                        = "${var.project_id}-educational-audit-logs"
  location                    = var.region
  force_destroy              = false
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 2555  # 7 years minimum for educational compliance
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.educational_apis]
}

# Educational Secrets (separate resources for granular control)
resource "google_secret_manager_secret" "educational_config" {
  count     = var.educational_create_secrets && var.enable_educational_platform ? 1 : 0
  secret_id = "educational-platform-config"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_secret_manager_secret_version" "educational_config_version" {
  count   = var.educational_create_secrets && var.enable_educational_platform ? 1 : 0
  secret  = google_secret_manager_secret.educational_config[0].id
  secret_data = jsonencode({
    region                    = var.educational_region
    supported_languages       = var.educational_region == "cameroon" ? ["fr-CM", "en-CM"] : ["en-US", "fr-FR", "es-ES"]
    default_language         = var.educational_region == "cameroon" ? "fr-CM" : "en-US"
    grading_system           = var.educational_region == "cameroon" ? "20_point" : "flexible"
    payment_providers        = var.educational_region == "cameroon" ? ["orange_money", "mtn_momo"] : ["stripe", "paypal"]
    sms_provider            = var.educational_region == "cameroon" ? "africa_talking" : "twilio"
    email_provider          = "sendgrid"
    academic_year_start      = 9
    school_hours_start       = 8
    school_hours_end         = 16
    holiday_scaling_factor   = 0.1
    exam_period_scaling_factor = 1.5
  })
}

resource "google_secret_manager_secret" "school_onboarding_key" {
  count     = var.educational_create_secrets && var.enable_educational_platform ? 1 : 0
  secret_id = "school-onboarding-key"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_secret_manager_secret_version" "school_onboarding_key_version" {
  count       = var.educational_create_secrets && var.enable_educational_platform ? 1 : 0
  secret      = google_secret_manager_secret.school_onboarding_key[0].id
  secret_data = "prod-educational-key-2024-secure-${random_id.onboarding_key_suffix[0].hex}"
}

resource "random_id" "onboarding_key_suffix" {
  count       = var.educational_create_secrets && var.enable_educational_platform ? 1 : 0
  byte_length = 16
}

# Educational Monitoring (separate resource for granular control)
resource "google_monitoring_dashboard" "educational_dashboard" {
  count          = var.educational_create_monitoring && var.enable_educational_platform ? 1 : 0
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "AcademyAxis Educational Platform - Production"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Active Schools"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"firestore_database\" AND metric.type=\"firestore.googleapis.com/document/read_count\""
                  aggregation = {
                    alignmentPeriod  = "300s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
            }
          }
        }
      ]
    }
  })
}

# Educational Budget (separate resource for granular control)
resource "google_billing_budget" "educational_budget" {
  count           = var.create_budget && var.enable_educational_platform ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "AcademyAxis Educational Platform - Production"

  budget_filter {
    projects = ["projects/${var.project_id}"]
    
    services = [
      "services/firestore.googleapis.com",
      "services/storage.googleapis.com",
      "services/secretmanager.googleapis.com"
    ]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.educational_budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.75
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}

# Cloud Run service (your existing logic - ONLY created when deploy_cloud_run = true)
resource "google_cloud_run_service" "academyaxis_app" {
  count    = var.deploy_cloud_run ? 1 : 0
  name     = "academyaxis-prod"
  location = var.region
  project  = var.project_id

  template {
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"      = "1"
        "autoscaling.knative.dev/maxScale"      = "20"
        "run.googleapis.com/execution-environment" = "gen2"
        "run.googleapis.com/cpu-throttling"     = "false"
        
        # Educational platform annotations (only when enabled)
        "academyaxis.io/educational-platform"   = var.enable_educational_platform ? "enabled" : "disabled"
        "academyaxis.io/educational-region"     = var.educational_region
      }
    }

    spec {
      containers {
        image = var.container_image
        
        resources {
          limits = {
            cpu    = "2"
            memory = "1Gi"
          }
        }

        env {
          name  = "ENVIRONMENT"
          value = var.environment
        }
        
        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }
        
        # Educational platform environment variables (conditional)
        dynamic "env" {
          for_each = var.enable_educational_platform ? [1] : []
          content {
            name  = "EDUCATIONAL_PLATFORM"
            value = "true"
          }
        }
        
        dynamic "env" {
          for_each = var.enable_educational_platform ? [1] : []
          content {
            name  = "EDUCATIONAL_REGION"
            value = var.educational_region
          }
        }
        
        dynamic "env" {
          for_each = var.enable_educational_platform && var.educational_region == "cameroon" ? [1] : []
          content {
            name  = "GRADING_SYSTEM"
            value = "20_point"
          }
        }

        ports {
          container_port = 8080
        }
      }
      
      # FIXED: Only set service account when it exists
      service_account_name = var.create_service_account && length(module.workload_identity) > 0 ? module.workload_identity[0].service_account_email : null
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.educational_apis
  ]
}

# Cloud Run IAM (only when Cloud Run is deployed)
resource "google_cloud_run_service_iam_member" "public_access" {
  count    = var.deploy_cloud_run ? 1 : 0
  location = google_cloud_run_service.academyaxis_app[0].location
  project  = google_cloud_run_service.academyaxis_app[0].project
  service  = google_cloud_run_service.academyaxis_app[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Data sources
data "google_project" "project" {
  project_id = var.project_id
}

# Outputs - Fixed conditional logic
output "workload_identity_provider" {
  description = "The workload identity provider"
  value       = var.create_identity_pool && length(module.workload_identity) > 0 ? module.workload_identity[0].workload_identity_provider : "Not created (create_identity_pool = false)"
  sensitive   = false
}

output "service_account_email" {
  description = "The service account email"
  value       = var.create_service_account && length(module.workload_identity) > 0 ? module.workload_identity[0].service_account_email : "Not created (create_service_account = false)"
}

output "load_balancer_ip" {
  description = "The load balancer IP address"
  value       = var.deploy_cloud_run && length(module.network_infrastructure) > 0 ? module.network_infrastructure[0].load_balancer_ip : "Not created (deploy_cloud_run = false)"
}

output "cloud_run_url" {
  description = "The Cloud Run service URL"
  value       = var.deploy_cloud_run && length(google_cloud_run_service.academyaxis_app) > 0 ? google_cloud_run_service.academyaxis_app[0].status[0].url : "Not created (deploy_cloud_run = false)"
}

# Educational platform outputs (conditional)
output "educational_platform_status" {
  description = "Educational platform activation status"
  value = {
    enabled     = var.enable_educational_platform
    firestore   = var.educational_create_firestore && var.enable_educational_platform
    storage     = var.educational_create_storage && var.enable_educational_platform
    secrets     = var.educational_create_secrets && var.enable_educational_platform
    monitoring  = var.educational_create_monitoring && var.enable_educational_platform
    scheduler   = var.educational_create_scheduler && var.enable_educational_platform
    region      = var.educational_region
    budget      = var.educational_budget_amount
  }
}

output "educational_firestore_database" {
  description = "Educational Firestore database name"
  value       = var.educational_create_firestore && var.enable_educational_platform && length(google_firestore_database.educational_database) > 0 ? google_firestore_database.educational_database[0].name : "Not created"
}

output "educational_content_bucket" {
  description = "Educational content storage bucket"
  value       = var.educational_create_storage && var.enable_educational_platform && length(google_storage_bucket.educational_content) > 0 ? google_storage_bucket.educational_content[0].name : "Not created"
}

output "educational_secrets_created" {
  description = "Educational secrets creation status"
  value = {
    config_secret    = var.educational_create_secrets && var.enable_educational_platform && length(google_secret_manager_secret.educational_config) > 0 ? google_secret_manager_secret.educational_config[0].secret_id : "Not created"
    onboarding_secret = var.educational_create_secrets && var.enable_educational_platform && length(google_secret_manager_secret.school_onboarding_key) > 0 ? google_secret_manager_secret.school_onboarding_key[0].secret_id : "Not created"
  }
}