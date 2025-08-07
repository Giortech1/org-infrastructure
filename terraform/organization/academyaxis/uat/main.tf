terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
  backend "gcs" {
    bucket = "academyaxis-terraform-state"
    prefix = "academyaxis/uat"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Network Infrastructure Module
module "network_infrastructure" {
  source = "../../../modules/network_infrastructure"
  
  project_id            = var.project_id
  region                = var.region
  environment           = "uat"
  application           = "academyaxis"
  domain                = "academyaxis.io"
  enable_cdn            = false
  enable_cloud_armor    = false
  cloud_run_service_name = "academyaxis-uat"
  enable_monitoring      = true
  skip_neg               = true
  
  alert_email_address    = "alerts@giortech.com"
  create_budget_alert    = false  # DISABLED FOR UAT
  budget_amount          = 15
  billing_account_id     = ""     # EMPTY FOR UAT
}

# Educational Platform Module
module "educational_platform" {
  source = "../../../modules/educational_platform"
  
  project_id              = var.project_id
  region                  = var.region
  environment             = "uat"
  educational_region      = "global"
  
  # Educational configuration
  supported_languages     = ["en-US", "fr-FR"]
  grading_system         = "flexible"
  payment_providers      = ["stripe"]
  sms_provider           = "twilio"
  
  # Multi-tenant configuration
  enable_school_isolation      = true
  enable_cross_school_parents  = true
  max_schools_per_district     = 50
  
  # Budget controls - DISABLED FOR UAT
  create_budget          = false
  budget_amount          = 30
  billing_account_id     = ""
  notification_channels  = []
  
  school_onboarding_key  = "uat-educational-key-2024"
  
  depends_on = [module.network_infrastructure]
}