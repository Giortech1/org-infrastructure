# Terraform configuration for managing DNS resources

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "app_name" {
  description = "The application name"
  type        = string
}

variable "domain_name" {
  description = "The root domain name"
  type        = string
}

variable "environment" {
  description = "The environment (dev, uat, prod)"
  type        = string
}

variable "load_balancer_ip" {
  description = "IP address of the load balancer"
  type        = string
}

variable "dns_ttl" {
  description = "TTL for DNS records in seconds"
  type        = number
  default     = 300
}

# Enable DNS API
resource "google_project_service" "dns_api" {
  project = var.project_id
  service = "dns.googleapis.com"
  
  disable_on_destroy = false
}

# Create DNS zone if it doesn't exist
resource "google_dns_managed_zone" "dns_zone" {
  name        = "${var.app_name}-zone"
  dns_name    = "${var.app_name}.${var.domain_name}."
  description = "DNS zone for ${var.app_name}.${var.domain_name}"
  project     = var.project_id
  
  depends_on = [google_project_service.dns_api]
}

# A record for the environment
resource "google_dns_record_set" "a_record" {
  name         = var.environment == "prod" ? "${var.app_name}.${var.domain_name}." : "${var.environment}.${var.app_name}.${var.domain_name}."
  type         = "A"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = [var.load_balancer_ip]
  project      = var.project_id
}

# Create www CNAME for production environment
resource "google_dns_record_set" "www_cname" {
  count        = var.environment == "prod" && var.app_name == "giortech" ? 1 : 0
  name         = "www.${var.app_name}.${var.domain_name}."
  type         = "CNAME"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["${var.app_name}.${var.domain_name}."]
  project      = var.project_id
}

# Create wildcard CNAME for development domains
resource "google_dns_record_set" "wildcard_cname" {
  count        = var.environment == "prod" ? 1 : 0
  name         = "*.${var.app_name}.${var.domain_name}."
  type         = "CNAME"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["${var.app_name}.${var.domain_name}."]
  project      = var.project_id
}

# Output DNS configuration
output "dns_zone_name" {
  value = google_dns_managed_zone.dns_zone.name
}

output "dns_name_servers" {
  value = google_dns_managed_zone.dns_zone.name_servers
}

output "full_domain" {
  value = var.environment == "prod" ? "${var.app_name}.${var.domain_name}" : "${var.environment}.${var.app_name}.${var.domain_name}"
}