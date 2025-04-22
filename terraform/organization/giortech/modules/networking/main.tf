# terraform/organization/giortech/modules/networking/main.tf
# Enable required APIs
resource "google_project_service" "lb_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "certificatemanager.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# Create global IP address for load balancer
resource "google_compute_global_address" "lb_ip" {
  name    = "giortech-${var.environment}-ip"
  project = var.project_id

  depends_on = [google_project_service.services]
}

# Create serverless NEG for Cloud Run service
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  name                  = "giortech-${var.environment}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = google_cloud_run_service.giortech_service.name
  }

  depends_on = [google_cloud_run_service.giortech_service]
}

# Create backend service with serverless NEG - FOR NON-PROD ONLY
resource "google_compute_backend_service" "backend" {
  count                 = var.environment != "prod" ? 1 : 0
  name                  = "giortech-${var.environment}-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
}

# Setup Cloud Armor security policy for production
resource "google_compute_security_policy" "security_policy" {
  count       = var.environment == "prod" ? 1 : 0
  name        = "giortech-${var.environment}-waf"
  project     = var.project_id
  description = "WAF policy for giortech ${var.environment}"
  depends_on = [google_project_service.services]

  # Default rule (required)
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, higher priority overrides it"
  }
  
  # XSS protection
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "XSS protection"
  }
  
  # SQL injection protection
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "SQL injection protection"
  }
  
  # Rate limiting to prevent DDoS
  rule {
    action   = "rate_based_ban"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limiting"
    
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      
      ban_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
  }
}

# Apply security policy to the backend service for production
resource "google_compute_backend_service" "backend_with_security" {
  count                 = var.environment == "prod" ? 1 : 0
  name                  = "giortech-${var.environment}-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  security_policy       = google_compute_security_policy.security_policy[0].id
  
  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }
  
  # Enable Cloud CDN
  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    client_ttl        = 3600
    max_ttl           = 86400
    serve_while_stale = 86400
  }
  
  depends_on = [
    google_compute_region_network_endpoint_group.serverless_neg,
    google_compute_security_policy.security_policy
  ]
}

# Create URL map
resource "google_compute_url_map" "url_map" {
  name            = "giortech-${var.environment}-urlmap"
  project         = var.project_id
  default_service = var.environment == "prod" ? google_compute_backend_service.backend_with_security[0].id : google_compute_backend_service.backend[0].id
}

# Create certificate (only for production environment)
resource "google_certificate_manager_certificate" "certificate" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "giortech-${var.environment}-cert"
  project = var.project_id
  scope   = "DEFAULT"
  
  managed {
    domains = ["giortech.academyaxis.io", "www.giortech.academyaxis.io"]
  }

  depends_on = [google_project_service.services]
}

# Create certificate map
resource "google_certificate_manager_certificate_map" "certificate_map" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "giortech-${var.environment}-cert-map"
  project = var.project_id
}

# Create certificate map entry
resource "google_certificate_manager_certificate_map_entry" "map_entry" {
  count              = var.environment == "prod" ? 1 : 0
  name               = "giortech-${var.environment}-map-entry"
  project            = var.project_id
  map                = google_certificate_manager_certificate_map.certificate_map[0].name
  certificates       = [google_certificate_manager_certificate.certificate[0].id]
  hostname           = "giortech.academyaxis.io"
}

# Create HTTPS target proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name    = "giortech-${var.environment}-https-proxy"
  project = var.project_id
  url_map = google_compute_url_map.url_map.id
  
  # Use certificate map for production environment
  dynamic "certificate_map" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      certificate_map = google_certificate_manager_certificate_map.certificate_map[0].id
    }
  }
  
  # Use self-signed certificate for non-prod environments
  dynamic "ssl_certificates" {
    for_each = var.environment != "prod" ? [1] : []
    content {
      # Google will automatically use a managed self-signed certificate when none is specified
      # This is just a placeholder to make the conditional work
      ssl_certificates = []
    }
  }
}

# Create forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "giortech-${var.environment}-https-rule"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
}

# DNS configuration
resource "google_dns_managed_zone" "dns_zone" {
  name        = "giortech-zone"
  dns_name    = "giortech.academyaxis.io."
  description = "DNS zone for giortech.academyaxis.io"
  project     = var.project_id
  
  depends_on = [google_project_service.services]
}

# A record for the environment
resource "google_dns_record_set" "a_record" {
  name         = var.environment == "prod" ? "giortech.academyaxis.io." : "${var.environment}.giortech.academyaxis.io."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = [google_compute_global_address.lb_ip.address]
  project      = var.project_id
}

# Create www CNAME for production environment
resource "google_dns_record_set" "www_cname" {
  count        = var.environment == "prod" ? 1 : 0
  name         = "www.giortech.academyaxis.io."
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["giortech.academyaxis.io."]
  project      = var.project_id
}

# Create wildcard CNAME for all subdomains
resource "google_dns_record_set" "wildcard_cname" {
  count        = var.environment == "prod" ? 1 : 0
  name         = "*.giortech.academyaxis.io."
  type         = "CNAME"
  ttl          = 300
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["giortech.academyaxis.io."]
  project      = var.project_id
}

# Cloud Monitoring for load balancer
resource "google_monitoring_uptime_check_config" "uptime_check" {
  count        = var.environment == "prod" ? 1 : 0
  display_name = "giortech-${var.environment} Uptime Check"
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
      host = var.environment == "prod" ? "giortech.academyaxis.io" : "${var.environment}.giortech.academyaxis.io"
    }
  }
  
  depends_on = [google_dns_record_set.a_record]
}

# Additional outputs for load balancing and DNS
output "load_balancer_ip" {
  value = google_compute_global_address.lb_ip.address
  description = "IP address of the load balancer"
}

output "domain_name" {
  value = var.environment == "prod" ? "giortech.academyaxis.io" : "${var.environment}.giortech.academyaxis.io"
  description = "Domain name for the environment"
}

output "name_servers" {
  value = google_dns_managed_zone.dns_zone.name_servers
  description = "Name servers that need to be configured in the parent domain"
}