# Cost Control Best Practices for ACADEMYAXIS-UAT

## Monthly Budget: $25 USD

This environment is configured with cost controls to ensure we stay within our organization's monthly budget. Total monthly budget for all environments should not exceed $300 USD.

## Key Cost Control Measures

1. **Auto-scaling to zero** when not in use
2. **Limited log retention** (14 days for cost optimization)
3. **Log filtering** to exclude health checks and debug logs
4. **Mobile app and web platform optimization** - efficient resource usage

## Monitoring Dashboards

Access the cost monitoring dashboards at:
https://console.cloud.google.com/monitoring/dashboards/custom/projects/415071431590/dashboards/b64bb7c2-6e43-48b0-82d0-567255a10c07?project=academyaxis-uat-project

## Alert Notifications

Budget alerts are sent to: projects/academyaxis-uat-project/notificationChannels/7985875571254248292

## AcademyAxis Platform Specific Optimizations

1. Optimize API calls between mobile app and web platform
2. Implement efficient caching for educational content
3. Use minimal Cloud Run instances for backend services
4. Optimize media and educational resource storage
5. Implement smart content delivery for learning materials

## Tracking Expensive Operations

The following metric tracks expensive operations:
`academyaxis-uat-expensive-ops`

To mark an operation as expensive, include the following in your logs:
```
expensive-operation: operation_type
```

## UAT Testing Guidelines

1. Test with realistic data volumes but limited scope
2. Use compressed media files for testing
3. Implement test data cleanup after UAT cycles
4. Monitor resource usage during load testing
