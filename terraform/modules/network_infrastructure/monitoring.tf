# terraform/modules/network_infrastructure/monitoring.tf

# Create notification channel for email alerts
resource "google_monitoring_notification_channel" "email_channel" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${local.service_name}-email-notifications"
  type         = "email"
  labels = {
    email_address = var.alert_email_address
  }
  project = var.project_id
}

# Cloud Monitoring uptime check
resource "google_monitoring_uptime_check_config" "uptime_check" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "${local.service_name} Uptime Check"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host = local.full_domain
    }
  }

  depends_on = [google_dns_record_set.a_record]
}

# Create alert policy for uptime failures
resource "google_monitoring_alert_policy" "uptime_alert" {
  count        = var.enable_monitoring && var.environment == "prod" ? 1 : 0
  display_name = "${local.service_name} Uptime Alert"
  combiner     = "OR"

  conditions {
    display_name = "Uptime Check Failed"
    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.uptime_check[0].uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
      }
    }
  }

  notification_channels = length(google_monitoring_notification_channel.email_channel) > 0 ? [
    google_monitoring_notification_channel.email_channel[0].name
  ] : []

  documentation {
    content   = "⚠️ **ALERT: Service Down!** ⚠️\n\n${local.service_name} service is currently unreachable. Please investigate immediately."
    mime_type = "text/markdown"
  }

  depends_on = [google_monitoring_uptime_check_config.uptime_check]
}

# Create additional alert for 5xx errors
resource "google_monitoring_alert_policy" "error_rate_alert" {
  count        = var.enable_monitoring && !var.skip_neg ? 1 : 0
  display_name = "${local.service_name} Error Rate Alert"
  combiner     = "OR"

  conditions {
    display_name = "HTTP 5xx Error Rate"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.05  # 5% error rate
      duration        = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = length(google_monitoring_notification_channel.email_channel) > 0 ? [
    google_monitoring_notification_channel.email_channel[0].name
  ] : []
  
  documentation {
    content   = "High error rate detected for ${local.service_name}. Current error rate exceeds 5% threshold."
    mime_type = "text/markdown"
  }
}

# Create latency alert policy
resource "google_monitoring_alert_policy" "latency_alert" {
  count        = var.enable_monitoring && var.environment == "prod" && !var.skip_neg ? 1 : 0
  display_name = "${local.service_name} High Latency Alert"
  combiner     = "OR"

  conditions {
    display_name = "95th Percentile Latency"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2000  # 2 seconds in ms
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  notification_channels = length(google_monitoring_notification_channel.email_channel) > 0 ? [
    google_monitoring_notification_channel.email_channel[0].name
  ] : []
  
  documentation {
    content   = "High latency detected for ${local.service_name}. 95th percentile latency exceeds 2 seconds."
    mime_type = "text/markdown"
  }
}

# Create a dashboard for the service
resource "google_monitoring_dashboard" "service_dashboard" {
  count = var.enable_monitoring && !var.skip_neg ? 1 : 0
  
  dashboard_json = jsonencode({
    "displayName" = "${local.service_name} Dashboard",
    "gridLayout" = {
      "columns" = "2",
      "widgets" = [
        {
          "title" = "HTTP Request Count",
          "xyChart" = {
            "dataSets" = [{
              "timeSeriesQuery" = {
                "timeSeriesFilter" = {
                  "filter" = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/request_count\"",
                  "aggregation" = {
                    "perSeriesAligner" = "ALIGN_RATE",
                    "crossSeriesReducer" = "REDUCE_SUM",
                    "alignmentPeriod" = "60s"
                  }
                }
              }
            }]
          }
        },
        {
          "title" = "HTTP Response Codes",
          "xyChart" = {
            "dataSets" = [{
              "timeSeriesQuery" = {
                "timeSeriesFilter" = {
                  "filter" = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/request_count\"",
                  "aggregation" = {
                    "perSeriesAligner" = "ALIGN_RATE",
                    "crossSeriesReducer" = "REDUCE_SUM",
                    "alignmentPeriod" = "60s",
                    "groupByFields" = ["metric.labels.response_code_class"]
                  }
                }
              }
            }]
          }
        },
        {
          "title" = "Latency",
          "xyChart" = {
            "dataSets" = [{
              "timeSeriesQuery" = {
                "timeSeriesFilter" = {
                  "filter" = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/request_latencies\"",
                  "aggregation" = {
                    "perSeriesAligner" = "ALIGN_PERCENTILE_95",
                    "crossSeriesReducer" = "REDUCE_MEAN",
                    "alignmentPeriod" = "60s"
                  }
                }
              }
            }]
          }
        },
        {
          "title" = "Instance Count",
          "xyChart" = {
            "dataSets" = [{
              "timeSeriesQuery" = {
                "timeSeriesFilter" = {
                  "filter" = "resource.type = \"cloud_run_revision\" AND resource.labels.service_name = \"${var.cloud_run_service_name}\" AND metric.type = \"run.googleapis.com/container/instance_count\"",
                  "aggregation" = {
                    "perSeriesAligner" = "ALIGN_MAX",
                    "crossSeriesReducer" = "REDUCE_SUM",
                    "alignmentPeriod" = "60s"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
  
  project = var.project_id
}

# Create log-based metric for 5xx errors
resource "google_logging_metric" "error_count_metric" {
  count       = var.enable_monitoring ? 1 : 0
  name        = "${var.application}_${var.environment}_error_count"
  description = "Count of 5xx error logs for ${local.service_name}"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloud_run_service_name}\" AND jsonPayload.statusCode>=500"
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "status_code"
      value_type  = "INT64"
      description = "HTTP status code"
    }
  }
  
  label_extractors = {
    "status_code" = "EXTRACT(jsonPayload.statusCode)"
  }
  
  project = var.project_id
}

# Create cloud run latency logging metric
resource "google_logging_metric" "latency_metric" {
  count       = var.enable_monitoring ? 1 : 0
  name        = "${var.application}_${var.environment}_latency"
  description = "Distribution of request latencies for ${local.service_name}"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloud_run_service_name}\" AND jsonPayload.latencyMs!=\"\""
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    labels {
      key         = "path"
      value_type  = "STRING"
      description = "Request path"
    }
  }
  
  value_extractor = "EXTRACT(jsonPayload.latencyMs)"
  
  label_extractors = {
    "path" = "EXTRACT(jsonPayload.path)"
  }
  
  bucket_options {
    exponential_buckets {
      num_finite_buckets = 64
      growth_factor      = 2
      scale              = 0.01
    }
  }
  
  project = var.project_id
}