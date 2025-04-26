# terraform/modules/network_infrastructure/dns.tf

# Create DNS zone
resource "google_dns_managed_zone" "dns_zone" {
  name        = "${var.application}-zone"
  dns_name    = "${var.application}.${var.domain}."
  description = "DNS zone for ${var.application}.${var.domain}"
  project     = var.project_id

}

# A record for the environment
resource "google_dns_record_set" "a_record" {
  name         = "${local.full_domain}."
  type         = "A"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = [google_compute_global_address.lb_ip.address]
  project      = var.project_id
}

# Create www CNAME for production environment
resource "google_dns_record_set" "www_cname" {
  count        = var.environment == "prod" ? 1 : 0
  name         = "www.${local.full_domain}."
  type         = "CNAME"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["${local.full_domain}."]
  project      = var.project_id
}

# Create wildcard CNAME for production
resource "google_dns_record_set" "wildcard_cname" {
  count        = var.environment == "prod" ? 1 : 0
  name         = "*.${local.full_domain}."
  type         = "CNAME"
  ttl          = var.dns_ttl
  managed_zone = google_dns_managed_zone.dns_zone.name
  rrdatas      = ["${local.full_domain}."]
  project      = var.project_id
}