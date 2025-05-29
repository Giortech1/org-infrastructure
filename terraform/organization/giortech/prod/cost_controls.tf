# Configure cost controls for giortech production environment
module "giortech_prod_cost_controls" {
  source = "../../../modules/cost_controls"
  
  project_id          = "giortech-prod-project"
  application         = "giortech"
  environment         = "prod"
  region              = "us-central1"
  billing_account_id  = "0141E4-398D5E-91A063"
  budget_amount       = 100  # $100 monthly budget for production environment
  alert_email_address = "devops@academyaxis.io"
  create_budget       = false # Budget already exists, don't recreate
}

# Output the dashboard URLs for easy access
output "cost_control_dashboards" {
  value = module.giortech_prod_cost_controls.dashboards
}

# Create a README with cost control best practices
resource "local_file" "cost_control_readme" {
  content  = <<-EOF
# Cost Control Best Practices for ${upper("giortech-prod")}

## Monthly Budget: $100 USD

This production environment is configured with cost controls to ensure we stay within our organization's monthly budget. Total monthly budget for all environments should not exceed $300 USD.

## Key Cost Control Measures

1. **Minimum 1 instance** for consistent availability
2. **Standard log retention** (30 days)
3. **Log filtering** to exclude health checks
4. **Production-grade monitoring** and alerting

## Monitoring Dashboards

Access the cost monitoring dashboards at:
${module.giortech_prod_cost_controls.dashboards.cost_dashboard}

## Alert Notifications

Budget alerts are sent to: ${module.giortech_prod_cost_controls.notification_channel}

## Production Cost Optimization Strategies

1. Implement CDN for static content caching
2. Optimize database queries and indexes
3. Use efficient scaling policies (min 1 instance, max 20)
4. Monitor and adjust resource allocation based on traffic patterns
5. Regular performance and cost reviews

## Tracking Expensive Operations

The following metric tracks expensive operations:
`${module.giortech_prod_cost_controls.log_metric_name}`

To mark an operation as expensive, include the following in your logs:
```
expensive-operation: operation_type
```

## Production-Specific Considerations

- **Always-on availability**: Minimum 1 Cloud Run instance
- **Enhanced monitoring**: Comprehensive dashboards and alerting
- **Data retention**: 30-day log retention for compliance
- **Backup strategy**: Versioned storage with lifecycle management
  EOF
  filename = "../../../docs/giortech-prod-cost-controls.md"
}