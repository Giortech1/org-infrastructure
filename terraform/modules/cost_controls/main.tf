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
  
  #add explicit provider configuration
  provider = google
}

# Create log-based metric for expensive operations (FIXED)
resource "google_logging_metric" "expensive_operations" {
  name   = "${var.project_id}-expensive-operations"
  filter = "textPayload:\"expensive-operation:\" OR jsonPayload.message:\"expensive-operation:\""
  
  metric_descriptor {
    metric_kind = "DELTA"  # Changed to DELTA (valid option)
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

# Create cost dashboard (FIXED)
resource "google_monitoring_dashboard" "cost_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.project_id} Cost Dashboard"
    mosaicLayout = {
      columns = 12  # Required field: number of columns (1-48)
      tiles = [
        {
          width = 6
          height = 4
          xPos = 0
          yPos = 0
          widget = {
            title = "Monthly Spending Trend"
            text = {
              content = "Cost monitoring dashboard for ${var.project_id}\n\nMonitor your spending and resource usage here."
              format = "MARKDOWN"
            }
          }
        }
      ]
    }
  })
  
  depends_on = [google_project_service.required_apis]
}

# Create cost optimization dashboard (SIMPLIFIED)
resource "google_monitoring_dashboard" "cost_optimization_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.project_id} Cost Optimization"
    mosaicLayout = {
      columns = 12  # Required field: number of columns (1-48)
      tiles = [
        {
          width = 6
          height = 4
          xPos = 0
          yPos = 0
          widget = {
            title = "Resource Usage Overview"
            text = {
              content = "Cost optimization recommendations for ${var.project_id}\n\n- Scale down unused resources\n- Optimize log retention\n- Monitor expensive operations"
              format = "MARKDOWN"
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