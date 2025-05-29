# Configure cost controls for waspwallet UAT environment
module "waspwallet_uat_cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id          = "waspwallet-uat-project"
  application         = "waspwallet"
  environment         = "uat"
  region              = "us-central1"
  billing_account_id  = "013EC4-560F65-79B652"  # WaspWallet billing account
  budget_amount       = 25  # $25 monthly budget for UAT environment
  alert_email_address = "devops@academyaxis.io"
  create_budget       = true  # Enable budget creation
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value = module.waspwallet_uat_cost_controls.dashboards
}

# Create a README with cost control best practices
resource "local_file" "cost_control_readme" {
  content  = <<-EOF
# Cost Control Best Practices for ${upper("waspwallet-uat")}

## Monthly Budget: $25 USD

This environment is configured with cost controls to ensure we stay within our organization's monthly budget. Total monthly budget for all environments should not exceed $300 USD.

## Key Cost Control Measures

1. **Auto-scaling to zero** when not in use
2. **Limited log retention** (7 days for cost optimization)
3. **Log filtering** to exclude health checks and debug logs
4. **Mobile app optimization** - efficient resource usage

## Monitoring Dashboards

Access the cost monitoring dashboards at:
${module.waspwallet_uat_cost_controls.dashboards.cost_dashboard}

## Alert Notifications

Budget alerts are sent to: ${module.waspwallet_uat_cost_controls.notification_channel}

## Mobile App Specific Optimizations

1. Optimize API calls frequency
2. Implement efficient caching for mobile data
3. Use minimal Cloud Run instances for backend services
4. Optimize image and asset storage

## Tracking Expensive Operations

The following metric tracks expensive operations:
`${module.waspwallet_uat_cost_controls.log_metric_name}`

To mark an operation as expensive, include the following in your logs:
```
expensive-operation: operation_type
```
  EOF
  filename = "../../../docs/waspwallet-uat-cost-controls.md"
}