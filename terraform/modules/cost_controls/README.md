# Cost Controls Module for AcademyAxis.io

This module provides comprehensive cost controls, monitoring, and optimization for AcademyAxis.io applications on Google Cloud Platform. It works alongside the existing network_infrastructure module to ensure that your infrastructure stays within the monthly budget of $300 USD.

## Features

### Budget Controls

- **Monthly Budget**: Sets up a budget with alert thresholds at 50%, 75%, 90%, and 100% of the allocated amount.
- **Email Notifications**: Sends alerts when approaching budget limits.
- **Cost Dashboards**: Visual tracking of expenses and trends.

### Cost Optimization

- **Resource Scaling**: Environment-specific scaling configurations:
  - Dev/UAT: Scales to zero, lower max instances
  - Prod: Minimum 1 instance, higher max instances
- **Log Filtering**: Reduces log storage costs by filtering out health checks and debug logs
- **Operation Monitoring**: Tracks expensive operations to identify cost-saving opportunities

### Monitoring

- **Cost Trends**: Monitors spending patterns over time
- **Service Cost Breakdown**: Shows costs by service
- **Billable Resource Usage**: Tracks usage of billable resources

## Usage

```hcl
module "cost_controls" {
  source = "../../modules/cost_controls"
  
  project_id         = "your-project-id"
  application        = "giortech"  # giortech, waspwallet, or academyaxis
  environment        = "dev"       # dev, uat, or prod
  billing_account_id = "your-billing-account-id"
  budget_amount      = 50          # Budget in USD
  
  # Optional parameters
  alert_email_address = "your-email@example.com"
  create_budget       = true       # Set to false to skip budget creation
}
```

## Cost-Efficient Configuration by Environment

The module applies different configurations based on the environment to optimize costs:

### Development Environment

- Budget: 50 USD recommended
- Log retention: 7 days
- Min instances: 0 (scales to zero)
- Max instances: 10
- Debug logs: Excluded
- Health check logs: Excluded

### UAT Environment

- Budget: 50 USD recommended
- Log retention: 7 days
- Min instances: 0 (scales to zero)
- Max instances: 10
- Debug logs: Excluded
- Health check logs: Excluded

### Production Environment

- Budget: 100-150 USD recommended
- Log retention: 30 days
- Min instances: 1 (always running)
- Max instances: 100
- Debug logs: Included
- Health check logs: Excluded

## Integration with Network Infrastructure

This module complements the existing network_infrastructure module. To use both together:

```hcl
module "network_infrastructure" {
  source = "../../modules/network_infrastructure"
  
  # Network infrastructure parameters...
}

module "cost_controls" {
  source = "../../modules/cost_controls"
  
  project_id         = "your-project-id"
  application        = "giortech"
  environment        = "dev"
  billing_account_id = "your-billing-account-id"
  budget_amount      = 50
}
```

## Best Practices for Cost Control

1. **Start with Minimal Resources**: Begin with the minimum resources needed and scale up only when necessary.
2. **Use Development/UAT Sparingly**: Turn off or delete non-production environments when not in use.
3. **Monitor Dashboards Regularly**: Check the cost dashboards weekly to identify trends.
4. **Investigate Spikes**: If you receive budget alerts, investigate immediately.
5. **Log Parsing in Application**: Move log parsing logic to your application code to reduce Cloud Run instance time.
6. **Implement Cost Tags**: Use labels consistently to track costs by feature or team.

## Outputs

The module provides the following outputs:

- `budget_id`: ID of the created budget
- `dashboards`: URLs to access monitoring dashboards
- `notification_channel`: The notification channel for alerts
- `logging_bucket`: Name of the logging bucket
- `log_metric_name`: Name of the expensive operations log metric