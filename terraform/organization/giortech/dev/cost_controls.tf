# Configure cost controls for giortech development environment
module "cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id         = "giortech-dev-project"
  application        = "giortech"
  environment        = "dev"
  region             = "us-central1"
  billing_account_id = "0141E4-398D5E-91A063"
  budget_amount      = 50
  alert_email_address = "devops@academyaxis.io"
  create_budget      = false  # Disabled due to auth issues
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value = module.cost_controls.dashboards
  description = "URLs to access cost control dashboards"
}