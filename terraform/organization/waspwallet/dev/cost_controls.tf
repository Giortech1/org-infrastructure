# Configure cost controls for waspwallet development environment
module "cost_controls" {
  source = "../../../modules/cost_controls"

  project_id          = "waspwallet-dev-project"
  application         = "waspwallet"
  environment         = "dev"
  region              = "us-central1"
  billing_account_id  = "013EC4-560F65-79B652" # WaspWallet billing account
  budget_amount       = 25                     # $25 monthly budget for dev environment
  alert_email_address = "devops@academyaxis.io"
  create_budget       = false # Disabled due to auth issues, enable after setup
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value       = module.cost_controls.dashboards
  description = "URLs to access cost control dashboards"
}