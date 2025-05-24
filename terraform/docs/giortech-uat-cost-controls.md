# Cost Control Best Practices for GIORTECH-UAT

## Monthly Budget: $50 USD

This environment is configured with cost controls to ensure we stay within our organization's monthly budget. Total monthly budget for all environments should not exceed $300 USD.

## Key Cost Control Measures

1. **Auto-scaling to zero** when not in use
2. **Limited log retention** (14 days)
3. **Log filtering** to exclude health checks and debug logs

## Monitoring Dashboards

Access the cost monitoring dashboards at:
https://console.cloud.google.com/monitoring/dashboards/custom/projects/28962750525/dashboards/c5e5f27e-b113-42bd-b163-7b019b6128ac?project=giortech-uat-project

## Alert Notifications

Budget alerts are sent to: projects/giortech-uat-project/notificationChannels/16375270045541827752

## How to Optimize Costs

1. Delete unused resources (storage buckets, unused services)
2. Scale down resources during non-business hours
3. Implement efficient caching
4. Optimize logging and monitoring

## Tracking Expensive Operations

The following metric tracks expensive operations:
`giortech-uat-project-expensive-operations`

To mark an operation as expensive, include the following in your logs:
```
expensive-operation: operation_type
```
