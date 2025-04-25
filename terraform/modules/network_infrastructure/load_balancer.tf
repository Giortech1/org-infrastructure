# terraform/modules/network_infrastructure/load_balancer.tf

# Create global IP address for load balancer
resource "google_compute_global_address" "lb_ip" {
  name    = "${local.service_name}-ip"
  project = var.project_id

}

# Create serverless NEG for Cloud Run service
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  count                 = var.skip_neg ? 0 : 1
  name                  = "${local.service_name}-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# Create backend service with serverless NEG
resource "google_compute_backend_service" "backend" {
  name                  = "${local.service_name}-backend"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
backend {
  group = var.skip_neg ? null : google_compute_region_network_endpoint_group.serverless_neg[0].id
}

  # Enable CDN for production if requested
  dynamic "cdn_policy" {
    for_each = var.enable_cdn ? [1] : []
    content {
      cache_mode        = "CACHE_ALL_STATIC"
      default_ttl       = var.cdn_cache_ttl
      client_ttl        = var.cdn_cache_ttl
      max_ttl           = var.cdn_cache_ttl * 2
      serve_while_stale = var.cdn_cache_ttl
      negative_caching  = true
    }
  }

  # Link to security policy if Cloud Armor is enabled
  security_policy = var.enable_cloud_armor ? google_compute_security_policy.security_policy[0].id : null

  depends_on = [
    google_compute_region_network_endpoint_group.serverless_neg,
    google_compute_security_policy.security_policy
  ]
}

# Create URL map
resource "google_compute_url_map" "url_map" {
  name            = "${local.service_name}-urlmap"
  project         = var.project_id
  default_service = google_compute_backend_service.backend.id
}

# Create SSL certificate
resource "google_certificate_manager_certificate" "certificate" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "${local.service_name}-cert"
  project = var.project_id
  scope   = "DEFAULT"
  
  managed {
    domains = [local.full_domain, "www.${local.full_domain}"]
  }

}

# Create self-signed certificate for non-prod environments
resource "google_compute_ssl_certificate" "self_signed" {
  count       = var.environment != "prod" ? 1 : 0
  # Add a timestamp to make the name unique
  name        = "${local.service_name}-self-signed-cert-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  project     = var.project_id
  private_key = file("${path.module}/cert/key.pem")
  certificate = file("${path.module}/cert/cert.pem")
  
  lifecycle {
    create_before_destroy = true
    # Option 1: Ignore changes - not ideal but works for testing
    # ignore_changes = all

    # Option 2: Prevent recreation
    prevent_destroy = false
  }
}

# Create certificate map for prod
resource "google_certificate_manager_certificate_map" "certificate_map" {
  count   = var.environment == "prod" ? 1 : 0
  name    = "${local.service_name}-cert-map"
  project = var.project_id
}

# Create certificate map entry for prod
resource "google_certificate_manager_certificate_map_entry" "map_entry" {
  count              = var.environment == "prod" ? 1 : 0
  name               = "${local.service_name}-map-entry"
  project            = var.project_id
  map                = google_certificate_manager_certificate_map.certificate_map[0].name
  certificates       = [google_certificate_manager_certificate.certificate[0].id]
  hostname           = local.full_domain
}

# Create HTTPS target proxy
resource "google_compute_target_https_proxy" "https_proxy" {
  name    = "${local.service_name}-https-proxy"
  project = var.project_id
  url_map = google_compute_url_map.url_map.id
  
  # Use certificate map for production environment
  certificate_map = var.environment == "prod" ? (
    length(google_certificate_manager_certificate_map.certificate_map) > 0 ? 
    google_certificate_manager_certificate_map.certificate_map[0].id : null
  ) : null
  
  # Use self-signed certificate for non-prod environments
  ssl_certificates = var.environment != "prod" ? (
    length(google_compute_ssl_certificate.self_signed) > 0 ? 
    [google_compute_ssl_certificate.self_signed[0].id] : null
  ) : null
}

# Create forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "${local.service_name}-https-rule"
  project               = var.project_id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.id
}