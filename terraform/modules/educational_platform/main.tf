# terraform/modules/educational_platform/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

# Enable required APIs for educational platform
resource "google_project_service" "educational_apis" {
  for_each = toset([
    "run.googleapis.com",
    "firestore.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "scheduler.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudbuild.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Educational Firestore Database (Multi-tenant with school isolation)
resource "google_firestore_database" "educational_database" {
  project                           = var.project_id
  name                             = "(default)"
  location_id                      = var.firestore_region
  type                             = "FIRESTORE_NATIVE"
  concurrency_mode                 = "OPTIMISTIC"
  app_engine_integration_mode      = "DISABLED"
  point_in_time_recovery_enablement = var.environment == "prod" ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
  delete_protection_state          = var.environment == "prod" ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"

  depends_on = [google_project_service.educational_apis]
}

# Educational Cloud Storage for school-isolated content
resource "google_storage_bucket" "educational_content" {
  name                        = "${var.project_id}-educational-content"
  location                    = var.region
  force_destroy              = var.environment != "prod"
  uniform_bucket_level_access = true

  # Educational content lifecycle (optimized for academic years)
  lifecycle_rule {
    condition {
      age = var.environment == "prod" ? 2555 : 365  # 7 years for prod, 1 year for dev/uat
    }
    action {
      type = "Delete"
    }
  }

  # Academic year archival
  lifecycle_rule {
    condition {
      age = 365  # Move to coldline after 1 year (end of academic year)
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  versioning {
    enabled = var.environment == "prod"
  }

  # Educational compliance logging
  logging {
    log_bucket        = google_storage_bucket.educational_audit_logs.name
    log_object_prefix = "educational-content-access/"
  }

  depends_on = [google_project_service.educational_apis]
}

# Educational audit logs bucket (compliance requirement)
resource "google_storage_bucket" "educational_audit_logs" {
  name                        = "${var.project_id}-educational-audit-logs"
  location                    = var.region
  force_destroy              = false  # Never force destroy audit logs
  uniform_bucket_level_access = true

  # Extended retention for educational compliance
  lifecycle_rule {
    condition {
      age = 2555  # 7 years minimum for educational records
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.educational_apis]
}

# School onboarding secret (for automated school setup)
resource "google_secret_manager_secret" "school_onboarding_key" {
  secret_id = "school-onboarding-key"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_secret_manager_secret_version" "school_onboarding_key_version" {
  secret      = google_secret_manager_secret.school_onboarding_key.id
  secret_data = var.school_onboarding_key
}

# Educational platform secrets (region-specific)
resource "google_secret_manager_secret" "educational_config" {
  secret_id = "educational-platform-config"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_secret_manager_secret_version" "educational_config_version" {
  secret = google_secret_manager_secret.educational_config.id
  secret_data = jsonencode({
    region                    = var.educational_region
    supported_languages       = var.supported_languages
    default_language         = var.default_language
    grading_system           = var.grading_system
    academic_year_start      = var.academic_year_start
    school_hours_start       = var.school_hours_start
    school_hours_end         = var.school_hours_end
    holiday_scaling_factor   = var.holiday_scaling_factor
    exam_period_scaling_factor = var.exam_period_scaling_factor
    payment_providers        = var.payment_providers
    sms_provider            = var.sms_provider
    email_provider          = var.email_provider
  })
}

# Academic schedule-based Cloud Scheduler jobs
resource "google_cloud_scheduler_job" "academic_scaling_up" {
  name             = "academic-scaling-up"
  project          = var.project_id
  region           = var.region
  description      = "Scale up educational services during school hours"
  schedule         = "0 ${var.school_hours_start} * * 1-5"  # Weekdays at school start
  time_zone        = var.school_timezone
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-${var.project_id}.cloudfunctions.net/educational-scaler"
    body        = base64encode(jsonencode({
      action = "scale_up"
      factor = 1.0
      reason = "school_hours_start"
    }))
  }

  depends_on = [google_project_service.educational_apis]
}

resource "google_cloud_scheduler_job" "academic_scaling_down" {
  name             = "academic-scaling-down"
  project          = var.project_id
  region           = var.region
  description      = "Scale down educational services after school hours"
  schedule         = "0 ${var.school_hours_end} * * 1-5"  # Weekdays at school end
  time_zone        = var.school_timezone
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-${var.project_id}.cloudfunctions.net/educational-scaler"
    body        = base64encode(jsonencode({
      action = "scale_down"
      factor = var.holiday_scaling_factor
      reason = "school_hours_end"
    }))
  }

  depends_on = [google_project_service.educational_apis]
}

# Holiday scaling job
resource "google_cloud_scheduler_job" "holiday_scaling" {
  name             = "holiday-scaling"
  project          = var.project_id
  region           = var.region
  description      = "Scale down during school holidays"
  schedule         = "0 0 * * 6,0"  # Weekends
  time_zone        = var.school_timezone
  attempt_deadline = "320s"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-${var.project_id}.cloudfunctions.net/educational-scaler"
    body        = base64encode(jsonencode({
      action = "scale_down"
      factor = var.holiday_scaling_factor
      reason = "weekend"
    }))
  }

  depends_on = [google_project_service.educational_apis]
}

# Educational monitoring dashboard
resource "google_monitoring_dashboard" "educational_dashboard" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "AcademyAxis Educational Platform - ${var.environment}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Active Schools"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_LINE"
              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Student Activity"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"firestore_database\" AND metric.type=\"firestore.googleapis.com/document/read_count\""
                  aggregation = {
                    alignmentPeriod  = "300s"
                    perSeriesAligner = "ALIGN_RATE"
                  }
                }
              }
              sparkChartView = {
                sparkChartType = "SPARK_BAR"
              }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 12
          height = 4
          widget = {
            title = "Educational Platform Performance"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {
                        alignmentPeriod    = "60s"
                        perSeriesAligner   = "ALIGN_DELTA"
                        crossSeriesReducer = "REDUCE_PERCENTILE_95"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Latency (ms)"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })

  depends_on = [google_project_service.educational_apis]
}

# Educational alert policy for high error rates during school hours
resource "google_monitoring_alert_policy" "educational_error_rate" {
    project      = var.project_id
    display_name = "Educational Platform - High Error Rate During School Hours"
    
    conditions {
        display_name = "Error rate too high during school hours"
        condition_threshold {
            filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
            duration        = "300s"
            comparison      = "COMPARISON_GREATER_THAN"
            threshold_value = var.error_rate_threshold

            aggregations {
                alignment_period     = "300s"
                per_series_aligner   = "ALIGN_RATE"
                cross_series_reducer = "REDUCE_SUM"
                group_by_fields     = ["resource.service_name"]  # Group by service name
            }

            trigger {
                count = 1
            }
        }
    }

    documentation {
        content   = "High error rate detected during school hours. Please investigate immediately."
        mime_type = "text/markdown"
    }

    alert_strategy {
        auto_close = "1800s"  # Auto-close after 30 minutes
    }

    notification_channels = var.notification_channels
    combiner             = "OR"  # Alert if any condition is met

    depends_on = [google_project_service.educational_apis]
}

# Educational budget alert for cost control
resource "google_billing_budget" "educational_budget" {
  count           = var.create_budget ? 1 : 0
  billing_account = var.billing_account_id
  display_name    = "AcademyAxis Educational Budget - ${var.environment}"

  budget_filter {
    projects = ["projects/${var.project_id}"]
    
    # Educational services only
    services = [
      "services/run.googleapis.com",
      "services/firestore.googleapis.com", 
      "services/storage.googleapis.com",
      "services/secretmanager.googleapis.com"
    ]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = var.budget_amount
    }
  }

  # Educational budget thresholds (different for school year vs holidays)
  threshold_rules {
    threshold_percent = 0.5  # 50% during active school period
  }
  threshold_rules {
    threshold_percent = 0.75  # 75% warning
  }
  threshold_rules {
    threshold_percent = 0.9   # 90% critical
  }
  threshold_rules {
    threshold_percent = 1.0   # 100% over budget
  }

  all_updates_rule {
    monitoring_notification_channels = var.notification_channels
    pubsub_topic                    = var.budget_pubsub_topic
  }

  depends_on = [google_project_service.educational_apis]
}