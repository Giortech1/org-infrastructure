# Configure cost controls for giortech UAT environment
module "cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id         = "giortech-uat-project"
  application        = "giortech"
  environment        = "uat"
  region             = "us-central1"
  billing_account_id = "0141E4-398D5E-91A063"
  budget_amount      = 50  # $50 monthly budget for UAT environment
  alert_email_address = "devops@academyaxis.io"
  create_budget = false  # Set to true if you want to create a budget
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value = module.cost_controls.dashboards
}

# Create a README with cost control best practices
resource "local_file" "cost_control_readme" {
  content  = <<-EOF
# Cost Control Best Practices for ${upper("giortech-uat")}

## Monthly Budget: $50 USD

This environment is configured with cost controls to ensure we stay within our organization's monthly budget. Total monthly budget for all environments should not exceed $300 USD.

## Key Cost Control Measures

1. **Auto-scaling to zero** when not in use
2. **Limited log retention** (14 days)
3. **Log filtering** to exclude health checks and debug logs

## Monitoring Dashboards

Access the cost monitoring dashboards at:
${module.cost_controls.dashboards.cost_dashboard}

## Alert Notifications

Budget alerts are sent to: ${module.cost_controls.notification_channel}

## How to Optimize Costs

1. Delete unused resources (storage buckets, unused services)
2. Scale down resources during non-business hours
3. Implement efficient caching
4. Optimize logging and monitoring

## Tracking Expensive Operations

The following metric tracks expensive operations:
`${module.cost_controls.log_metric_name}`

To mark an operation as expensive, include the following in your logs:
```
expensive-operation: operation_type
```
  EOF
  filename = "../../../docs/giortech-uat-cost-controls.md"
}