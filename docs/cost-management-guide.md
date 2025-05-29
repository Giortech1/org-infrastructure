# AcademyAxis.io Cost Management Guide

This guide provides comprehensive instructions for managing costs across all AcademyAxis.io applications on Google Cloud Platform. Our organization has a strict monthly budget limit of **$300 USD** that must not be exceeded.

## Budget Allocation

The budget is allocated across applications and environments as follows:

| Application  | Environment | Budget (USD) | Total (USD) |
|--------------|-------------|--------------|-------------|
| giortech     | Dev         | $50          | $200        |
| giortech     | UAT         | $50          |             |
| giortech     | Prod        | $100         |             |
| waspwallet   | Dev         | $25          | $50         |
| waspwallet   | UAT         | $25          |             |
| waspwallet   | Prod        | $0*          |             |
| academyaxis  | Dev         | $25          | $50         |
| academyaxis  | UAT         | $25          |             |
| academyaxis  | Prod        | $0*          |             |
| **TOTAL**    |             |              | **$300**    |

*Production environments for waspwallet and academyaxis have not been deployed yet.

## Monitoring Dashboards

### Organization-Level Dashboard
Access the organization-level cost dashboard at:
- [AcademyAxis.io Organization Cost Dashboard](https://console.cloud.google.com/monitoring/dashboards)

### Application-Level Dashboards
- [Giortech Dev Cost Dashboard](https://console.cloud.google.com/monitoring/dashboards)
- [Giortech UAT Cost Dashboard](https://console.cloud.google.com/monitoring/dashboards)
- [Giortech Prod Cost Dashboard](https://console.cloud.google.com/monitoring/dashboards)

## Cost Control Mechanisms

Our infrastructure uses several mechanisms to control costs:

1. **Budget Alerts**: Notifications at 50%, 75%, 90%, and 100% of budget
2. **Cost-Efficient Scaling**: 
   - Dev/UAT environments scale to zero when not in use
   - Production maintains minimum instances for availability
3. **Log Management**:
   - Short retention in dev/uat environments (7-14 days)
   - Filtering of health check and debug logs
4. **Storage Optimization**:
   - Lifecycle rules to delete unused objects
   - Appropriate storage classes based on access patterns
5. **Monitoring**:
   - Tracking of expensive operations
   - Real-time cost visibility

## Cost Optimization Best Practices

### For Developers

1. **Mark Expensive Operations**:
   ```javascript
   console.log("expensive-operation: database_query");
   ```

2. **Optimize Database Queries**:
   - Use indexes for frequently accessed fields
   - Limit result sets
   - Use query caching

3. **Efficient Resource Usage**:
   - Minimize CPU-intensive operations
   - Optimize memory usage
   - Use appropriate instance sizes

4. **Code Efficiency**:
   - Minimize external API calls
   - Implement efficient algorithms
   - Use memoization and caching

### For DevOps

1. **Resource Scaling**:
   - Use auto-scaling wisely
   - Set appropriate min/max instances
   - Schedule scaling for predictable loads

2. **Storage Management**:
   - Implement lifecycle rules
   - Use appropriate storage classes
   - Delete unused resources

3. **Networking**:
   - Optimize data transfer
   - Use CDN for static content
   - Monitor egress costs

## Regular Cost Review Process

1. **Weekly Review**:
   - Check cost dashboards for anomalies
   - Adjust resources if trending above budget

2. **Monthly Review**:
   - Comprehensive cost analysis
   - Identify optimization opportunities
   - Adjust budgets if necessary

3. **Quarterly Optimization**:
   - Deep dive into service usage
   - Implement major optimizations
   - Review resource allocation

## Cost Optimization Commands

```bash
# View current spending
gcloud billing accounts get-iam-policy $BILLING_ACCOUNT_ID

# View project billing info
gcloud billing projects describe $PROJECT_ID

# Set budget notifications
gcloud billing budgets update $BUDGET_ID --update-tokens-per-cost=$TOKENS

# Optimize Cloud Run scaling
gcloud run services update $SERVICE_NAME \
  --region=$REGION \
  --min-instances=0 \
  --max-instances=10 \
  --project=$PROJECT_ID

# Set log retention
gcloud logging settings update --retention-days=7 --project=$PROJECT_ID
```

## Emergency Cost-Cutting Measures

If approaching 100% of budget, implement these emergency measures:

1. **Scale Down Non-Critical Services**:
   ```bash
   gcloud run services update $SERVICE_NAME --min-instances=0 --max-instances=1
   ```

2. **Disable Dev/UAT Environments**:
   ```bash
   gcloud run services update $SERVICE_NAME --no-traffic
   ```

3. **Reduce Log Retention**:
   ```bash
   gcloud logging settings update --retention-days=1
   ```

4. **Pause Non-Critical Jobs**:
   ```bash
   gcloud scheduler jobs pause $JOB_NAME
   ```

## Requesting Budget Increases

If legitimate business needs require additional budget:

1. Submit request to devops@academyaxis.io with:
   - Business justification
   - Expected cost increase
   - Duration (temporary or permanent)
   - Optimization measures considered

2. Approval process:
   - Review by DevOps team
   - Approval by management
   - Implementation of adjusted budgets

## Logging Cost-Related Events

When logging cost-related events, use these standard formats:

```
expensive-operation: [operation_type]
cost-alert: [resource_type] [description]
optimization-required: [resource_type] [threshold]
```

## Contribution

To contribute to this cost management guide, please submit pull requests to the [org-infrastructure repository](https://github.com/giortech1/org-infrastructure).

## Contact

For questions or concerns about cost management, contact:
- devops@academyaxis.io