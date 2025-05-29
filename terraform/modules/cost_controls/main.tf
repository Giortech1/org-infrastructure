# terraform/modules/cost_controls/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Create budget for cost control
resource "google_billing_budget" "project_budget" {
  count           = var.create_budget ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "${var.application}-${var.environment}-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.budget_amount
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.75
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email_channel.name]
  }
}

# Create notification channel for alerts
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "${var.application}-${var.environment}-email-alerts"
  type         = "email"
  labels = {
    email_address = var.alert_email_address
  }
}

# Create cost dashboard
resource "google_monitoring_dashboard" "cost_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.application}-${var.environment} Cost Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run CPU Utilization"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Storage Usage"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gcs_bucket\""
                  aggregation = {
                    alignmentPeriod  = "3600s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }
          }
        }
      ]
    }
  })
}

# Create cost optimization dashboard
resource "google_monitoring_dashboard" "cost_optimization_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.application}-${var.environment} Cost Optimization"
    mosaicLayout = {
      tiles = [
        {
          width  = 12
          height = 4
          widget = {
            title = "Cost Optimization Recommendations"
            text = {
              content = "Monitor resource usage to identify optimization opportunities:\n\n1. Check for unused resources\n2. Review scaling settings\n3. Optimize log retention\n4. Monitor expensive operations"
              format = "MARKDOWN"
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Budget Usage"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"billing_account\""
                  aggregation = {
                    alignmentPeriod  = "86400s"
                    perSeriesAligner = "ALIGN_MAX"
                  }
                }
              }
            }
          }
        }
      ]
    }
  })
}

# Log bucket configuration
resource "google_logging_project_bucket_config" "logging_bucket" {
  project    = var.project_id
  location   = "global"
  bucket_id  = "_Default"
  
  retention_days = var.log_retention_days != null ? var.log_retention_days : (var.environment == "prod" ? 30 : (var.environment == "uat" ? 14 : 7))
}

# Log metric for expensive operations
resource "google_logging_metric" "expensive_operations" {
  name   = "${var.application}-${var.environment}-expensive-ops"
  filter = "textPayload:\"expensive-operation:\""
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
  }

  value_extractor = "EXTRACT(textPayload)"
  
  label_extractors = {
    "operation_type" = "EXTRACT(textPayload)"
  }
}

# Alert policy for expensive operations
resource "google_monitoring_alert_policy" "expensive_operations_alert" {
  display_name = "${var.application}-${var.environment} Expensive Operations Alert"
  combiner     = "OR"

  conditions {
    display_name = "High number of expensive operations"
    condition_threshold {
      filter         = "resource.type=\"global\" AND metric.type=\"logging.googleapis.com/user/${google_logging_metric.expensive_operations.name}\""
      comparison     = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_channel.name]

  depends_on = [google_logging_metric.expensive_operations]
}

# Log sink to exclude health checks and debug logs (cost optimization)
resource "google_logging_project_sink" "cost_optimized_sink" {
  name        = "${var.application}-${var.environment}-cost-optimized-logs"
  destination = "logging.googleapis.com/projects/${var.project_id}/logs/${var.application}-${var.environment}-filtered"

  # Exclude health checks and debug logs to reduce costs
  filter = <<-EOT
    NOT (
      httpRequest.requestUrl:"/health" 
      OR httpRequest.requestUrl:"/_ah/health"
      OR severity="DEBUG"
      OR (resource.type="cloud_run_revision" AND textPayload:"health check")
    )
  EOT

  unique_writer_identity = true
}