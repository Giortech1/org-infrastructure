terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Enable required APIs for cost management
resource "google_project_service" "required_apis" {
  for_each = toset([
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudbilling.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  disable_on_destroy = false
}

# Create email notification channel for budget alerts
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "${var.project_id}-budget-alerts"
  type         = "email"
  
  labels = {
    email_address = var.alert_email_address
  }
  
  depends_on = [google_project_service.required_apis]
}

# Create budget with multiple alert thresholds
resource "google_billing_budget" "project_budget" {
  count           = var.create_budget ? 1 : 0
  display_name    = "${var.project_id}-monthly-budget"
  billing_account = var.billing_account_id

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.budget_amount
    }
  }

  # Alert at 50%, 75%, 90%, and 100% of budget
  threshold_rules {
    threshold_percent = 0.5
    spend_basis      = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 0.75
    spend_basis      = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 0.9
    spend_basis      = "CURRENT_SPEND"
  }
  
  threshold_rules {
    threshold_percent = 1.0
    spend_basis      = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email_channel.name
    ]
  }

  depends_on = [google_project_service.required_apis]
}

# Create log-based metric for expensive operations
resource "google_logging_metric" "expensive_operations" {
  name   = "${var.project_id}-expensive-operations"
  filter = "textPayload:\"expensive-operation:\" OR jsonPayload.message:\"expensive-operation:\""
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "Expensive Operations Count"
  }
  
  depends_on = [google_project_service.required_apis]
}

# Environment-specific log bucket configuration
resource "google_logging_project_bucket_config" "logging_bucket" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "${var.project_id}-logs"
  retention_days = local.log_retention_days
  
  depends_on = [google_project_service.required_apis]
}

# Create cost dashboard
resource "google_monitoring_dashboard" "cost_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.project_id} Cost Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width = 6
          height = 4
          widget = {
            title = "Monthly Spending Trend"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"billing_account\""
                    aggregation = {
                      alignmentPeriod = "86400s"
                      perSeriesAligner = "ALIGN_SUM"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
  
  depends_on = [google_project_service.required_apis]
}

# Create cost optimization dashboard
resource "google_monitoring_dashboard" "cost_optimization_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.project_id} Cost Optimization"
    mosaicLayout = {
      tiles = [
        {
          width = 6
          height = 4
          widget = {
            title = "Resource Usage by Service"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\""
                    aggregation = {
                      alignmentPeriod = "300s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
  
  depends_on = [google_project_service.required_apis]
}

# Local values for environment-specific configurations
locals {
  log_retention_days = var.environment == "prod" ? 30 : (var.environment == "uat" ? 14 : 7)
}