# terraform/modules/network_infrastructure/monitoring.tf

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

  notification_channels = [] # Add notification channels if needed

  depends_on = [google_monitoring_uptime_check_config.uptime_check]
}