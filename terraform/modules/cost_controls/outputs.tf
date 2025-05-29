output "budget_id" {
  description = "The ID of the created budget"
  value       = var.create_budget ? (length(google_billing_budget.project_budget) > 0 ? google_billing_budget.project_budget[0].id : null) : null
}

output "dashboards" {
  description = "URLs to access the monitoring dashboards"
  value = {
    cost_dashboard           = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.cost_dashboard.id}?project=${var.project_id}"
    cost_optimization        = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.cost_optimization_dashboard.id}?project=${var.project_id}"
  }
}

output "notification_channel" {
  description = "The notification channel for alerts"
  value       = google_monitoring_notification_channel.email_channel.name
}

output "logging_bucket" {
  description = "The name of the logging bucket"
  value       = google_logging_project_bucket_config.logging_bucket.name
}

output "log_metric_name" {
  description = "The name of the expensive operations log metric"
  value       = google_logging_metric.expensive_operations.name
}