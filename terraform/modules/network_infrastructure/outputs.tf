# terraform/modules/network_infrastructure/outputs.tf

output "load_balancer_ip" {
  value       = google_compute_global_address.lb_ip.address
  description = "IP address of the load balancer"
}

output "domain_name" {
  value       = local.full_domain
  description = "Domain name for the environment"
}

output "name_servers" {
  value       = google_dns_managed_zone.dns_zone.name_servers
  description = "Name servers for the DNS zone"
}

output "ssl_certificate_id" {
  value       = var.environment == "prod" ? google_certificate_manager_certificate.certificate[0].id : (var.environment != "prod" ? google_compute_ssl_certificate.self_signed[0].id : null)
  description = "SSL certificate ID"
}

output "backend_service_id" {
  value       = google_compute_backend_service.backend.id
  description = "Backend service ID"
}