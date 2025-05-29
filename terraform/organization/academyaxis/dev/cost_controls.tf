# Configure cost controls for academyaxis development environment
module "cost_controls" {
  source = "../../../modules/cost_controls"

  project_id          = "academyaxis-dev-project"
  application         = "academyaxis"
  environment         = "dev"
  region              = "us-central1"
  billing_account_id  = "01CCAF-9AB761-C3B593" # AcademyAxis billing account
  budget_amount       = 25                     # $25 monthly budget for dev environment
  alert_email_address = "devops@academyaxis.io"
  create_budget       = false # Disabled due to auth issues, enable after setup
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value       = module.cost_controls.dashboards
  description = "URLs to access cost control dashboards"
}