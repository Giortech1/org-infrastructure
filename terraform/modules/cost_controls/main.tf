terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
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

  depends_on = [google_project_service.required_apis]
}

# Create notification channel for alerts
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "${var.application}-${var.environment}-email-alerts"
  type         = "email"
  labels = {
    email_address = var.alert_email_address
  }

  depends_on = [google_project_service.required_apis]
}
# Create a dashboard for cost monitoring
# This dashboard provides a high-level overview of costs and budget status
resource "google_monitoring_dashboard" "cost_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.application}-${var.environment} Cost Dashboard"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 12
          height = 6
          widget = {
            title = "Cost Monitoring Overview"
            text = {
              content = "## ${title(var.application)} ${title(var.environment)} Environment\n\n**Monthly Budget:** $${var.budget_amount} USD\n\n**Current Configuration:**\n- Log Retention: ${var.environment == "prod" ? "30" : (var.environment == "uat" ? "14" : "7")} days\n- Environment: ${title(var.environment)}\n- Project: ${var.project_id}\n\n**Cost Optimization Status:**\n- Budget alerts configured at 50%, 75%, 90%, 100%\n- Log filtering active to reduce costs\n- Expensive operations tracking enabled\n\n**Monitoring:**\n- Email alerts: ${var.alert_email_address}\n- Dashboard last updated: $(date)\n\n**Quick Actions:**\n1. Review resource usage weekly\n2. Scale down unused services\n3. Clean up old storage buckets\n4. Monitor expensive operations in logs"
              format = "MARKDOWN"
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
    displayName = "${var.application}-${var.environment} Cost Optimization"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 12
          height = 4
          widget = {
            title = "Cost Optimization Recommendations"
            text = {
              content = "## Cost Optimization for ${var.application}-${var.environment}\n\n**Monthly Budget:** ${var.budget_amount}\n\n### Recommendations:\n1. Monitor resource usage patterns\n2. ...\n"
              format = "MARKDOWN"
            }
          }
        }
      ]
    }
  })

  depends_on = [google_project_service.required_apis]
}

# Log bucket configuration
resource "google_logging_project_bucket_config" "logging_bucket" {
  project    = var.project_id
  location   = "global"
  bucket_id  = "_Default"

  retention_days = var.log_retention_days != null ? var.log_retention_days : (var.environment == "prod" ? 30 : (var.environment == "uat" ? 14 : 7))

  depends_on = [google_project_service.required_apis]
}

# Simplified log metric for expensive operations (ensure only valid metric_kind)
resource "google_logging_metric" "expensive_operations" {
  name   = "${var.application}-${var.environment}-expensive-ops"
  filter = "textPayload:\"expensive-operation:\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }

  depends_on = [google_project_service.required_apis]
}

# Alert policy for expensive operations
resource "google_monitoring_alert_policy" "expensive_operations_alert" {
  count        = var.enable_alerts ? 1 : 0
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

  depends_on = [
    google_logging_metric.expensive_operations,
    google_project_service.required_apis
  ]
}

# Simplified log sink for cost optimization (fix destination to valid storage bucket)
# Add storage bucket first
resource "google_storage_bucket" "log_storage" {
  name          = "${var.project_id}-${var.application}-${var.environment}-logs"
  location      = var.region
  force_destroy = true
  uniform_bucket_level_access = true

  depends_on = [google_project_service.required_apis]
}

# Fixed log sink
resource "google_logging_project_sink" "cost_optimized_sink" {
  name        = "${var.application}-${var.environment}-cost-optimized-logs"
  destination = "storage.googleapis.com/${google_storage_bucket.log_storage.name}"  # ✅ FIXED

  filter = <<-EOT
    NOT (
      httpRequest.requestUrl:"/health"
      OR httpRequest.requestUrl:"/_ah/health"
      OR severity="DEBUG"
      OR (resource.type="cloud_run_revision" AND textPayload:"health check")
    )
  EOT

  unique_writer_identity = true
  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket.log_storage
  ]
}

# Grant log sink permission to write to bucket
resource "google_storage_bucket_iam_member" "log_sink_writer" {
  bucket = google_storage_bucket.log_storage.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cost_optimized_sink.writer_identity
}